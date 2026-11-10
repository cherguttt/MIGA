//
//  GestorAlertasTests.swift
//  ControlDeGastosTests
//
//  PRUEBAS del CU-04 «Evaluar umbral y notificar» (Sprint 2).
//  Implementan los casos CP-07, CP-08, CP-09 y CP-10 del Plan de pruebas (Tabla 5),
//  con los mismos datos del portafolio: presupuesto de Alimentación de $130.000.
//

import XCTest
import SwiftData
@testable import ControlDeGastos

@MainActor
final class GestorAlertasTests: XCTestCase {

    // MARK: - Preparación

    /// Base de datos en memoria con un presupuesto de $130.000 en Alimentación (mes actual),
    /// más un servicio de transacciones que usa el notificador simulado.
    private func escenario(notificacionesActivas: Bool = true)
        -> (ModelContainer, ServicioTransacciones, NotificadorSimulado, Presupuesto) {
        let contenedor = ContenedorDatos.crear(enMemoria: true)
        let contexto = contenedor.mainContext
        contexto.insert(PerfilUsuario(
            nombre: "Prueba", ingresoMensualReferencia: 800_000,
            consentimientoAceptado: true, notificacionesActivas: notificacionesActivas))
        let periodo = PeriodoMensual()
        let presupuesto = Presupuesto(categoria: .alimentacion, mes: periodo.mes, anio: periodo.anio, montoMaximo: 130_000)
        contexto.insert(presupuesto)
        try? contexto.save()
        let notificador = NotificadorSimulado()
        let servicio = ServicioTransacciones(contexto: contexto, notificador: notificador)
        return (contenedor, servicio, notificador, presupuesto)
    }

    /// Registra un gasto de Alimentación con la fecha actual.
    private func gastar(_ monto: Decimal, _ servicio: ServicioTransacciones) throws {
        try servicio.registrarGasto(monto: monto, categoria: .alimentacion, fecha: .now, descripcion: nil)
    }

    // MARK: - Cálculo del umbral (función pura)

    func testUmbralAlcanzadoEnLosLimites() {
        let tope: Decimal = 130_000
        XCTAssertNil(GestorAlertas.umbralAlcanzado(acumulado: 90_999, montoMaximo: tope))   // 69,99 %
        XCTAssertEqual(GestorAlertas.umbralAlcanzado(acumulado: 91_000, montoMaximo: tope), .setenta)
        XCTAssertEqual(GestorAlertas.umbralAlcanzado(acumulado: 104_000, montoMaximo: tope), .ochenta)
        XCTAssertEqual(GestorAlertas.umbralAlcanzado(acumulado: 117_000, montoMaximo: tope), .noventa)
        XCTAssertEqual(GestorAlertas.umbralAlcanzado(acumulado: 200_000, montoMaximo: tope), .noventa) // sobre el 100 %
        XCTAssertNil(GestorAlertas.umbralAlcanzado(acumulado: 50_000, montoMaximo: 0))       // sin límite válido
    }

    // MARK: - CP-07, CP-08, CP-09

    /// CP-07: presupuesto $130.000, acumulado $91.000 → alerta del 70 %; alerta70Enviada = true.
    func testCP07AlertaAl70() throws {
        let (contenedor, servicio, notificador, presupuesto) = escenario()
        try gastar(91_000, servicio)
        XCTAssertEqual(notificador.enviadas.map(\.umbral), [.setenta])
        XCTAssertTrue(presupuesto.alerta70Enviada)
        XCTAssertFalse(presupuesto.alerta80Enviada)
        XCTAssertEqual(notificador.enviadas.first?.titulo, "Alimentación alcanzó el 70 %")
        withExtendedLifetime(contenedor) {}
    }

    /// CP-08: acumulado $104.000 (en dos gastos) → se envía la alerta del 80 % después de la del 70 %.
    func testCP08AlertaAl80() throws {
        let (contenedor, servicio, notificador, presupuesto) = escenario()
        try gastar(91_000, servicio)
        try gastar(13_000, servicio)   // Acumulado: $104.000 = 80 %
        XCTAssertEqual(notificador.enviadas.map(\.umbral), [.setenta, .ochenta])
        XCTAssertTrue(presupuesto.alerta80Enviada)
        XCTAssertEqual(notificador.enviadas.last?.cuerpo(),
                       "Llevas \(Formato.pesos(104_000)) de \(Formato.pesos(130_000)) este mes.")
        withExtendedLifetime(contenedor) {}
    }

    /// CP-09: acumulado $117.000 → alerta del 90 %; alerta90Enviada = true.
    func testCP09AlertaAl90() throws {
        let (contenedor, servicio, notificador, presupuesto) = escenario()
        try gastar(104_000, servicio)
        try gastar(13_000, servicio)   // Acumulado: $117.000 = 90 %
        XCTAssertEqual(notificador.enviadas.last?.umbral, .noventa)
        XCTAssertTrue(presupuesto.alerta90Enviada)
        withExtendedLifetime(contenedor) {}
    }

    // MARK: - CP-10 y reglas de no duplicidad

    /// CP-10: con alerta80Enviada = true, un gasto que deja el avance entre 80 % y 90 %
    /// NO envía una segunda alerta del 80 %.
    func testCP10SinAlertaDuplicadaDel80() throws {
        let (contenedor, servicio, notificador, presupuesto) = escenario()
        try gastar(104_000, servicio)            // 80 % → 1 alerta
        XCTAssertTrue(presupuesto.alerta80Enviada)
        try gastar(5_000, servicio)              // 83,8 % → ninguna alerta nueva
        XCTAssertEqual(notificador.enviadas.count, 1)
        withExtendedLifetime(contenedor) {}
    }

    /// Si el gasto salta directo al 95 %, se envía SOLO la alerta del 90 % y se marcan los
    /// umbrales inferiores (no llegan después avisos del 70 % ni del 80 %).
    func testSaltoDirectoAl90MarcaUmbralesInferiores() throws {
        let (contenedor, servicio, notificador, presupuesto) = escenario()
        try gastar(124_000, servicio)
        XCTAssertEqual(notificador.enviadas.map(\.umbral), [.noventa])
        XCTAssertTrue(presupuesto.alerta70Enviada && presupuesto.alerta80Enviada && presupuesto.alerta90Enviada)
        try gastar(1_000, servicio)
        XCTAssertEqual(notificador.enviadas.count, 1)
        withExtendedLifetime(contenedor) {}
    }

    /// Flujo alternativo del CU-04: sin permiso de notificaciones no se envía nada
    /// ni se marca el umbral.
    func testSinPermisoNoSeNotifica() throws {
        let (contenedor, servicio, notificador, presupuesto) = escenario(notificacionesActivas: false)
        try gastar(110_000, servicio)
        XCTAssertTrue(notificador.enviadas.isEmpty)
        XCTAssertFalse(presupuesto.alerta80Enviada)
        withExtendedLifetime(contenedor) {}
    }

    /// Precondición del CU-04: una categoría sin presupuesto no genera alertas.
    func testCategoriaSinPresupuestoNoGeneraAlerta() throws {
        let (contenedor, servicio, notificador, _) = escenario()
        try servicio.registrarGasto(monto: 500_000, categoria: .salud, fecha: .now, descripcion: nil)
        XCTAssertTrue(notificador.enviadas.isEmpty)
        withExtendedLifetime(contenedor) {}
    }

    /// Al eliminar un gasto y bajar del umbral, el indicador se restablece y se puede avisar de nuevo.
    func testEliminarGastoRestableceIndicador() throws {
        let (contenedor, servicio, notificador, presupuesto) = escenario()
        let gasto = try servicio.registrarGasto(monto: 104_000, categoria: .alimentacion, fecha: .now, descripcion: nil)
        XCTAssertTrue(presupuesto.alerta80Enviada)
        try servicio.eliminar(gasto)                 // Acumulado vuelve a $0
        XCTAssertFalse(presupuesto.alerta70Enviada || presupuesto.alerta80Enviada)
        try gastar(104_000, servicio)
        XCTAssertEqual(notificador.enviadas.count, 2) // Se volvió a avisar
        withExtendedLifetime(contenedor) {}
    }
}
