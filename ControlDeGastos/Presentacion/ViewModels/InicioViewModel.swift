//
//  InicioViewModel.swift
//  ControlDeGastos
//
//  CAPA: Presentación — estado del panel de la pestaña «Inicio» (Sprint 3, CU-05, RF-16).
//
//  Sigue la Figura 5 del portafolio: la vista pide el resumen (`cargarResumen`), el ViewModel
//  se lo solicita al Motor Analítico y publica el resultado para que la vista lo dibuje.
//  Como la clase es @Observable, al cambiar `resumen` la pantalla se actualiza sola.
//

import Foundation
import Observation
import SwiftUI   // Para los colores e íconos del estado de la proyección.

@Observable
final class InicioViewModel {

    /// Resumen del mes en curso; `nil` mientras no se ha calculado.
    private(set) var resumen: ResumenMensual?

    /// CU-05, pasos 2 a 9. Recibe los datos que la vista ya leyó de la base de datos con
    /// @Query (así el panel se actualiza solo al registrar o borrar un gasto) y le pide
    /// al Motor Analítico el cálculo del resumen.
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

/// EXTENSIÓN en la capa de presentación: la lógica decide el estado (EstadoProyeccion) y
/// aquí solo se decide cómo se VE (color e ícono). Así la lógica no depende de SwiftUI.
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
