//
//  AjustesViewModelTests.swift
//  ControlDeGastosTests
//
//  PRUEBAS UNITARIAS del ViewModel de Ajustes (RF-02: ingreso mensual de referencia).
//

import XCTest
import SwiftData
@testable import ControlDeGastos

@MainActor
final class AjustesViewModelTests: XCTestCase {

    private func perfilDePrueba() -> PerfilUsuario {
        PerfilUsuario(nombre: "Camila", ingresoMensualReferencia: 800_000, consentimientoAceptado: true)
    }

    /// Al cargar, el ingreso se muestra con separadores de miles.
    func testCargarMuestraIngresoFormateado() {
        let modelo = AjustesViewModel()
        modelo.cargar(desde: perfilDePrueba())
        XCTAssertEqual(modelo.ingresoTexto, "800.000")
    }

    /// Un ingreso válido actualiza el perfil.
    func testIngresoValidoActualizaPerfil() {
        let modelo = AjustesViewModel()
        let perfil = perfilDePrueba()
        modelo.ingresoCambio("950000", en: perfil)
        XCTAssertEqual(modelo.ingresoTexto, "950.000")
        XCTAssertEqual(perfil.ingresoMensualReferencia, 950_000)
    }

    /// Borrar el campo NO deja el ingreso del perfil en cero.
    func testCampoVacioNoModificaPerfil() {
        let modelo = AjustesViewModel()
        let perfil = perfilDePrueba()
        modelo.ingresoCambio("", en: perfil)
        XCTAssertEqual(perfil.ingresoMensualReferencia, 800_000)
    }
}
