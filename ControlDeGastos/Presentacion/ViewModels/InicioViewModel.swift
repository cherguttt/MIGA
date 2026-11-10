//
//  InicioViewModel.swift
//  ControlDeGastos
//
//  CAPA: Presentación — estado del panel de la pestaña «Inicio» (Sprint 3, CU-05, RF-16).
//

import Foundation
import Observation
import SwiftUI

/// Estado del panel de Inicio: resumen del ciclo y proyección.
@Observable
final class InicioViewModel {
    /// Resumen del mes en curso; `nil` mientras no se ha calculado.
    private(set) var resumen: ResumenMensual?

    /// CU-05, pasos 2 a 9.
    func cargarResumen(transacciones: [Transaccion], presupuestos: [Presupuesto], ahora: Date = .now) {
        resumen = MotorAnalitico.calcularResumen(
            transacciones: transacciones,
            presupuestos: presupuestos,
            periodo: PeriodoMensual(ahora),
            ahora: ahora
        )
    }

    /// Flujo alternativo del CU-05: si no hay gastos en el mes se muestra el estado vacío.
    var sinGastos: Bool { (resumen?.cantidadGastos ?? 0) == 0 }
}

// MARK: - Apariencia del estado de la proyección

/// EXTENSIÓN en la capa de presentación: la lógica decide el estado (EstadoProyeccion) y aquí solo se decide
/// cómo se VE (color e ícono).
extension EstadoProyeccion {
    var color: Color {
        switch self {
        case .dentroDelPresupuesto: return .green
        case .cercaDelLimite: return .orange
        case .sobreElPresupuesto: return .red
        case .sinPresupuesto: return .secondary
        }
    }

    /// Nombre del ícono de SF Symbols.
    var icono: String {
        switch self {
        case .dentroDelPresupuesto: return "checkmark.circle"
        case .cercaDelLimite: return "exclamationmark.triangle"
        case .sobreElPresupuesto: return "exclamationmark.octagon"
        case .sinPresupuesto: return "questionmark.circle"
        }
    }
}
