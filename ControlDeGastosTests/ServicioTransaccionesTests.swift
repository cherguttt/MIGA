//
//  ServicioTransaccionesTests.swift
//  ControlDeGastosTests
//
//  PRUEBAS DE INTEGRACIÓN del servicio de transacciones con SwiftData.
//  Corresponden a los casos CP-03 y CP-06 del Plan de pruebas (sección 4.4.11).
//
//  Se usa una base de datos EN MEMORIA: cada prueba parte con una base vacía y
//  no se toca la base de datos real de la app.
//

import XCTest
import SwiftData
@testable import ControlDeGastos

@MainActor
final class ServicioTransaccionesTests: XCTestCase {

    /// Crea una base de datos nueva y vacía para UNA prueba, junto con su servicio.
    /// Devuelve una TUPLA con dos valores: el contenedor (debe seguir existiendo mientras
    /// se use el contexto) y el servicio que vamos a probar.
    private func crearServicio() -> (ModelContainer, ServicioTransacciones) {
        let contenedor = ContenedorDatos.crear(enMemoria: true)
        return (contenedor, ServicioTransacciones(contexto: contenedor.mainContext))
    }

    /// Devuelve todas las transacciones guardadas en un contenedor.
    private func todas(_ contenedor: ModelContainer) throws -> [Transaccion] {
        try contenedor.mainContext.fetch(FetchDescriptor<Transaccion>())
    }

    /// CP-03: registrar un gasto válido ($15.000, Alimentación, fecha actual).
    func testRegistrarGastoValidoLoGuarda() throws {
        let (contenedor, servicio) = crearServicio()
        let ahora = Date.now
        try servicio.registrarGasto(
            monto: 15_000, categoria: .alimentacion, fecha: ahora,
            descripcion: "  Almuerzo  ", ahora: ahora)

        let guardadas = try todas(contenedor)
        XCTAssertEqual(guardadas.count, 1)
        XCTAssertEqual(guardadas.first?.monto, 15_000)
        XCTAssertEqual(guardadas.first?.categoria, .alimentacion)
        XCTAssertEqual(guardadas.first?.origen, .manual)
        XCTAssertEqual(guardadas.first?.descripcion, "Almuerzo")   // Sin espacios sobrantes.
    }

    /// Una descripción vacía se guarda como `nil`.
    func testDescripcionVaciaSeGuardaComoNil() throws {
        let (contenedor, servicio) = crearServicio()
        try servicio.registrarGasto(monto: 1_000, categoria: .transporte, fecha: .now, descripcion: "   ")
        XCTAssertNil(try todas(contenedor).first?.descripcion)
    }

    /// El servicio rechaza un monto cero aunque el formulario lo dejara pasar.
    func testMontoCeroLanzaError() {
        let (contenedor, servicio) = crearServicio()
        XCTAssertThrowsError(
            try servicio.registrarGasto(monto: 0, categoria: .salud, fecha: .now, descripcion: nil)
        ) { error in
            XCTAssertEqual(error as? ErrorTransaccion, .montoInvalido)
        }
        // Mantiene viva la base de datos hasta el final de la prueba.
        withExtendedLifetime(contenedor) {}
    }

    /// El servicio rechaza una fecha futura.
    func testFechaFuturaLanzaError() {
        let (contenedor, servicio) = crearServicio()
        let ahora = Date.now
        XCTAssertThrowsError(
            try servicio.registrarGasto(
                monto: 5_000, categoria: .salud, fecha: ahora.addingTimeInterval(3_600),
                descripcion: nil, ahora: ahora)
        ) { error in
            XCTAssertEqual(error as? ErrorTransaccion, .fechaFutura)
        }
        // Mantiene viva la base de datos hasta el final de la prueba.
        withExtendedLifetime(contenedor) {}
    }

    /// `gastosDelMes` devuelve solo los gastos del mes consultado, del más reciente al más antiguo.
    func testGastosDelMesFiltraYOrdena() throws {
        let (contenedor, servicio) = crearServicio()
        var calendario = Calendar(identifier: .gregorian)
        calendario.timeZone = TimeZone(identifier: "America/Santiago")!
        let fecha = { (dia: Int, mes: Int) in
            calendario.date(from: DateComponents(year: 2026, month: mes, day: dia, hour: 12))!
        }
        let ahora = fecha(31, 12)
        try servicio.registrarGasto(monto: 1_000, categoria: .salud, fecha: fecha(5, 10), descripcion: nil, ahora: ahora)
        try servicio.registrarGasto(monto: 2_000, categoria: .salud, fecha: fecha(20, 10), descripcion: nil, ahora: ahora)
        try servicio.registrarGasto(monto: 3_000, categoria: .salud, fecha: fecha(2, 11), descripcion: nil, ahora: ahora)

        let octubre = try servicio.gastosDelMes(fecha(15, 10), calendario: calendario)
        XCTAssertEqual(octubre.map(\.monto), [2_000, 1_000])
        // Mantiene viva la base de datos hasta el final de la prueba.
        withExtendedLifetime(contenedor) {}
    }

    /// Eliminar un gasto lo borra de la base de datos.
    func testEliminarBorraElGasto() throws {
        let (contenedor, servicio) = crearServicio()
        let gasto = try servicio.registrarGasto(monto: 8_000, categoria: .entretenimiento, fecha: .now, descripcion: "Cine")
        try servicio.eliminar(gasto)
        XCTAssertTrue(try todas(contenedor).isEmpty)
    }

    /// CP-06: los datos persisten al cerrar y reabrir la base de datos.
    /// Se usa un archivo SQLite temporal (no la base real de la app): se guarda un gasto,
    /// se descarta el contenedor (como si la app se cerrara) y se abre uno nuevo sobre el mismo archivo.
    func testPersistenciaAlCerrarYReabrir() throws {
        let carpeta = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: carpeta, withIntermediateDirectories: true)
        let archivo = carpeta.appending(path: "Prueba.store")
        // `defer`: al terminar la prueba, se borra la carpeta temporal.
        defer { try? FileManager.default.removeItem(at: carpeta) }

        func abrir() throws -> ModelContainer {
            let configuracion = ModelConfiguration(schema: ContenedorDatos.esquema, url: archivo)
            return try ModelContainer(for: ContenedorDatos.esquema, configurations: [configuracion])
        }

        // 1. «Primera sesión»: registrar el gasto. El bloque `do` hace que el contenedor
        //    deje de existir al terminar, igual que al cerrar la app.
        do {
            let primero = try abrir()
            try ServicioTransacciones(contexto: primero.mainContext)
                .registrarGasto(monto: 15_000, categoria: .alimentacion, fecha: .now, descripcion: "Persistencia")
        }

        // 2. «Segunda sesión»: reabrir el archivo y comprobar que el gasto sigue ahí.
        let segundo = try abrir()
        let guardadas = try segundo.mainContext.fetch(FetchDescriptor<Transaccion>())
        XCTAssertEqual(guardadas.count, 1)
        XCTAssertEqual(guardadas.first?.descripcion, "Persistencia")
    }
}
