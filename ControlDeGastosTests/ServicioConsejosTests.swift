//
//  ServicioConsejosTests.swift
//  ControlDeGastosTests
//
//  PRUEBAS DE INTEGRACIÓN del Servicio de Consejos con SwiftData (Sprint 5, CU-07).
//  - CP-14: envío del consejo semanal (lunes a las 9:00) y registro del EnvioConsejo.
//  - CP-15 integrado: aviso de gasto hormiga al registrar gastos pequeños.
//  - RF-23: valoración «¿Te fue útil?».
//

import XCTest
import SwiftData
@testable import ControlDeGastos

@MainActor
final class ServicioConsejosTests: XCTestCase {

    private var calendario: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "America/Santiago")!
        return c
    }

    private func fecha(_ mes: Int, _ dia: Int, _ hora: Int = 9) -> Date {
        calendario.date(from: DateComponents(year: 2026, month: mes, day: dia, hour: hora))!
    }

    /// «Ahora»: miércoles 28 de octubre de 2026, 15:00.
    private var ahora: Date { fecha(10, 28, 15) }

    /// Fecha `d` días antes de «ahora» (y una hora antes, para quedar dentro de la ventana).
    /// Es un método de la clase (y no una función dentro de la prueba) para que Swift sepa
    /// que se ejecuta en el hilo principal, igual que las propiedades que usa.
    private func haceDias(_ d: Int) -> Date {
        calendario.date(byAdding: .hour, value: -(d * 24 + 1), to: ahora)!
    }

    /// Base de datos en memoria con los consejos ya precargados, el servicio y el programador simulado.
    private func crearServicio() throws -> (ModelContainer, ServicioConsejos, ProgramadorConsejosSimulado) {
        let contenedor = ContenedorDatos.crear(enMemoria: true)
        let programador = ProgramadorConsejosSimulado()
        let servicio = ServicioConsejos(contexto: contenedor.mainContext, programador: programador, calendario: calendario)
        try servicio.precargarSiHaceFalta(bundle: Bundle(for: Consejo.self))
        return (contenedor, servicio, programador)
    }

    // MARK: - Precarga

    /// Se cargan los 39 consejos con la misma distribución del mockup P6.
    func testPrecargaConsejosIniciales() throws {
        let (contenedor, servicio, _) = try crearServicio()
        try withExtendedLifetime(contenedor) {
            let consejos = try servicio.consejosActivos()
            XCTAssertEqual(consejos.count, 39)
            let esperado: [CategoriaConsejo: Int] = [.ahorro: 6, .presupuesto: 8, .deuda: 5, .inversion: 4, .gastoHormiga: 7, .habitos: 9]
            for (categoria, cantidad) in esperado {
                XCTAssertEqual(consejos.filter { $0.categoria == categoria }.count, cantidad, categoria.nombre)
            }
            XCTAssertEqual(consejos.map(\.orden), Array(1...39))   // Orden sin saltos ni repetidos.
            // Una segunda precarga no duplica.
            XCTAssertEqual(try servicio.precargarSiHaceFalta(bundle: Bundle(for: Consejo.self)), 0)
        }
    }

    /// La notificación usa la primera oración, igual que el mockup P9.
    func testPrimeraOracionDelCafe() throws {
        let (contenedor, servicio, _) = try crearServicio()
        try withExtendedLifetime(contenedor) {
            let cafe = try XCTUnwrap(try servicio.consejosActivos().first { $0.titulo == "El costo oculto del café diario" })
            XCTAssertEqual(cafe.primeraOracion, "Un café de $2.500 en días hábiles suma más de $50.000 al mes.")
            for consejo in try servicio.consejosActivos() {
                XCTAssertTrue(consejo.primeraOracion.hasSuffix("."), consejo.titulo)
            }
        }
    }

    /// El ejemplo de la bola de nieve tiene las tres filas del mockup P7.
    func testFilasDelEjemplo() throws {
        let (contenedor, servicio, _) = try crearServicio()
        try withExtendedLifetime(contenedor) {
            let bola = try XCTUnwrap(try servicio.consejosActivos().first { $0.titulo == "La regla de la bola de nieve" })
            let filas = bola.filasEjemplo
            XCTAssertEqual(filas.count, 3)
            XCTAssertEqual(filas[0].texto, "Deuda 1: $50.000")
            XCTAssertEqual(filas[0].valor, "Pagar primero")
            XCTAssertTrue(filas[0].destacado)
            XCTAssertFalse(filas[1].destacado)
        }
    }

    // MARK: - CP-14: consejo semanal

    /// CP-14: el primer consejo se entrega de inmediato y quedan 4 lunes a las 9:00 programados,
    /// con los consejos n.° 2 a 5 en orden.
    func testCP14ProgramaLunesALasNueve() throws {
        let (contenedor, servicio, programador) = try crearServicio()
        try withExtendedLifetime(contenedor) {
            try servicio.programarSemanal(ahora: ahora)
            let envios = try servicio.envios()
            XCTAssertEqual(envios.count, 5)
            XCTAssertEqual(envios.map { $0.consejo?.orden }, [1, 2, 3, 4, 5])
            XCTAssertEqual(envios.map(\.fechaEnvio), [ahora, fecha(11, 2), fecha(11, 9), fecha(11, 16), fecha(11, 23)])
            XCTAssertTrue(envios.allSatisfy { $0.motivo == .semanal })

            // Se programaron 4 notificaciones (la primera no: el usuario está en la app).
            XCTAssertEqual(programador.programados.count, 4)
            XCTAssertEqual(programador.programados.map(\.fecha), [fecha(11, 2), fecha(11, 9), fecha(11, 16), fecha(11, 23)])
            XCTAssertEqual(programador.programados.first?.subtitulo, "Consejo semanal")
            XCTAssertEqual(programador.programados.first?.cuerpo, envios[1].consejo?.primeraOracion)
        }
    }

    /// Programar dos veces no duplica envíos.
    func testProgramarDosVecesNoDuplica() throws {
        let (contenedor, servicio, _) = try crearServicio()
        try withExtendedLifetime(contenedor) {
            try servicio.programarSemanal(ahora: ahora)
            try servicio.programarSemanal(ahora: ahora)
            XCTAssertEqual(try servicio.envios().count, 5)
        }
    }

    /// Una semana después se agrega un lunes más y la secuencia continúa con el consejo n.° 6.
    func testLaSecuenciaAvanza() throws {
        let (contenedor, servicio, _) = try crearServicio()
        try withExtendedLifetime(contenedor) {
            try servicio.programarSemanal(ahora: ahora)
            let unaSemanaDespues = fecha(11, 4, 15)
            try servicio.programarSemanal(ahora: unaSemanaDespues)
            let envios = try servicio.envios()
            XCTAssertEqual(envios.count, 6)
            XCTAssertEqual(envios.last?.consejo?.orden, 6)
            XCTAssertEqual(envios.last?.fechaEnvio, fecha(11, 30))
            // Recibidos a esa fecha: el inicial y el del lunes 2 de noviembre.
            XCTAssertEqual(try servicio.recibidos(ahora: unaSemanaDespues).count, 2)
        }
    }

    /// Después del último consejo, la secuencia vuelve al primero.
    func testLaSecuenciaVuelveAlInicio() throws {
        let (contenedor, servicio, _) = try crearServicio()
        try withExtendedLifetime(contenedor) {
            let consejos = try servicio.consejosActivos()
            XCTAssertEqual(ServicioConsejos.siguiente(despuesDe: consejos.last, en: consejos)?.orden, 1)
            XCTAssertEqual(ServicioConsejos.siguiente(despuesDe: nil, en: consejos)?.orden, 1)
        }
    }

    /// Flujo alternativo: al desactivar el consejo semanal se cancelan los pendientes,
    /// pero el consejo ya recibido se conserva.
    func testCancelarSemanal() throws {
        let (contenedor, servicio, programador) = try crearServicio()
        try withExtendedLifetime(contenedor) {
            try servicio.programarSemanal(ahora: ahora)
            try servicio.cancelarSemanal(ahora: ahora)
            XCTAssertEqual(programador.cancelados.count, 4)
            XCTAssertEqual(try servicio.envios().count, 1)
        }
    }

    /// Si el perfil tiene el consejo semanal desactivado, no se programa nada.
    func testConsejoSemanalDesactivado() throws {
        let (contenedor, servicio, programador) = try crearServicio()
        try withExtendedLifetime(contenedor) {
            let perfil = PerfilUsuario(nombre: "Prueba", ingresoMensualReferencia: 800_000, consentimientoAceptado: true)
            perfil.consejoSemanalActivo = false
            contenedor.mainContext.insert(perfil)
            try servicio.programarSemanal(ahora: ahora)
            XCTAssertTrue(try servicio.envios().isEmpty)
            XCTAssertTrue(programador.programados.isEmpty)
        }
    }

    // MARK: - Gasto hormiga (integración)

    /// Escenario del CP-15 guardado en la base: se envía un consejo de «Gasto hormiga» de
    /// inmediato, y una segunda evaluación el mismo día no repite el aviso.
    func testAvisoDeGastoHormiga() throws {
        let (contenedor, servicio, programador) = try crearServicio()
        try withExtendedLifetime(contenedor) {
            let contexto = contenedor.mainContext
            contexto.insert(Transaccion(monto: 25_000, categoria: .servicios, fecha: haceDias(70)))   // Primer registro.
            for i in 0..<9 { contexto.insert(Transaccion(monto: 3_000, categoria: .alimentacion, fecha: haceDias(i % 7))) }
            for semana in 1...8 {
                for k in 1...4 { contexto.insert(Transaccion(monto: 3_000, categoria: .alimentacion, fecha: haceDias(7 * semana + k - 1))) }
            }
            try contexto.save()

            let envio = try XCTUnwrap(try servicio.evaluarGastoHormiga(categoria: .alimentacion, ahora: ahora))
            XCTAssertEqual(envio.motivo, .gastoHormiga)
            XCTAssertEqual(envio.categoriaGasto, .alimentacion)
            XCTAssertEqual(envio.consejo?.categoria, .gastoHormiga)
            let aviso = try XCTUnwrap(programador.programados.last)
            XCTAssertNil(aviso.fecha)                                  // Inmediato.
            XCTAssertEqual(aviso.subtitulo, "Gasto hormiga detectado")
            XCTAssertTrue(aviso.cuerpo.contains(Formato.pesos(115_714)), aviso.cuerpo)

            // Máximo un aviso por categoría cada siete días.
            XCTAssertNil(try servicio.evaluarGastoHormiga(categoria: .alimentacion, ahora: ahora))
        }
    }

    // MARK: - RF-23: valoración

    func testValorarConsejo() throws {
        let (contenedor, servicio, _) = try crearServicio()
        try withExtendedLifetime(contenedor) {
            try servicio.programarSemanal(ahora: ahora)
            let envio = try XCTUnwrap(try servicio.recibidos(ahora: ahora).first)
            XCTAssertNil(envio.util)
            try servicio.valorar(envio, util: true)
            XCTAssertEqual(try servicio.recibidos(ahora: ahora).first?.util, true)
        }
    }
}
