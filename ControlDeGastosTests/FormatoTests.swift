//
//  FormatoTests.swift
//  ControlDeGastosTests
//
//  PRUEBAS UNITARIAS de las funciones de formato de montos en pesos chilenos.
//

import XCTest
@testable import ControlDeGastos

@MainActor
final class FormatoTests: XCTestCase {

    /// Los separadores de miles se insertan cada tres dígitos.
    func testMilesAgregaSeparadores() {
        XCTAssertEqual(Formato.miles("12500"), "12.500")
        XCTAssertEqual(Formato.miles("1500000"), "1.500.000")
        XCTAssertEqual(Formato.miles("999"), "999")
    }

    /// Se eliminan letras y ceros a la izquierda.
    func testMilesLimpiaCaracteresYCeros() {
        XCTAssertEqual(Formato.miles("00a12b3"), "123")
        XCTAssertEqual(Formato.miles("000"), "0")
        XCTAssertEqual(Formato.miles(""), "")
    }

    /// El texto con puntos se convierte en un monto numérico exacto.
    func testMontoDesdeTexto() {
        XCTAssertEqual(Formato.monto(desde: "12.500"), Decimal(12_500))
        XCTAssertNil(Formato.monto(desde: ""))
    }
}
