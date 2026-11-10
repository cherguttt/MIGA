//
//  ControlDeGastosApp.swift
//  ControlDeGastos
//
//  CAPA: App (punto de entrada). Es el PRIMER código que se ejecuta al abrir la aplicación.
//

import SwiftUI
import SwiftData
import UserNotifications

/// Punto de entrada de MIGA: crea la base de datos y muestra la vista raíz.
@main
struct ControlDeGastosApp: App {
    private let contenedor = ContenedorDatos.crear()

    /// `init` de la app: se ejecuta una vez, al abrirla.
    init() {
        UNUserNotificationCenter.current().delegate = DelegadoNotificaciones.compartido

        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil {
            ServicioCiclos(contexto: contenedor.mainContext).cargar()
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(contenedor)
    }
}
