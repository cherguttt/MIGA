//
//  ValidadorFormularioTests.swift
//  ControlDeGastosTests
//
//  PRUEBAS UNITARIAS del validador del formulario de gasto (RF-06).
//  Corresponden a los casos CP-04 y CP-05 del Plan de pruebas (sección 4.4.11).
//

import XCTest
@testable import ControlDeGastos

@MainActor
final class ValidadorFormularioTests: XCTestCase {
    /// Fecha fija que usamos como «ahora».
    private let ahora = Date(timeIntervalSince1970: 1_790_000_000)

    /// Formulario completo y válido: no debe haber errores (base de CP-03).
    func testFormularioValidoNoTieneErrores() {
        let errores = ValidadorFormulario.validar(
            montoTexto: "15.000", categoria: .alimentacion, fecha: ahora, ahora: ahora)
        XCTAssertTrue(errores.isEmpty)
    }

    /// CP-04: confirmar con campos vacíos → el formulario informa monto y categoría faltantes.
    func testCamposVaciosInformanMontoYCategoria() {
        let errores = ValidadorFormulario.validar(
            montoTexto: "", categoria: nil, fecha: ahora, ahora: ahora)
        XCTAssertEqual(errores, [.montoVacio, .categoriaFaltante])
    }

    /// CP-05: monto $0 → el validador bloquea el registro.
    func testMontoCeroEsInvalido() {
        let errores = ValidadorFormulario.validar(
            montoTexto: "0", categoria: .transporte, fecha: ahora, ahora: ahora)
        XCTAssertEqual(errores, [.montoNoPositivo])
    }

    /// Una fecha de mañana no se acepta.
    func testFechaFuturaEsInvalida() {
        let manana = ahora.addingTimeInterval(86_400)
        let errores = ValidadorFormulario.validar(
            montoTexto: "5.000", categoria: .salud, fecha: manana, ahora: ahora)
        XCTAssertEqual(errores, [.fechaFutura])
    }

    /// Un gasto de ayer sí es válido (el usuario puede registrar gastos pasados).
    func testFechaPasadaEsValida() {
        let ayer = ahora.addingTimeInterval(-86_400)
        let errores = ValidadorFormulario.validar(
            montoTexto: "5.000", categoria: .salud, fecha: ayer, ahora: ahora)
        XCTAssertTrue(errores.isEmpty)
    }
}
