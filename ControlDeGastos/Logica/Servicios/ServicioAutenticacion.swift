//
//  ServicioAutenticacion.swift
//  ControlDeGastos
//
//  CAPA: Lógica de negocio — bloqueo de la aplicación con Face ID, Touch ID o el código
//  del dispositivo, mediante el framework LocalAuthentication (RF-03, RNF-02).
//

import Foundation
import LocalAuthentication

/// Bloqueo de la app con Face ID, Touch ID o el código del dispositivo (RF-03).
enum ServicioAutenticacion {
    /// Indica si el dispositivo puede autenticar al usuario (biometría o código).
    static var disponible: Bool {
        LAContext().canEvaluatePolicy(.deviceOwnerAuthentication, error: nil)
    }

    /// Nombre del método disponible, para mostrarlo en pantalla («Face ID», «Touch ID»…).
    static var nombreMetodo: String {
        let contexto = LAContext()
        _ = contexto.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        switch contexto.biometryType {
        case .faceID: return "Face ID"
        case .touchID: return "Touch ID"
        default: return "código del dispositivo"
        }
    }

    /// Solicita la autenticación al usuario.
    static func autenticar(motivo: String) async -> Bool {
        let contexto = LAContext()
        contexto.localizedCancelTitle = "Cancelar"
        guard contexto.canEvaluatePolicy(.deviceOwnerAuthentication, error: nil) else {
            return true
        }
        do {
            return try await contexto.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: motivo)
        } catch {
            return false
        }
    }
}
