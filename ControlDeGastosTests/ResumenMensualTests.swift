//
//  ResumenMensualTests.swift
//  ControlDeGastosTests
//
//  PRUEBAS del Motor Analítico — pipeline 2: velocidad diaria, proyección y panel
//  (Sprint 3, CU-05, RF-14 y RF-15). Incluye el caso CP-11 del Plan de pruebas (Tabla 5)
//  y verifica la exactitud de los cálculos exigida por el RNF-08.
//

import XCTest
import SwiftData
@testable import ControlDeGastos

@MainActor
final class ResumenMensualTests: XCTestCase {

    /// Calendario fijo (Chile) para que las pruebas den siempre el mismo resultado.
    private var calendario: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "America/Santiago")!
        return c
    }

    private func fecha(_ dia: Int, _ mes: Int, _ anio: Int = 2026, hora: Int = 12) -> Date {
        calendario.date(from: DateComponents(year: anio, month: mes, day: dia, hour: hora))!
    }

    private func resumen(_ gastos: [Transaccion], _ presupuestos: [Presupuesto] = [], periodo: PeriodoMensual, ahora: Date) -> ResumenMensual {
        MotorAnalitico.calcularResumen(transacciones: gastos, presupuestos: presupuestos,
                                       periodo: periodo, ahora: ahora, calendario: calendario)
    }

    // MARK: - CP-11

    /// CP-11: día 10 de un mes de 30 días (septiembre de 2026) con $104.000 acumulados
    /// → V = $10.400/día y P = $312.000.
    func testCP11CalculoDeLaProyeccion() {
        let gastos = [
            Transaccion(monto: 60_000, categoria: .alimentacion, fecha: fecha(2, 9)),
            Transaccion(monto: 44_000, categoria: .servicios, fecha: fecha(9, 9))
        ]
        let r = resumen(gastos, periodo: PeriodoMensual(mes: 9, anio: 2026), ahora: fecha(10, 9, hora: 18))
        XCTAssertEqual(r.diasDelMes, 30)
        XCTAssertEqual(r.diasTranscurridos, 10)
        XCTAssertEqual(r.gastoTotal, 104_000)
        XCTAssertEqual(r.velocidadDiaria, 10_400)
        XCTAssertEqual(r.proyeccion, 312_000)
    }

    // MARK: - Escenario del mockup P2

    /// Datos del mockup P2: $342.800 al día 18 de un mes de 31 días, presupuesto $600.000
    /// → velocidad $19.044/día, proyección $590.378 y estado «Cerca del límite».
    func testEscenarioDelMockup() {
        let periodo = PeriodoMensual(mes: 10, anio: 2026)
        let gastos = [Transaccion(monto: 342_800, categoria: .alimentacion, fecha: fecha(5, 10))]
        let limites = [Presupuesto(categoria: .alimentacion, mes: 10, anio: 2026, montoMaximo: 600_000)]
        let r = resumen(gastos, limites, periodo: periodo, ahora: fecha(18, 10))
        XCTAssertEqual(r.diasDelMes, 31)
        XCTAssertEqual(Formato.pesos(r.velocidadDiaria), Formato.pesos(19_044))
        XCTAssertEqual(Formato.pesos(r.proyeccion), Formato.pesos(590_378))
        XCTAssertEqual(r.porcentajeUtilizado, 57)
        XCTAssertEqual(r.estado, .cercaDelLimite)
    }

    // MARK: - Estado de la proyección (CU-05, paso 6)

    func testEstadosDeLaProyeccion() {
        let periodo = PeriodoMensual(mes: 9, anio: 2026)          // 30 días
        let ahora = fecha(10, 9)
        let limite = [Presupuesto(categoria: .salud, mes: 9, anio: 2026, montoMaximo: 300_000)]
        func estado(gastado: Decimal) -> EstadoProyeccion {
            resumen([Transaccion(monto: gastado, categoria: .salud, fecha: fecha(1, 9))], limite, periodo: periodo, ahora: ahora).estado
        }
        XCTAssertEqual(estado(gastado: 89_000), .dentroDelPresupuesto)   // P = 267.000 (89 %)
        XCTAssertEqual(estado(gastado: 90_000), .cercaDelLimite)         // P = 270.000 (90 %)
        XCTAssertEqual(estado(gastado: 100_000), .cercaDelLimite)        // P = 300.000 (100 %)
        XCTAssertEqual(estado(gastado: 101_000), .sobreElPresupuesto)    // P = 303.000 (101 %)
        let sinLimites = resumen([Transaccion(monto: 1_000, categoria: .salud, fecha: fecha(1, 9))], periodo: periodo, ahora: ahora)
        XCTAssertEqual(sinLimites.estado, .sinPresupuesto)
    }

    // MARK: - Días transcurridos y gasto diario

    /// En un mes ya terminado se usan todos sus días; en un mes futuro, cero (sin dividir por cero).
    func testDiasTranscurridosSegunElMes() {
        let ahora = fecha(10, 9)
        let pasado = resumen([], periodo: PeriodoMensual(mes: 8, anio: 2026), ahora: ahora)
        XCTAssertEqual(pasado.diasTranscurridos, 31)
        let futuro = resumen([], periodo: PeriodoMensual(mes: 10, anio: 2026), ahora: ahora)
        XCTAssertEqual(futuro.diasTranscurridos, 0)
        XCTAssertEqual(futuro.velocidadDiaria, 0)
        XCTAssertEqual(futuro.proyeccion, 0)
    }

    /// El gráfico tiene una barra por día transcurrido, incluidos los días sin gastos,
    /// y suma los gastos de un mismo día. Los gastos de otros meses no se cuentan.
    func testGastoPorDia() {
        let gastos = [
            Transaccion(monto: 1_000, categoria: .transporte, fecha: fecha(3, 9, hora: 8)),
            Transaccion(monto: 2_500, categoria: .alimentacion, fecha: fecha(3, 9, hora: 20)),
            Transaccion(monto: 9_999, categoria: .alimentacion, fecha: fecha(28, 8))   // otro mes
        ]
        let r = resumen(gastos, periodo: PeriodoMensual(mes: 9, anio: 2026), ahora: fecha(5, 9))
        XCTAssertEqual(r.gastoPorDia.map(\.dia), [1, 2, 3, 4, 5])
        XCTAssertEqual(r.gastoPorDia.map(\.monto), [0, 0, 3_500, 0, 0])
        XCTAssertEqual(r.gastoTotal, 3_500)
        XCTAssertEqual(r.cantidadGastos, 2)
    }

    // MARK: - Avance por categoría

    /// Categorías ordenadas como en el mockup P2: con límite primero, de mayor a menor avance.
    func testOrdenDeCategorias() {
        let periodo = PeriodoMensual(mes: 10, anio: 2026)
        let gastos = [
            Transaccion(monto: 106_600, categoria: .alimentacion, fecha: fecha(5, 10)),
            Transaccion(monto: 136_500, categoria: .servicios, fecha: fecha(6, 10)),
            Transaccion(monto: 36_000, categoria: .transporte, fecha: fecha(7, 10)),
            Transaccion(monto: 5_000, categoria: .salud, fecha: fecha(8, 10))            // sin límite
        ]
        let limites = [
            Presupuesto(categoria: .alimentacion, mes: 10, anio: 2026, montoMaximo: 130_000),
            Presupuesto(categoria: .servicios, mes: 10, anio: 2026, montoMaximo: 150_000),
            Presupuesto(categoria: .transporte, mes: 10, anio: 2026, montoMaximo: 80_000),
            Presupuesto(categoria: .educacion, mes: 10, anio: 2026, montoMaximo: 80_000)  // sin gastos
        ]
        let r = resumen(gastos, limites, periodo: periodo, ahora: fecha(18, 10))
        XCTAssertEqual(r.categorias.map(\.categoria), [.servicios, .alimentacion, .transporte, .educacion, .salud])
        XCTAssertEqual(r.categorias.map(\.porcentaje), [91, 82, 45, 0, nil])
    }

    // MARK: - Integración con la base de datos (Figura 5)

    /// `resumenMensual` obtiene los datos desde SwiftData y entrega el mismo resultado.
    func testResumenDesdeLaBaseDeDatos() throws {
        let contenedor = ContenedorDatos.crear(enMemoria: true)
        let servicio = ServicioTransacciones(contexto: contenedor.mainContext, notificador: NotificadorSimulado())
        try ServicioPresupuestos(contexto: contenedor.mainContext)
            .guardar(montoMaximo: 100_000, categoria: .alimentacion, periodo: PeriodoMensual())
        try servicio.registrarGasto(monto: 20_000, categoria: .alimentacion, fecha: .now, descripcion: nil)
        let r = try MotorAnalitico(contexto: contenedor.mainContext).resumenMensual()
        XCTAssertEqual(r.gastoTotal, 20_000)
        XCTAssertEqual(r.presupuestoTotal, 100_000)
        XCTAssertEqual(r.categorias.first?.porcentaje, 20)
    }
}
