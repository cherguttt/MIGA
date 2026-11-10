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
/// `Equatable` permite comparar dos valores con `==` (útil en las pruebas:
/// por ejemplo, comprobar que la lista de errores contiene `.montoVacio`).
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

struct ValidadorFormulario {

    /// Devuelve la lista de errores del formulario; si está vacía, el formulario es válido.
    /// Es una «función pura»: con los mismos datos de entrada, siempre da el mismo resultado,
    /// sin modificar nada externo. Por eso es muy fácil de probar.
    static func validar(
        montoTexto: String,
        categoria: CategoriaGasto?,
        fecha: Date,
        ahora: Date = .now
    ) -> [ErrorValidacion] {
        // `var` porque la lista irá creciendo. `[ErrorValidacion]` = arreglo de errores.
        var errores: [ErrorValidacion] = []

        // `if let`: «si el texto se puede convertir en monto, guárdalo en `monto` y entra aquí».
        if let monto = Formato.monto(desde: montoTexto) {
            if monto <= 0 { errores.append(.montoNoPositivo) }   // Ej.: el usuario escribió "0".
        } else {
            errores.append(.montoVacio)                           // No escribió ningún número.
        }

        if categoria == nil { errores.append(.categoriaFaltante) }
        // Igual que en el servicio: se tolera 1 minuto por el avance del reloj.
        if fecha > ahora.addingTimeInterval(60) { errores.append(.fechaFutura) }
        return errores
    }
}
