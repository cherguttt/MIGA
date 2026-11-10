//
//  PresupuestosViewModelTests.swift
//  ControlDeGastosTests
//
//  PRUEBAS del ViewModel de Presupuestos y del período mensual (Sprint 2).
//

import XCTest
@testable import ControlDeGastos

@MainActor
final class PresupuestosViewModelTests: XCTestCase {

    /// Las ocho categorías aparecen siempre, con su límite (o sin él) y lo gastado del mes.
    func testFilasDelMes() {
        let modelo = PresupuestosViewModel()
        let p = modelo.periodo
        let presupuestos = [
            Presupuesto(categoria: .alimentacion, mes: p.mes, anio: p.anio, montoMaximo: 130_000),
            Presupuesto(categoria: .servicios, mes: p.mes, anio: p.anio, montoMaximo: 150_000),
            Presupuesto(categoria: .salud, mes: p.anterior.mes, anio: p.anterior.anio, montoMaximo: 99_000) // otro mes
        ]
        let gastos = [
            Transaccion(monto: 106_600, categoria: .alimentacion, fecha: .now),
            Transaccion(monto: 136_500, categoria: .servicios, fecha: .now)
        ]
        let filas = modelo.filas(presupuestos: presupuestos, transacciones: gastos)
        // Una fila por categoría. Se compara con `allCases.count` para que la prueba no se rompa
        // al agregar una categoría (falló al incorporar «Pago Créditos»).
        XCTAssertEqual(filas.count, CategoriaGasto.allCases.count)
        let alimentacion = filas.first { $0.categoria == .alimentacion }!
        XCTAssertEqual(alimentacion.porcentaje, 82)
        XCTAssertEqual(alimentacion.estado, .atencion)                      // Naranjo
        XCTAssertEqual(filas.first { $0.categoria == .servicios }?.estado, .critico)  // Rojo (91 %)
        XCTAssertNil(filas.first { $0.categoria == .salud }?.montoMaximo)   // El de otro mes no cuenta
        XCTAssertEqual(modelo.totalPresupuestado(filas), 280_000)
    }

    /// Colores de la barra según los cortes 70 % y 90 %.
    func testEstadoAvance() {
        XCTAssertEqual(EstadoAvance.para(gastado: 50_000, montoMaximo: nil), .sinLimite)
        XCTAssertEqual(EstadoAvance.para(gastado: 69_000, montoMaximo: 100_000), .enRango)
        XCTAssertEqual(EstadoAvance.para(gastado: 70_000, montoMaximo: 100_000), .atencion)
        XCTAssertEqual(EstadoAvance.para(gastado: 90_000, montoMaximo: 100_000), .critico)
    }

    /// El botón «Guardar» del editor se habilita solo con un monto mayor a cero.
    func testPuedeGuardarSoloConMontoPositivo() {
        let modelo = PresupuestosViewModel()
        modelo.montoTexto = ""
        XCTAssertFalse(modelo.puedeGuardar)
        modelo.montoTexto = "0"
        XCTAssertFalse(modelo.puedeGuardar)
        modelo.montoTexto = "130.000"
        XCTAssertTrue(modelo.puedeGuardar)
    }

    /// El período mensual cruza correctamente el cambio de año.
    func testPeriodoCruzaElAnio() {
        let diciembre = PeriodoMensual(mes: 12, anio: 2026)
        XCTAssertEqual(diciembre.siguiente, PeriodoMensual(mes: 1, anio: 2027))
        XCTAssertEqual(PeriodoMensual(mes: 1, anio: 2027).anterior, diciembre)
        XCTAssertEqual(diciembre.desplazado(meses: 14), PeriodoMensual(mes: 2, anio: 2028))
    }

    /// La categoría «Otros» (por ejemplo, una pensión de alimentos) funciona igual que las demás:
    /// aparece al final, acepta un límite y calcula su avance.
    func testCategoriaOtros() {
        XCTAssertEqual(CategoriaGasto.allCases.count, 8)
        XCTAssertEqual(CategoriaGasto.allCases.last, .otros)
        XCTAssertEqual(CategoriaGasto.otros.nombre, "Otros")
        XCTAssertEqual(CategoriaGasto.otros.rawValue, "otros")   // Así se guarda en SQLite.

        let modelo = PresupuestosViewModel()
        let p = modelo.periodo
        let filas = modelo.filas(
            presupuestos: [Presupuesto(categoria: .otros, mes: p.mes, anio: p.anio, montoMaximo: 250_000)],
            transacciones: [Transaccion(monto: 200_000, categoria: .otros, fecha: .now, descripcion: "Pensión de alimentos")]
        )
        let otros = filas.last!
        XCTAssertEqual(otros.categoria, .otros)
        XCTAssertEqual(otros.porcentaje, 80)
        XCTAssertEqual(otros.estado, .atencion)
    }

    /// «Pago Créditos» (tarjeta de crédito, línea o crédito de consumo) se puede presupuestar
    /// como las demás y queda justo antes de «Otros».
    func testCategoriaPagoCreditos() {
        XCTAssertEqual(CategoriaGasto.pagoCreditos.nombre, "Pago Créditos")
        XCTAssertEqual(CategoriaGasto.pagoCreditos.rawValue, "pagoCreditos")   // Así se guarda en SQLite.
        let todas = CategoriaGasto.allCases
        XCTAssertEqual(todas[todas.count - 2], .pagoCreditos)
        let p = PeriodoMensual()
        let filas = PresupuestosViewModel().filas(
            presupuestos: [Presupuesto(categoria: .pagoCreditos, mes: p.mes, anio: p.anio, montoMaximo: 200_000)],
            transacciones: [Transaccion(monto: 180_000, categoria: .pagoCreditos, fecha: .now, descripcion: "Tarjeta de crédito")]
        )
        let fila = filas.first { $0.categoria == .pagoCreditos }
        XCTAssertEqual(fila?.porcentaje, 90)
    }
}
