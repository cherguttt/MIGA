//
//  RegistroGastoViewModelTests.swift
//  ControlDeGastosTests
//
//  PRUEBAS del ViewModel de «Registrar gasto» con el monto que viene de una boleta
//  (Sprint 4: CU-06, paso 5, y RF-19).
//

import XCTest
import SwiftData
@testable import ControlDeGastos

@MainActor
final class RegistroGastoViewModelTests: XCTestCase {

    /// Precargar deja el monto con puntos de miles y marca el origen «boleta».
    func testPrecargarMontoDeBoleta() {
        let modelo = RegistroGastoViewModel()
        modelo.precargar(monto: 12_500)
        XCTAssertEqual(modelo.montoTexto, "12.500")
        XCTAssertEqual(modelo.origen, .boleta)
    }

    /// Al confirmar, el gasto se guarda con origen «boleta» y el formulario vuelve a «manual».
    func testConfirmarGuardaOrigenBoleta() throws {
        let contenedor = ContenedorDatos.crear(enMemoria: true)
        // `var`: ServicioTransacciones es un struct; para cambiarle el notificador debe ser variable.
        var servicio = ServicioTransacciones(contexto: contenedor.mainContext)
        servicio.notificador = NotificadorSimulado()   // Sin notificaciones reales.

        let modelo = RegistroGastoViewModel()
        modelo.precargar(monto: 12_500)
        modelo.categoria = .alimentacion
        modelo.confirmar(con: servicio)

        let guardadas = try contenedor.mainContext.fetch(FetchDescriptor<Transaccion>())
        XCTAssertEqual(guardadas.count, 1)
        XCTAssertEqual(guardadas.first?.monto, 12_500)
        XCTAssertEqual(guardadas.first?.origen, .boleta)
        XCTAssertEqual(modelo.origen, .manual)            // Listo para el siguiente gasto.
        XCTAssertEqual(modelo.montoTexto, "")
        XCTAssertTrue(modelo.mensajeConfirmacion?.contains("desde la boleta") ?? false)
    }

    /// Un gasto escrito a mano sigue guardándose como «manual».
    func testGastoManualSigueSiendoManual() throws {
        let contenedor = ContenedorDatos.crear(enMemoria: true)
        // `var`: ServicioTransacciones es un struct; para cambiarle el notificador debe ser variable.
        var servicio = ServicioTransacciones(contexto: contenedor.mainContext)
        servicio.notificador = NotificadorSimulado()

        let modelo = RegistroGastoViewModel()
        modelo.montoTexto = "3.500"
        modelo.categoria = .transporte
        modelo.confirmar(con: servicio)

        let guardadas = try contenedor.mainContext.fetch(FetchDescriptor<Transaccion>())
        XCTAssertEqual(guardadas.first?.origen, .manual)
    }

    /// Si el usuario borra el monto leído, lo que escriba después cuenta como manual.
    func testBorrarMontoVuelveAManual() {
        let modelo = RegistroGastoViewModel()
        modelo.precargar(monto: 12_500)
        modelo.normalizarMonto("")
        XCTAssertEqual(modelo.origen, .manual)
    }
}
