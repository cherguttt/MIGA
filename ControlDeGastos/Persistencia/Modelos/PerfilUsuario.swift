//
//  PerfilUsuario.swift
//  ControlDeGastos
//
//  CAPA: Persistencia (modelo de datos) — entidad PerfilUsuario, sección 4.6.2 del portafolio.
//
//  ¿QUÉ ES UN MODELO DE SWIFTDATA?
//  Es una clase de Swift marcada con `@Model`. SwiftData lee sus propiedades y crea
//  automáticamente una TABLA en la base de datos SQLite, con una COLUMNA por propiedad.
//  Nosotros nunca escribimos SQL: trabajamos con objetos Swift normales.
//
//  La aplicación es de un solo usuario: existe una única fila (instancia) de este modelo.
//

import Foundation   // Tipos básicos: Date (fecha), Decimal (número exacto), UUID (identificador).
import SwiftData    // Framework de persistencia que gestiona la base de datos SQLite.

// `@Model` es una «macro»: código que el compilador expande por nosotros.
// Convierte la clase en una entidad persistente (tabla) y la hace observable,
// es decir, las vistas se actualizan solas cuando cambia un valor.
@Model
// `final class`: una clase que no puede heredarse. Los modelos de SwiftData deben ser clases.
final class PerfilUsuario {

    /// Identificador único del perfil.
    /// `@Attribute(.unique)` le pide a SwiftData que no permita dos filas con el mismo id.
    /// `UUID` es un identificador aleatorio de 128 bits (prácticamente imposible de repetir).
    @Attribute(.unique) var id: UUID

    /// Nombre del usuario. `String` = texto.
    var nombre: String

    /// Ingreso líquido mensual usado como referencia para los presupuestos.
    /// Usamos `Decimal` (y no `Double`) porque para dinero necesitamos exactitud:
    /// `Double` puede producir errores de redondeo como 0,1 + 0,2 = 0,30000000000000004.
    var ingresoMensualReferencia: Decimal

    /// Divisa del usuario; por defecto, pesos chilenos.
    var moneda: String

    /// Indica si el usuario aceptó la política de privacidad (Ley N° 21.719).
    /// `Bool` solo puede ser `true` (verdadero) o `false` (falso).
    var consentimientoAceptado: Bool

    /// Fecha y hora en que se aceptó la política de privacidad.
    /// El signo `?` lo hace OPCIONAL: puede tener una fecha o estar vacío (`nil`).
    var fechaConsentimiento: Date?

    /// Indica si el usuario autorizó las notificaciones locales.
    var notificacionesActivas: Bool

    /// Indica si se exige Face ID o código al abrir la aplicación.
    var bloqueoBiometricoActivo: Bool

    /// Fecha de creación del perfil.
    var fechaCreacion: Date

    /// Sprint 5: el usuario quiere recibir el consejo semanal (lunes a las 9:00).
    /// Se declara con un valor por defecto (`= true`) para que SwiftData pueda agregar la
    /// columna a una base de datos existente sin perder los perfiles ya guardados
    /// (migración ligera). Se cambia en la pestaña Ajustes.
    var consejoSemanalActivo: Bool = true

    /// INICIALIZADOR (`init`): la función que se ejecuta al crear un perfil nuevo.
    /// Los parámetros con `=` tienen un valor por defecto, así que al crear un perfil
    /// podemos omitirlos. Ejemplo: PerfilUsuario(nombre: "Ana", ingresoMensualReferencia: 800000,
    /// consentimientoAceptado: true)
    init(
        nombre: String,
        ingresoMensualReferencia: Decimal,
        moneda: String = "CLP",
        consentimientoAceptado: Bool,
        fechaConsentimiento: Date? = nil,
        notificacionesActivas: Bool = false,
        bloqueoBiometricoActivo: Bool = false,
        fechaCreacion: Date = .now          // `.now` = la fecha y hora actuales.
    ) {
        // `self.` se refiere a la propiedad del objeto; a la derecha está el parámetro recibido.
        self.id = UUID()                    // Se genera un identificador nuevo automáticamente.
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
