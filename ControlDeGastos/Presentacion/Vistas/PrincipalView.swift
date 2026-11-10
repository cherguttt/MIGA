//
//  PrincipalView.swift
//  ControlDeGastos
//
//  CAPA: Presentación — barra de pestañas (TabView) de la aplicación.
//  Sprint 1: Inicio, Registrar y Ajustes. Sprint 2: Presupuestos. Sprint 5: Educación.
//

import SwiftUI
import SwiftData

/// Barra de pestañas de la app.
struct PrincipalView: View {
    /// Enum ANIDADO (definido dentro de la vista) con las pestañas posibles.
    enum Pestana: Hashable {
        case inicio, registrar, presupuestos, educacion, ajustes
    }

    /// Pestaña visible en este momento.
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
    /// `@AppStorage` guarda un valor pequeño en las preferencias de la app (UserDefaults), no en la base de
    /// datos.
    @AppStorage("consejoAlAbrir") private var consejoAlAbrir = true
    /// …y el último consejo mostrado, para no repetirlo dos veces seguidas.
    @AppStorage("ultimoConsejoEmergente") private var ultimoConsejoEmergente = ""
    /// Segundos que el aviso permanece en pantalla si el usuario no lo toca.
    private let segundosVisible = 10

    var body: some View {
        TabView(selection: $pestanaSeleccionada) {
            InicioView(irARegistrar: { pestanaSeleccionada = .registrar })
                .tabItem { Label("Inicio", systemImage: "house") }
                .tag(Pestana.inicio)

            RegistroGastoView()
                .tabItem { Label("Registrar", systemImage: "plus.circle") }
                .tag(Pestana.registrar)

            PresupuestosView()
                .tabItem { Label("Presupuestos", systemImage: "wallet.bifold") }
                .tag(Pestana.presupuestos)

            EducacionView()
                .tabItem { Label("Educación", systemImage: "lightbulb") }
                .tag(Pestana.educacion)

            AjustesView()
                .tabItem { Label("Ajustes", systemImage: "gearshape") }
                .tag(Pestana.ajustes)
        }
        .overlay(alignment: .top) {
            if let consejo = consejoEmergente {
                AvisoConsejoView(
                    consejo: consejo,
                    alAbrir: { abrir(consejo) },
                    alCerrar: { consejoEmergente = nil }
                )
                .padding(.top, 4)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.spring(duration: 0.45), value: consejoEmergente?.id)
        .task(id: consejoEmergente?.id) {
            guard consejoEmergente != nil else { return }
            try? await Task.sleep(for: .seconds(segundosVisible))
            if !Task.isCancelled { consejoEmergente = nil }
        }
        .task {
            ServicioConsejos(contexto: contexto).prepararAlIniciar()
            await mostrarConsejoEmergente()
        }
        .onChange(of: faseEscena) { anterior, nueva in
            if anterior == .background && nueva == .active {
                Task { await mostrarConsejoEmergente() }
            }
        }
        .onAppear { if navegacion.hayPendiente { pestanaSeleccionada = .educacion } }
        .onChange(of: navegacion.hayPendiente) { _, pendiente in
            if pendiente { pestanaSeleccionada = .educacion }
        }
    }

    /// Elige un consejo al azar y lo muestra, salvo que el usuario lo haya desactivado o que la app se haya
    /// abierto tocando una notificación (en ese caso ya se abre un consejo).
    private func mostrarConsejoEmergente() async {
        guard consejoAlAbrir, !navegacion.hayPendiente else { return }
        try? await Task.sleep(for: .milliseconds(700))
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
