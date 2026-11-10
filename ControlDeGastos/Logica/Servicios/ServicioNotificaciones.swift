//
//  ServicioNotificaciones.swift
//  ControlDeGastos
//
//  CAPA: Lógica de negocio — notificaciones locales de iOS.
//  - Sprint 1: solicita el permiso de notificaciones (CU-01, paso 4).
//  - Sprint 2: envía las alertas de presupuesto (CU-04) y permite verlas con la app abierta.
//  - Sprint 5: programa el consejo semanal y el aviso de gasto hormiga (CU-07), y abre
//  la pestaña Educación al tocar la notificación de un consejo.
//

import Foundation
import UserNotifications
import Observation

/// Permiso de notificaciones locales de iOS.
enum ServicioNotificaciones {
    /// Solicita autorización al usuario.
    static func solicitarPermiso() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    /// Consulta a iOS si las notificaciones están autorizadas EN ESTE MOMENTO.
    static func estaAutorizado() async -> Bool {
        let ajustes = await UNUserNotificationCenter.current().notificationSettings()
        switch ajustes.authorizationStatus {
        case .authorized, .provisional, .ephemeral: return true
        default: return false
        }
    }
}

// MARK: - Notificador real (Sprint 2)

/// Implementación del protocolo `Notificador` (ver GestorAlertas.swift) que entrega la alerta a iOS como
/// NOTIFICACIÓN LOCAL: la genera el propio iPhone, sin internet ni servidores.
struct NotificadorLocal: Notificador {
    /// Muestra la alerta como notificación local inmediata.
    func enviar(_ alerta: AlertaPresupuesto) {
        let contenido = UNMutableNotificationContent()
        contenido.title = alerta.titulo
        contenido.subtitle = alerta.subtitulo
        contenido.body = alerta.cuerpo()
        contenido.sound = .default
        contenido.threadIdentifier = "alertas-presupuesto"

        let solicitud = UNNotificationRequest(identifier: alerta.identificador, content: contenido, trigger: nil)
        UNUserNotificationCenter.current().add(solicitud) { _ in }
    }
}

// MARK: - Programador real de consejos (Sprint 5)

/// Implementación del protocolo `ProgramadorConsejos` (ver ServicioConsejos.swift).
struct ProgramadorConsejosLocal: ProgramadorConsejos {
    /// Programa el consejo como notificación local en su fecha.
    func programar(_ aviso: AvisoConsejo) {
        let contenido = UNMutableNotificationContent()
        contenido.title = aviso.titulo
        contenido.subtitle = aviso.subtitulo
        contenido.body = aviso.cuerpo
        contenido.sound = .default
        contenido.threadIdentifier = "consejos"

        var disparador: UNNotificationTrigger?
        if let fecha = aviso.fecha {
            let componentes = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: fecha)
            disparador = UNCalendarNotificationTrigger(dateMatching: componentes, repeats: false)
        }
        let solicitud = UNNotificationRequest(identifier: aviso.identificador, content: contenido, trigger: disparador)
        UNUserNotificationCenter.current().add(solicitud) { _ in }
    }

    /// Cancela las notificaciones pendientes con esos identificadores.
    func cancelar(identificadores: [String]) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identificadores)
    }
}

// MARK: - Navegación al tocar una notificación (Sprint 5)

/// Recuerda qué consejo debe abrirse cuando el usuario toca su notificación (CU-07, paso 5).
@Observable
final class NavegacionConsejos {
    static let compartida = NavegacionConsejos()
    /// Identificador del envío por abrir; las vistas lo vuelven a `nil` al abrirlo.
    var envioPorAbrir: UUID?
    /// Consejo por abrir al tocar el aviso emergente que aparece al abrir la app.
    var consejoPorAbrir: UUID?

    /// `true` si hay algo pendiente de abrir en la pestaña Educación.
    var hayPendiente: Bool { envioPorAbrir != nil || consejoPorAbrir != nil }
}

// MARK: - Mostrar notificaciones con la app abierta

/// Por defecto, iOS NO muestra una notificación si la app está en pantalla.
final class DelegadoNotificaciones: NSObject, UNUserNotificationCenterDelegate {
    /// Instancia única y compartida. iOS guarda el delegado como referencia «débil», así que alguien debe
    /// mantenerlo vivo: lo hace esta constante estática.
    static let compartido = DelegadoNotificaciones()

    /// iOS llama a este método cuando llega una notificación con la app en primer plano.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }

    /// Sprint 5: iOS llama a este método cuando el usuario TOCA una notificación.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let identificador = response.notification.request.identifier
        guard identificador.hasPrefix("consejo-"),
              let id = UUID(uuidString: String(identificador.dropFirst("consejo-".count))) else { return }
        await MainActor.run { NavegacionConsejos.compartida.envioPorAbrir = id }
    }
}
