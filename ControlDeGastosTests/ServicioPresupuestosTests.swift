//
//  ServicioPresupuestosTests.swift
//  ControlDeGastosTests
//
//  PRUEBAS del CU-03 «Configurar presupuesto por categoría» (Sprint 2, RF-08).
//

import XCTest
import SwiftData
@testable import ControlDeGastos

@MainActor
final class ServicioPresupuestosTests: XCTestCase {

    private func crear() -> (ModelContainer, ServicioPresupuestos) {
        let contenedor = ContenedorDatos.crear(enMemoria: true)
        return (contenedor, ServicioPresupuestos(contexto: contenedor.mainContext))
    }

    /// CU-03, paso 4: se guarda un límite válido.
    func testGuardarLimiteValido() throws {
        let (contenedor, servicio) = crear()
        let periodo = PeriodoMensual()
        try servicio.guardar(montoMaximo: 130_000, categoria: .alimentacion, periodo: periodo)
        XCTAssertEqual(try servicio.presupuesto(categoria: .alimentacion, periodo: periodo)?.montoMaximo, 130_000)
        withExtendedLifetime(contenedor) {}
    }

    /// CU-03, paso 4: un límite de $0 se rechaza.
    func testLimiteCeroSeRechaza() {
        let (contenedor, servicio) = crear()
        XCTAssertThrowsError(try servicio.guardar(montoMaximo: 0, categoria: .salud, periodo: PeriodoMensual())) { error in
            XCTAssertEqual(error as? ErrorPresupuesto, .montoInvalido)
        }
        withExtendedLifetime(contenedor) {}
    }

    /// Regla de la sección 4.6.4: a lo más un presupuesto por categoría, mes y año.
    /// Guardar dos veces la misma categoría ACTUALIZA el límite en vez de duplicarlo.
    func testGuardarDosVecesNoDuplica() throws {
        let (contenedor, servicio) = crear()
        let periodo = PeriodoMensual()
        try servicio.guardar(montoMaximo: 100_000, categoria: .transporte, periodo: periodo)
        try servicio.guardar(montoMaximo: 80_000, categoria: .transporte, periodo: periodo)
        let delMes = try servicio.presupuestos(de: periodo)
        XCTAssertEqual(delMes.count, 1)
        XCTAssertEqual(delMes.first?.montoMaximo, 80_000)
        withExtendedLifetime(contenedor) {}
    }

    /// CU-03, flujo alternativo: si el nuevo límite deja el gasto bajo un umbral ya
    /// notificado, ese indicador se restablece.
    func testSubirLimiteRestableceIndicadores() throws {
        let (contenedor, servicio) = crear()
        let periodo = PeriodoMensual()
        let transacciones = ServicioTransacciones(contexto: contenedor.mainContext, notificador: NotificadorSimulado())
        let presupuesto = try servicio.guardar(montoMaximo: 130_000, categoria: .alimentacion, periodo: periodo)
        try transacciones.registrarGasto(monto: 104_000, categoria: .alimentacion, fecha: .now, descripcion: nil)
        XCTAssertTrue(presupuesto.alerta70Enviada && presupuesto.alerta80Enviada)

        try servicio.guardar(montoMaximo: 140_000, categoria: .alimentacion, periodo: periodo) // 74 %
        XCTAssertTrue(presupuesto.alerta70Enviada)    // Sigue sobre el 70 %: no se restablece.
        XCTAssertFalse(presupuesto.alerta80Enviada)   // Quedó bajo el 80 %: se restablece.
        withExtendedLifetime(contenedor) {}
    }

    /// Copiar los límites del mes anterior sin pisar los que ya existen.
    func testCopiarDelMesAnterior() throws {
        let (contenedor, servicio) = crear()
        let actual = PeriodoMensual()
        try servicio.guardar(montoMaximo: 130_000, categoria: .alimentacion, periodo: actual.anterior)
        try servicio.guardar(montoMaximo: 80_000, categoria: .transporte, periodo: actual.anterior)
        try servicio.guardar(montoMaximo: 50_000, categoria: .transporte, periodo: actual)   // Ya existe
        let copiados = try servicio.copiarDelMesAnterior(a: actual)
        XCTAssertEqual(copiados, 1)
        XCTAssertEqual(try servicio.presupuesto(categoria: .alimentacion, periodo: actual)?.montoMaximo, 130_000)
        XCTAssertEqual(try servicio.presupuesto(categoria: .transporte, periodo: actual)?.montoMaximo, 50_000)
        withExtendedLifetime(contenedor) {}
    }
}
