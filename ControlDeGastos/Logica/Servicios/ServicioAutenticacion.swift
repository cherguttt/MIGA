//
//  ServicioAutenticacion.swift
//  ControlDeGastos
//
//  CAPA: Lógica de negocio — bloqueo de la aplicación con Face ID, Touch ID o el código
//  del dispositivo, mediante el framework LocalAuthentication (RF-03, RNF-02).
//
//  IMPORTANTE: la app NUNCA ve la cara ni la huella del usuario. iOS hace la verificación
//  y solo nos responde «sí» o «no».
//

import Foundation
import LocalAuthentication   // Framework de Apple para Face ID / Touch ID / código.

enum ServicioAutenticacion {

    /// Indica si el dispositivo puede autenticar al usuario (biometría o código).
    /// `LAContext` es el objeto que se comunica con el sistema de autenticación de iOS.
    /// `.deviceOwnerAuthentication` = acepta biometría Y, como respaldo, el código del iPhone.
    static var disponible: Bool {
        LAContext().canEvaluatePolicy(.deviceOwnerAuthentication, error: nil)
    }

    /// Nombre del método disponible, para mostrarlo en pantalla («Face ID», «Touch ID»…).
    static var nombreMetodo: String {
        let contexto = LAContext()
        // `biometryType` solo se llena DESPUÉS de llamar a `canEvaluatePolicy`.
        // `_ =` descarta el resultado: nos interesa el efecto, no el valor devuelto.
        _ = contexto.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        switch contexto.biometryType {
        case .faceID: return "Face ID"
        case .touchID: return "Touch ID"
        default: return "código del dispositivo"   // `default` cubre cualquier otro caso.
        }
    }

    /// Solicita la autenticación al usuario.
    /// Si el dispositivo no tiene biometría ni código configurado, no se bloquea el acceso.
    ///
    /// `async` = función ASÍNCRONA: puede «esperar» (aquí, a que el usuario mire la pantalla)
    /// sin congelar la app. Quien la llama debe usar `await`.
    static func autenticar(motivo: String) async -> Bool {
        let contexto = LAContext()
        contexto.localizedCancelTitle = "Cancelar"   // Texto del botón para cancelar.
        guard contexto.canEvaluatePolicy(.deviceOwnerAuthentication, error: nil) else {
            return true   // Sin método disponible: dejamos pasar para no dejar al usuario fuera.
        }
        do {
            // `try await`: la llamada puede fallar (try) y además hay que esperarla (await).
            // `motivo` es el texto que iOS muestra explicando por qué pedimos autenticación.
            return try await contexto.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: motivo)
        } catch {
            return false  // El usuario canceló o falló la verificación.
        }
    }
}
