//
//  ContentView.swift
//  ControlDeGastos
//
//  CAPA: Presentación — vista RAÍZ: decide qué pantalla mostrar según el estado del perfil.
//  - Sin perfil o sin consentimiento → Bienvenida (CU-01).
//  - Con bloqueo activo y sin desbloquear → Pantalla de bloqueo (RF-03).
//  - En otro caso → Pantalla principal con pestañas.
//

import SwiftUI
import SwiftData

/// Vista raíz: muestra la bienvenida, el bloqueo o la app según el estado del perfil.
struct ContentView: View {
    @Query private var perfiles: [PerfilUsuario]

    /// Contexto de la base de datos (Sprint 2: para actualizar el permiso de notificaciones).
    @Environment(\.modelContext) private var contexto

    @Environment(\.scenePhase) private var faseEscena

    @State private var desbloqueada = false

    /// El perfil del usuario (la app es de un solo usuario: tomamos el primero, si existe).
    private var perfil: PerfilUsuario? { perfiles.first }

    var body: some View {
        Group {
            if let perfil, perfil.consentimientoAceptado {
                if perfil.bloqueoBiometricoActivo && !desbloqueada {
                    BloqueoView { desbloqueada = true }
                } else {
                    PrincipalView()
                }
            } else {
                BienvenidaView { desbloqueada = true }
            }
        }
        .onChange(of: faseEscena) { _, nuevaFase in
            if nuevaFase == .background {
                desbloqueada = false
            }
            if nuevaFase == .active {
                Task { await actualizarPermisoNotificaciones() }
                if let perfil, perfil.consentimientoAceptado {
                    ServicioConsejos(contexto: contexto).prepararAlIniciar()
                }
            }
        }
        .task { await actualizarPermisoNotificaciones() }
    }

    /// Sincroniza `notificacionesActivas` del perfil con el permiso real de iOS.
    private func actualizarPermisoNotificaciones() async {
        guard let perfil, perfil.consentimientoAceptado else { return }
        let autorizado = await ServicioNotificaciones.estaAutorizado()
        if perfil.notificacionesActivas != autorizado {
            perfil.notificacionesActivas = autorizado
            try? contexto.save()
        }
    }
}

#Preview("Con perfil") {
    ContentView()
        .modelContainer(DatosDePrueba.contenedor)
}

#Preview("Primer inicio") {
    ContentView()
        .modelContainer(ContenedorDatos.crear(enMemoria: true))
}
