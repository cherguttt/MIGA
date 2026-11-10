//
//  ServicioNotificaciones.swift
//  ControlDeGastos
//
//  CAPA: Lógica de negocio — notificaciones locales de iOS.
//  - Sprint 1: solicita el permiso de notificaciones (CU-01, paso 4).
//  - Sprint 2: envía las alertas de presupuesto (CU-04) y permite verlas con la app abierta.
//  - Sprint 5: programa el consejo semanal y el aviso de gasto hormiga (CU-07), y abre
//    la pestaña Educación al tocar la notificación de un consejo.
//
//  «Locales» significa que las genera el propio iPhone, sin servidores externos:
//  ningún dato del usuario sale del dispositivo.
//

import Foundation
import UserNotifications   // Framework de Apple para notificaciones.
import Observation         // Sprint 5: macro @Observable.

enum ServicioNotificaciones {

    /// Solicita autorización al usuario. Devuelve `true` si la otorga.
    /// iOS muestra su propio cuadro de diálogo solo la PRIMERA vez; después recuerda la respuesta.
    static func solicitarPermiso() async -> Bool {
        do {
            // `UNUserNotificationCenter.current()` es el centro de notificaciones de la app.
            // Pedimos permiso para: mostrar alertas, emitir sonido y poner un número en el ícono.
            return try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    /// Consulta a iOS si las notificaciones están autorizadas EN ESTE MOMENTO.
    /// El usuario puede cambiar el permiso en la app Ajustes del iPhone en cualquier momento,
    /// por eso la app lo vuelve a revisar cada vez que pasa a primer plano (ContentView).
    static func estaAutorizado() async -> Bool {
        let ajustes = await UNUserNotificationCenter.current().notificationSettings()
        switch ajustes.authorizationStatus {
        case .authorized, .provisional, .ephemeral: return true
        default: return false   // .denied (rechazado) o .notDetermined (aún no se pregunta).
        }
    }
}

// MARK: - Notificador real (Sprint 2)

/// Implementación del protocolo `Notificador` (ver GestorAlertas.swift) que entrega la alerta
/// a iOS como NOTIFICACIÓN LOCAL: la genera el propio iPhone, sin internet ni servidores.
struct NotificadorLocal: Notificador {
    func enviar(_ alerta: AlertaPresupuesto) {
        // Contenido de la notificación (mockup P9 del portafolio).
        let contenido = UNMutableNotificationContent()
        contenido.title = alerta.titulo            // «Alimentación alcanzó el 80 %»
        contenido.subtitle = alerta.subtitulo      // «Alerta de presupuesto»
        contenido.body = alerta.cuerpo()           // «Llevas $104.000 de $130.000 este mes.»
        contenido.sound = .default
        contenido.threadIdentifier = "alertas-presupuesto"   // Agrupa las alertas en el Centro de notificaciones.

        // `trigger: nil` = entregar de inmediato (sin programarla para más tarde).
        let solicitud = UNNotificationRequest(identifier: alerta.identificador, content: contenido, trigger: nil)
        UNUserNotificationCenter.current().add(solicitud) { _ in }
    }
}

// MARK: - Programador real de consejos (Sprint 5)

/// Implementación del protocolo `ProgramadorConsejos` (ver ServicioConsejos.swift).
struct ProgramadorConsejosLocal: ProgramadorConsejos {
    func programar(_ aviso: AvisoConsejo) {
        let contenido = UNMutableNotificationContent()
        contenido.title = aviso.titulo          // «El costo oculto del café diario»
        contenido.subtitle = aviso.subtitulo    // «Consejo semanal»
        contenido.body = aviso.cuerpo
        contenido.sound = .default
        contenido.threadIdentifier = "consejos"

        // UNCalendarNotificationTrigger: dispara la notificación en una fecha y hora del
        // calendario (por ejemplo, lunes 12 de octubre a las 9:00). `repeats: false` porque
        // cada lunes lleva un consejo distinto: se programa uno por semana.
        var disparador: UNNotificationTrigger?
        if let fecha = aviso.fecha {
            let componentes = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: fecha)
            disparador = UNCalendarNotificationTrigger(dateMatching: componentes, repeats: false)
        }
        let solicitud = UNNotificationRequest(identifier: aviso.identificador, content: contenido, trigger: disparador)
        UNUserNotificationCenter.current().add(solicitud) { _ in }
    }

    func cancelar(identificadores: [String]) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identificadores)
    }
}

// MARK: - Navegación al tocar una notificación (Sprint 5)

/// Recuerda qué consejo debe abrirse cuando el usuario toca su notificación (CU-07, paso 5).
/// `@Observable`: PrincipalView y EducacionView se enteran del cambio y navegan solas.
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

/// Por defecto, iOS NO muestra una notificación si la app está en pantalla. Como la alerta
/// se genera justo al confirmar un gasto (con la app abierta), este «delegado» le indica a
/// iOS que la muestre igual, como un banner en la parte superior.
///
/// DELEGADO: un objeto al que otro objeto (aquí, el centro de notificaciones) le pregunta
/// qué hacer en ciertas situaciones. Se registra en ControlDeGastosApp.swift.
final class DelegadoNotificaciones: NSObject, UNUserNotificationCenterDelegate {
    /// Instancia única y compartida. iOS guarda el delegado como referencia «débil», así que
    /// alguien debe mantenerlo vivo: lo hace esta constante estática.
    static let compartido = DelegadoNotificaciones()

    /// iOS llama a este método cuando llega una notificación con la app en primer plano.
    /// `nonisolated` indica que puede ejecutarse fuera del hilo principal.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]   // Mostrar banner, dejarla en el Centro de notificaciones y sonar.
    }

    /// Sprint 5: iOS llama a este método cuando el usuario TOCA una notificación.
    /// Si es un consejo («consejo-<id>»), se pide abrir ese consejo en la pestaña Educación.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let identificador = response.notification.request.identifier
        guard identificador.hasPrefix("consejo-"),
              let id = UUID(uuidString: String(identificador.dropFirst("consejo-".count))) else { return }
        // La navegación cambia la interfaz, así que se hace en el hilo principal.
        await MainActor.run { NavegacionConsejos.compartida.envioPorAbrir = id }
    }
}
