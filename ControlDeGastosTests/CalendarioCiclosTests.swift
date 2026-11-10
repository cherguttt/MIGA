//
//  CalendarioCiclosTests.swift
//  ControlDeGastosTests
//
//  PRUEBAS del ciclo de gastos configurable (después del Sprint 5).
//  Ejemplo principal (el del usuario): hoy es 5 de noviembre de 2026, los ciclos son meses
//  calendario y se cambia el inicio al día 25.
//    - Ciclos pasados: no cambian.
//    - Ciclo actual: 1 nov – 24 nov (transición).
//    - Desde el 25 nov: 25 nov – 24 dic, 25 dic – 24 ene, …
//

import XCTest
import SwiftData
@testable import ControlDeGastos

@MainActor
final class CalendarioCiclosTests: XCTestCase {

    /// Calendario fijo (gregoriano, hora de Chile) para que las pruebas no dependan del iPhone.
    private var calendario: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "America/Santiago")!
        return c
    }

    private func fecha(_ anio: Int, _ mes: Int, _ dia: Int, _ hora: Int = 0) -> Date {
        calendario.date(from: DateComponents(year: anio, month: mes, day: dia, hour: hora))!
    }

    private var base: CalendarioCiclos { CalendarioCiclos(calendario: calendario) }
    /// Cambio al día 25 hecho el 5 de noviembre a mediodía.
    private var al25: CalendarioCiclos { base.cambiando(diaInicio: 25, ahora: fecha(2026, 11, 5, 12)) }

    private func comprobar(_ ciclo: Ciclo, clave: (Int, Int), desde: Date, hasta: Date,
                           file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(ciclo.clave, PeriodoMensual(mes: clave.0, anio: clave.1), file: file, line: line)
        XCTAssertEqual(ciclo.inicio, desde, file: file, line: line)
        XCTAssertEqual(ciclo.fin, hasta, file: file, line: line)
    }

    // MARK: - Sin cambios: meses calendario

    func testSinCambiosLosCiclosSonMesesCalendario() {
        comprobar(base.ciclo(contiene: fecha(2026, 11, 5, 12)), clave: (11, 2026), desde: fecha(2026, 11, 1), hasta: fecha(2026, 12, 1))
        comprobar(base.ciclo(clave: PeriodoMensual(mes: 2, anio: 2027)), clave: (2, 2027), desde: fecha(2027, 2, 1), hasta: fecha(2027, 3, 1))
        XCTAssertEqual(base.diaInicio(), 1)
    }

    // MARK: - Cambio al día 25 (ejemplo del usuario)

    func testCambioAl25CreaCicloDeTransicion() {
        let ciclos = al25
        XCTAssertEqual(ciclos.cambios.count, 1)
        XCTAssertEqual(ciclos.cambios.first?.vigenteDesde, fecha(2026, 11, 25))
        // Pasado intacto.
        comprobar(ciclos.ciclo(contiene: fecha(2026, 10, 15)), clave: (10, 2026), desde: fecha(2026, 10, 1), hasta: fecha(2026, 11, 1))
        // Transición: 1 al 24 de noviembre.
        comprobar(ciclos.ciclo(contiene: fecha(2026, 11, 5, 12)), clave: (11, 2026), desde: fecha(2026, 11, 1), hasta: fecha(2026, 11, 25))
        // Primer ciclo nuevo: 25 nov – 24 dic.
        comprobar(ciclos.ciclo(contiene: fecha(2026, 11, 30)), clave: (12, 2026), desde: fecha(2026, 11, 25), hasta: fecha(2026, 12, 25))
        // Cruce de año: 25 dic – 24 ene.
        comprobar(ciclos.ciclo(contiene: fecha(2026, 12, 26)), clave: (1, 2027), desde: fecha(2026, 12, 25), hasta: fecha(2027, 1, 25))
        // Buscar por identificador da el mismo resultado.
        XCTAssertEqual(ciclos.ciclo(clave: PeriodoMensual(mes: 12, anio: 2026)), ciclos.ciclo(contiene: fecha(2026, 12, 1)))
        // Día vigente: 1 hasta el 24 de noviembre; 25 desde ahí.
        XCTAssertEqual(ciclos.diaInicio(en: fecha(2026, 11, 5)), 1)
        XCTAssertEqual(ciclos.diaInicio(en: fecha(2026, 11, 26)), 25)
        XCTAssertEqual(ciclos.diaInicioFinal, 25)
    }

    /// Si el nuevo día ya pasó en el mes, la transición se alarga hasta el mes siguiente.
    func testCambioADiaYaPasadoAlargaLaTransicion() {
        let ciclos = base.cambiando(diaInicio: 3, ahora: fecha(2026, 11, 5, 12))
        comprobar(ciclos.ciclo(contiene: fecha(2026, 11, 5, 12)), clave: (11, 2026), desde: fecha(2026, 11, 1), hasta: fecha(2026, 12, 3))
        comprobar(ciclos.ciclo(contiene: fecha(2026, 12, 10)), clave: (12, 2026), desde: fecha(2026, 12, 3), hasta: fecha(2027, 1, 3))
    }

    /// Si el usuario cambia de nuevo antes de que rija el cambio, se reemplaza (no se acumula).
    func testCambiarDeOpinionAntesDeQueRija() {
        let ciclos = al25.cambiando(diaInicio: 10, ahora: fecha(2026, 11, 8, 12))
        XCTAssertEqual(ciclos.cambios.count, 1)
        XCTAssertEqual(ciclos.cambios.first?.diaInicio, 10)
        comprobar(ciclos.ciclo(contiene: fecha(2026, 11, 8, 12)), clave: (11, 2026), desde: fecha(2026, 11, 1), hasta: fecha(2026, 11, 10))
    }

    /// Volver al día que rige cancela el cambio programado.
    func testVolverAlDiaVigenteCancelaElCambio() {
        let ciclos = al25.cambiando(diaInicio: 1, ahora: fecha(2026, 11, 8, 12))
        XCTAssertTrue(ciclos.cambios.isEmpty)
        comprobar(ciclos.ciclo(contiene: fecha(2026, 11, 8, 12)), clave: (11, 2026), desde: fecha(2026, 11, 1), hasta: fecha(2026, 12, 1))
    }

    /// Dos cambios el mismo día: vale el último (no queda una transición de un día).
    func testDosCambiosElMismoDia() {
        let primero = base.cambiando(diaInicio: 25, ahora: fecha(2026, 11, 25, 10))   // Rige desde hoy.
        let segundo = primero.cambiando(diaInicio: 10, ahora: fecha(2026, 11, 25, 18))
        XCTAssertEqual(segundo.cambios.count, 1)
        comprobar(segundo.ciclo(contiene: fecha(2026, 11, 25, 18)), clave: (11, 2026), desde: fecha(2026, 11, 1), hasta: fecha(2026, 12, 10))
    }

    /// Un segundo cambio, después de que el primero ya rige, conserva el historial anterior.
    func testDosCambiosConservanElHistorial() {
        let ciclos = al25.cambiando(diaInicio: 10, ahora: fecha(2026, 12, 1, 12))
        XCTAssertEqual(ciclos.cambios.count, 2)
        comprobar(ciclos.ciclo(contiene: fecha(2026, 10, 15)), clave: (10, 2026), desde: fecha(2026, 10, 1), hasta: fecha(2026, 11, 1))
        comprobar(ciclos.ciclo(contiene: fecha(2026, 11, 10)), clave: (11, 2026), desde: fecha(2026, 11, 1), hasta: fecha(2026, 11, 25))
        comprobar(ciclos.ciclo(contiene: fecha(2026, 12, 1, 12)), clave: (12, 2026), desde: fecha(2026, 11, 25), hasta: fecha(2026, 12, 10))
        comprobar(ciclos.ciclo(contiene: fecha(2026, 12, 20)), clave: (1, 2027), desde: fecha(2026, 12, 10), hasta: fecha(2027, 1, 10))
    }

    /// Los ciclos quedan seguidos (sin huecos ni días repetidos) y sus identificadores
    /// avanzan de a uno, incluso con varios cambios.
    func testCiclosSeguidosYNumeradosEnOrden() {
        let ciclos = al25.cambiando(diaInicio: 10, ahora: fecha(2026, 12, 1, 12))
        var ciclo = ciclos.ciclo(contiene: fecha(2026, 8, 15))
        for _ in 0..<18 {
            let siguiente = ciclos.ciclo(contiene: ciclo.fin)
            XCTAssertEqual(siguiente.inicio, ciclo.fin)
            XCTAssertEqual(siguiente.clave, ciclo.clave.siguiente)
            XCTAssertEqual(ciclos.ciclo(clave: siguiente.clave), siguiente)
            ciclo = siguiente
        }
    }

    // MARK: - Proyección con ciclo de transición

    /// El resumen usa los días reales del ciclo: la transición dura 24 días.
    func testResumenUsaLosDiasDelCiclo() {
        let ciclos = al25
        let gastos = [
            Transaccion(monto: 10_000, categoria: .alimentacion, fecha: fecha(2026, 10, 31, 12)),   // Ciclo anterior.
            Transaccion(monto: 24_000, categoria: .alimentacion, fecha: fecha(2026, 11, 3, 12)),
            Transaccion(monto: 6_000, categoria: .transporte, fecha: fecha(2026, 11, 25, 12))       // Ciclo siguiente.
        ]
        let resumen = MotorAnalitico.calcularResumen(
            transacciones: gastos, presupuestos: [], periodo: PeriodoMensual(mes: 11, anio: 2026),
            ahora: fecha(2026, 11, 10, 12), calendario: calendario, ciclos: ciclos)
        XCTAssertEqual(resumen.diasDelMes, 24)
        XCTAssertEqual(resumen.diasTranscurridos, 10)
        XCTAssertEqual(resumen.gastoTotal, 24_000)
        XCTAssertEqual(resumen.velocidadDiaria, 2_400)   // V = 24.000 / 10
        XCTAssertEqual(resumen.proyeccion, 57_600)       // P = 2.400 × 24

        let siguiente = MotorAnalitico.calcularResumen(
            transacciones: gastos, presupuestos: [], periodo: PeriodoMensual(mes: 12, anio: 2026),
            ahora: fecha(2026, 11, 10, 12), calendario: calendario, ciclos: ciclos)
        XCTAssertEqual(siguiente.diasDelMes, 30)          // 25 nov – 24 dic.
        XCTAssertEqual(siguiente.diasTranscurridos, 0)    // Ciclo futuro.
    }

    // MARK: - Textos

    func testReglaEnPalabras() {
        XCTAssertEqual(AjustesViewModel.regla(1), "del 1 al último día de cada mes")
        XCTAssertEqual(AjustesViewModel.regla(25), "del 25 de cada mes al 24 del mes siguiente")
    }

    // MARK: - Servicio con base de datos

    private func crearServicio() -> (ModelContainer, ServicioCiclos) {
        let contenedor = ContenedorDatos.crear(enMemoria: true)
        return (contenedor, ServicioCiclos(contexto: contenedor.mainContext, calendario: calendario, actualizarApp: false))
    }

    /// El cambio se guarda en la base y los gastos NO se modifican: solo se reagrupan.
    func testServicioGuardaElCambioSinTocarLosGastos() throws {
        let (contenedor, servicio) = crearServicio()
        try withExtendedLifetime(contenedor) {
            let contexto = contenedor.mainContext
            for (monto, dia) in [(20_000, 3), (30_000, 20), (40_000, 28)] {
                contexto.insert(Transaccion(monto: Decimal(monto), categoria: .alimentacion, fecha: fecha(2026, 11, dia, 12)))
            }
            try contexto.save()

            try servicio.cambiarDiaInicio(25, ahora: fecha(2026, 11, 5, 12))
            XCTAssertEqual(try servicio.cambios().count, 1)
            XCTAssertEqual(try contexto.fetchCount(FetchDescriptor<Transaccion>()), 3)   // Ningún gasto borrado.

            let motor = MotorAnalitico(contexto: contexto, calendario: calendario, ciclos: try servicio.calendarioCiclos())
            XCTAssertEqual(try motor.gastoAcumulado(categoria: .alimentacion, periodo: PeriodoMensual(mes: 11, anio: 2026)), 50_000)
            XCTAssertEqual(try motor.gastoAcumulado(categoria: .alimentacion, periodo: PeriodoMensual(mes: 12, anio: 2026)), 40_000)

            // Cambiar de opinión reemplaza el cambio; volver al día 1 lo elimina.
            try servicio.cambiarDiaInicio(10, ahora: fecha(2026, 11, 8, 12))
            XCTAssertEqual(try servicio.cambios().map(\.diaInicio), [10])
            try servicio.cambiarDiaInicio(1, ahora: fecha(2026, 11, 8, 12))
            XCTAssertTrue(try servicio.cambios().isEmpty)
        }
    }

    /// Solo se aceptan los días 1 a 28.
    func testDiaInvalido() throws {
        let (contenedor, servicio) = crearServicio()
        // `try`: Swift considera que el bloque puede lanzar errores porque contiene `try`
        // (aunque esté dentro de XCTAssertThrowsError), así que la llamada también lo necesita.
        try withExtendedLifetime(contenedor) {
            XCTAssertThrowsError(try servicio.cambiarDiaInicio(29, ahora: fecha(2026, 11, 5, 12)))
            XCTAssertThrowsError(try servicio.cambiarDiaInicio(0, ahora: fecha(2026, 11, 5, 12)))
        }
    }

    /// Si el ciclo se acorta y el gasto baja de un umbral ya avisado, el umbral se restablece.
    func testAlAcortarseElCicloSeRestablecenLasAlertas() throws {
        let (contenedor, servicio) = crearServicio()
        try withExtendedLifetime(contenedor) {
            let contexto = contenedor.mainContext
            let presupuesto = Presupuesto(categoria: .alimentacion, mes: 11, anio: 2026, montoMaximo: 100_000)
            presupuesto.alerta70Enviada = true
            presupuesto.alerta80Enviada = true
            contexto.insert(presupuesto)
            contexto.insert(Transaccion(monto: 50_000, categoria: .alimentacion, fecha: fecha(2026, 11, 3, 12)))
            contexto.insert(Transaccion(monto: 30_000, categoria: .alimentacion, fecha: fecha(2026, 11, 28, 12)))
            try contexto.save()

            try servicio.cambiarDiaInicio(25, ahora: fecha(2026, 11, 5, 12))   // Noviembre queda en $50.000 (50 %).
            XCTAssertFalse(presupuesto.alerta70Enviada)
            XCTAssertFalse(presupuesto.alerta80Enviada)
        }
    }
}
