//
//  ValidadorFormulario.swift
//  ControlDeGastos
//
//  CAPA: Presentación — reglas de validación del formulario de gasto (RF-06).
//  Es una estructura independiente de la interfaz para poder probarla con XCTest
//  (casos de prueba CP-03 a CP-05 del portafolio).
//

import Foundation

/// Posibles errores del formulario.
enum ErrorValidacion: Equatable {
    case montoVacio
    case montoNoPositivo
    case categoriaFaltante
    case fechaFutura

    /// Mensaje que se muestra al usuario para cada error.
    var mensaje: String {
        switch self {
        case .montoVacio: return "Ingresa el monto del gasto."
        case .montoNoPositivo: return "El monto debe ser mayor a cero."
        case .categoriaFaltante: return "Selecciona una categoría."
        case .fechaFutura: return "La fecha no puede ser futura."
        }
    }
}

/// Valida el monto, la categoría y la fecha del formulario en tiempo real (RF-06).
struct ValidadorFormulario {
    /// Devuelve la lista de errores del formulario; si está vacía, el formulario es válido.
    static func validar(
        montoTexto: String,
        categoria: CategoriaGasto?,
        fecha: Date,
        ahora: Date = .now
    ) -> [ErrorValidacion] {
        var errores: [ErrorValidacion] = []

        if let monto = Formato.monto(desde: montoTexto) {
            if monto <= 0 { errores.append(.montoNoPositivo) }
        } else {
            errores.append(.montoVacio)
        }

        if categoria == nil { errores.append(.categoriaFaltante) }
        if fecha > ahora.addingTimeInterval(60) { errores.append(.fechaFutura) }
        return errores
    }
}
