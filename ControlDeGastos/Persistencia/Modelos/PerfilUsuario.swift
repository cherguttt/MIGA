//
//  PerfilUsuario.swift
//  ControlDeGastos
//
//  CAPA: Persistencia (modelo de datos) — entidad PerfilUsuario, sección 4.6.2 del portafolio.
//

import Foundation
import SwiftData

/// Perfil único del usuario, con su ingreso de referencia y su consentimiento.
@Model
final class PerfilUsuario {
    /// Identificador único del perfil.
    @Attribute(.unique) var id: UUID

    /// Nombre del usuario.
    var nombre: String

    /// Ingreso líquido mensual usado como referencia para los presupuestos.
    var ingresoMensualReferencia: Decimal

    /// Divisa del usuario; por defecto, pesos chilenos.
    var moneda: String

    /// Indica si el usuario aceptó la política de privacidad (Ley N° 21.719).
    var consentimientoAceptado: Bool

    /// Fecha y hora en que se aceptó la política de privacidad.
    var fechaConsentimiento: Date?

    /// Indica si el usuario autorizó las notificaciones locales.
    var notificacionesActivas: Bool

    /// Indica si se exige Face ID o código al abrir la aplicación.
    var bloqueoBiometricoActivo: Bool

    /// Fecha de creación del perfil.
    var fechaCreacion: Date

    /// Sprint 5: el usuario quiere recibir el consejo semanal (lunes a las 9:00).
    var consejoSemanalActivo: Bool = true

    /// INICIALIZADOR (`init`): la función que se ejecuta al crear un perfil nuevo.
    init(
        nombre: String,
        ingresoMensualReferencia: Decimal,
        moneda: String = "CLP",
        consentimientoAceptado: Bool,
        fechaConsentimiento: Date? = nil,
        notificacionesActivas: Bool = false,
        bloqueoBiometricoActivo: Bool = false,
        fechaCreacion: Date = .now
    ) {
        self.id = UUID()
        self.nombre = nombre
        self.ingresoMensualReferencia = ingresoMensualReferencia
        self.moneda = moneda
        self.consentimientoAceptado = consentimientoAceptado
        self.fechaConsentimiento = fechaConsentimiento
        self.notificacionesActivas = notificacionesActivas
        self.bloqueoBiometricoActivo = bloqueoBiometricoActivo
        self.fechaCreacion = fechaCreacion
    }
}
