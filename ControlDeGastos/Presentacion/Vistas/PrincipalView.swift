//
//  PrincipalView.swift
//  ControlDeGastos
//
//  CAPA: Presentación — barra de pestañas (TabView) de la aplicación.
//  Sprint 1: Inicio, Registrar y Ajustes. Sprint 2: Presupuestos. Sprint 5: Educación.
//

import SwiftUI
import SwiftData

struct PrincipalView: View {

    /// Enum ANIDADO (definido dentro de la vista) con las pestañas posibles.
    /// `Hashable` es requisito para usarlo como identificador de la selección del TabView.
    enum Pestana: Hashable {
        case inicio, registrar, presupuestos, educacion, ajustes
    }

    /// Pestaña visible en este momento. Al cambiarla por código, el TabView cambia de pestaña.
    @State private var pestanaSeleccionada: Pestana = .inicio

    /// Sprint 5: contexto de la base de datos, para preparar los consejos al abrir la app.
    @Environment(\.modelContext) private var contexto
    /// Sprint 5: navegación pedida al tocar la notificación de un consejo.
    private let navegacion = NavegacionConsejos.compartida

    // MARK: Consejo emergente al abrir la app

    /// Consejo que se está mostrando en el aviso emergente (`nil` = no hay aviso).
    @State private var consejoEmergente: Consejo?
    /// Fase de la app: activa, inactiva o en segundo plano.
    @Environment(\.scenePhase) private var faseEscena
    /// `@AppStorage` guarda un valor pequeño en las preferencias de la app (UserDefaults),
    /// no en la base de datos. Aquí: si el usuario quiere el consejo al abrir (se cambia en Ajustes)…
    @AppStorage("consejoAlAbrir") private var consejoAlAbrir = true
    /// …y el último consejo mostrado, para no repetirlo dos veces seguidas.
    @AppStorage("ultimoConsejoEmergente") private var ultimoConsejoEmergente = ""
    /// Segundos que el aviso permanece en pantalla si el usuario no lo toca.
    private let segundosVisible = 10

    var body: some View {
        // `$pestanaSeleccionada` (con signo $) es un BINDING: un enlace de doble vía.
        // El TabView puede LEER la pestaña actual y también MODIFICARLA cuando el usuario toca otra.
        TabView(selection: $pestanaSeleccionada) {
            // InicioView recibe un closure: cuando el usuario toca «Registrar gasto» en la lista
            // vacía, se ejecuta este código y saltamos a la pestaña Registrar.
            InicioView(irARegistrar: { pestanaSeleccionada = .registrar })
                .tabItem { Label("Inicio", systemImage: "house") }   // Ícono y texto de la pestaña.
                .tag(Pestana.inicio)                                 // Identificador de la pestaña.

            RegistroGastoView()
                .tabItem { Label("Registrar", systemImage: "plus.circle") }
                .tag(Pestana.registrar)

            PresupuestosView()   // Sprint 2 (CU-03).
                .tabItem { Label("Presupuestos", systemImage: "wallet.bifold") }
                .tag(Pestana.presupuestos)

            EducacionView()      // Sprint 5 (CU-07).
                .tabItem { Label("Educación", systemImage: "lightbulb") }
                .tag(Pestana.educacion)

            AjustesView()
                .tabItem { Label("Ajustes", systemImage: "gearshape") }
                .tag(Pestana.ajustes)
        }
        // Aviso emergente con un consejo, encima de las pestañas (`overlay` = capa superior).
        .overlay(alignment: .top) {
            if let consejo = consejoEmergente {
                AvisoConsejoView(
                    consejo: consejo,
                    alAbrir: { abrir(consejo) },
                    alCerrar: { consejoEmergente = nil }
                )
                .padding(.top, 4)
                // Entra deslizándose desde arriba y sale de la misma forma.
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.spring(duration: 0.45), value: consejoEmergente?.id)
        // Cierre automático: `.task(id:)` se reinicia cada vez que cambia el consejo mostrado;
        // si el usuario lo cierra antes, la espera se cancela sola.
        .task(id: consejoEmergente?.id) {
            guard consejoEmergente != nil else { return }
            try? await Task.sleep(for: .seconds(segundosVisible))
            if !Task.isCancelled { consejoEmergente = nil }
        }
        // Sprint 5 (CU-07, paso 1): precarga los consejos la primera vez y deja programado
        // el consejo semanal. `.task` se ejecuta cuando aparece la pantalla principal
        // (al abrir la app o al desbloquearla). Luego muestra el consejo emergente.
        .task {
            ServicioConsejos(contexto: contexto).prepararAlIniciar()
            await mostrarConsejoEmergente()
        }
        // Al volver a la app desde segundo plano (sin bloqueo), también se muestra un consejo.
        .onChange(of: faseEscena) { anterior, nueva in
            if anterior == .background && nueva == .active {
                Task { await mostrarConsejoEmergente() }
            }
        }
        // Sprint 5 (CU-07, paso 5): al tocar la notificación de un consejo, se cambia a la
        // pestaña Educación, que abre el detalle del consejo.
        .onAppear { if navegacion.hayPendiente { pestanaSeleccionada = .educacion } }
        .onChange(of: navegacion.hayPendiente) { _, pendiente in
            if pendiente { pestanaSeleccionada = .educacion }
        }
    }

    /// Elige un consejo al azar y lo muestra, salvo que el usuario lo haya desactivado o que
    /// la app se haya abierto tocando una notificación (en ese caso ya se abre un consejo).
    private func mostrarConsejoEmergente() async {
        guard consejoAlAbrir, !navegacion.hayPendiente else { return }
        // Una pequeña pausa para que la pantalla termine de aparecer antes del aviso.
        try? await Task.sleep(for: .milliseconds(700))
        // Se consultan los consejos en ese momento (la primera vez recién se precargaron).
        let consejos = (try? ServicioConsejos(contexto: contexto).consejosActivos()) ?? []
        let consejo = EducacionViewModel.consejoAleatorio(
            de: consejos,
            excepto: UUID(uuidString: ultimoConsejoEmergente)
        )
        guard let consejo else { return }
        ultimoConsejoEmergente = consejo.id.uuidString
        consejoEmergente = consejo
    }

    /// Al tocar el aviso: se cierra y se abre el consejo en la pestaña Educación.
    private func abrir(_ consejo: Consejo) {
        consejoEmergente = nil
        navegacion.consejoPorAbrir = consejo.id
    }
}

#Preview {
    PrincipalView()
        .modelContainer(DatosDePrueba.contenedor)
}
