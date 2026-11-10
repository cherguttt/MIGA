//
//  ControlDeGastosApp.swift
//  ControlDeGastos
//
//  CAPA: App (punto de entrada). Es el PRIMER código que se ejecuta al abrir la aplicación.
//
//  ¿QUÉ HACE?
//  1. Crea la base de datos local (SQLite gestionada con SwiftData).
//  2. Abre la ventana principal con la vista raíz `ContentView`.
//  3. Comparte la base de datos con TODAS las vistas mediante `.modelContainer(...)`.
//
//  ORDEN SUGERIDO DE LECTURA DEL PROYECTO:
//  App → Modelos → ContenedorDatos → Utilidades → Servicios → ViewModels → Vistas → Componentes.
//

import SwiftUI            // Framework de interfaz gráfica declarativa de Apple.
import SwiftData          // Framework de persistencia (base de datos).
import UserNotifications  // Sprint 2: para mostrar las alertas con la app abierta.

// `@main` le indica a Swift que AQUÍ empieza el programa. Solo puede haber uno por app.
@main
// `struct` es una estructura (un tipo de valor, más liviano que una clase).
// `: App` significa que adopta el protocolo App: SwiftUI exige que tenga una propiedad `body`.
struct ControlDeGastosApp: App {

    // `let` declara una CONSTANTE (no cambia después de asignarse); `var` sería una variable.
    // `private` = solo se puede usar dentro de este archivo/estructura.
    // Creamos el contenedor UNA sola vez al iniciar la app (ver ContenedorDatos.swift).
    private let contenedor = ContenedorDatos.crear()

    /// `init` de la app: se ejecuta una vez, al abrirla.
    /// Sprint 2: registra el delegado que permite ver las alertas de presupuesto como banner
    /// aunque la app esté en pantalla (ver DelegadoNotificaciones en ServicioNotificaciones.swift).
    init() {
        UNUserNotificationCenter.current().delegate = DelegadoNotificaciones.compartido

        // Ciclo de gastos: se carga el día de inicio configurado ANTES de mostrar cualquier
        // pantalla. Al ejecutar las pruebas (XCTest) no se carga, para que las pruebas no
        // dependan de lo que haya configurado en el simulador.
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil {
            ServicioCiclos(contexto: contenedor.mainContext).cargar()
        }
    }

    // `body` describe QUÉ muestra la app. `some Scene` significa «algún tipo de escena»;
    // Swift deduce el tipo exacto por nosotros (se llama «tipo opaco»).
    var body: some Scene {
        // `WindowGroup` es la ventana principal de la app en iPhone.
        WindowGroup {
            ContentView()   // Vista raíz: decide qué pantalla mostrar (ver ContentView.swift).
        }
        // MODIFICADOR: los métodos que empiezan con punto modifican lo que está arriba.
        // Este inyecta la base de datos en el «entorno» de SwiftUI, para que cualquier vista
        // pueda leerla con `@Query` o con `@Environment(\.modelContext)`.
        .modelContainer(contenedor)
    }
}
