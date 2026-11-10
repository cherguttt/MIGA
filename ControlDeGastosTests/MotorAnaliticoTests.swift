//
//  MotorAnaliticoTests.swift
//  ControlDeGastosTests
//
//  PRUEBAS del Motor Analítico — pipeline 1: gasto acumulado real (Sprint 2, RF-09).
//

import XCTest
import SwiftData
@testable import ControlDeGastos

@MainActor
final class MotorAnaliticoTests: XCTestCase {

    /// El acumulado considera SOLO la categoría y el mes pedidos.
    func testAcumuladoPorCategoriaYMes() throws {
        let contenedor = ContenedorDatos.crear(enMemoria: true)
        let servicio = ServicioTransacciones(contexto: contenedor.mainContext, notificador: NotificadorSimulado())
        let motor = MotorAnalitico(contexto: contenedor.mainContext)
        let actual = PeriodoMensual()
        let mesPasado = actual.anterior.inicio().addingTimeInterval(86_400 * 5)   // Día 6 del mes anterior

        try servicio.registrarGasto(monto: 10_000, categoria: .alimentacion, fecha: .now, descripcion: nil)
        try servicio.registrarGasto(monto: 2_500, categoria: .alimentacion, fecha: .now, descripcion: nil)
        try servicio.registrarGasto(monto: 7_000, categoria: .transporte, fecha: .now, descripcion: nil)
        try servicio.registrarGasto(monto: 50_000, categoria: .alimentacion, fecha: mesPasado, descripcion: nil)

        XCTAssertEqual(try motor.gastoAcumulado(categoria: .alimentacion, periodo: actual), 12_500)
        XCTAssertEqual(try motor.gastoAcumulado(categoria: .transporte, periodo: actual), 7_000)
        XCTAssertEqual(try motor.gastoAcumulado(categoria: .alimentacion, periodo: actual.anterior), 50_000)
        XCTAssertEqual(try motor.gastoAcumulado(categoria: .salud, periodo: actual), 0)
    }

    /// Porcentaje truncado (no redondeado) y protegido contra división por cero.
    func testPorcentaje() {
        XCTAssertEqual(MotorAnalitico.porcentaje(106_600, de: 130_000), 82)
        XCTAssertEqual(MotorAnalitico.porcentaje(90_999, de: 130_000), 69)   // 69,99 % → 69
        XCTAssertEqual(MotorAnalitico.porcentaje(600_000, de: 800_000), 75)
        XCTAssertNil(MotorAnalitico.porcentaje(1_000, de: 0))
    }
}
