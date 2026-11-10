//
//  ContentView.swift
//  ControlDeGastos
//
//  CAPA: Presentación — vista RAÍZ: decide qué pantalla mostrar según el estado del perfil.
//  - Sin perfil o sin consentimiento → Bienvenida (CU-01).
//  - Con bloqueo activo y sin desbloquear → Pantalla de bloqueo (RF-03).
//  - En otro caso → Pantalla principal con pestañas.
//
//  IDEA CLAVE DE SWIFTUI: la interfaz es una FUNCIÓN DEL ESTADO.
//  No le decimos «cambia a tal pantalla»; describimos qué se ve en cada situación,
//  y SwiftUI redibuja solo cuando cambian los datos.
//

import SwiftUI
import SwiftData

// Toda pantalla o componente en SwiftUI es una `struct` que adopta el protocolo `View`.
struct ContentView: View {

    // PROPERTY WRAPPERS (las palabras con @ delante de una propiedad):
    //
    // `@Query`: consulta automática a la base de datos. Trae todos los PerfilUsuario
    // y se actualiza sola cuando se inserta, cambia o borra un perfil.
    @Query private var perfiles: [PerfilUsuario]

    /// Contexto de la base de datos (Sprint 2: para actualizar el permiso de notificaciones).
    @Environment(\.modelContext) private var contexto

    // `@Environment`: lee un valor que SwiftUI pone a disposición de todas las vistas.
    // `scenePhase` indica si la app está activa, inactiva o en segundo plano.
    @Environment(\.scenePhase) private var faseEscena

    // `@State`: estado PROPIO de esta vista. Cuando cambia, la vista se vuelve a dibujar.
    // Siempre se declara `private` porque solo esta vista lo maneja.
    @State private var desbloqueada = false

    /// El perfil del usuario (la app es de un solo usuario: tomamos el primero, si existe).
    private var perfil: PerfilUsuario? { perfiles.first }

    // `some View` = «alguna vista»; SwiftUI deduce el tipo exacto.
    var body: some View {
        // `Group` agrupa vistas sin añadir nada visual; aquí permite aplicar `.onChange` al conjunto.
        Group {
            // `if let perfil, perfil.consentimientoAceptado`: entra solo si existe un perfil
            // Y además aceptó la política. Ambas condiciones separadas por coma deben cumplirse.
            if let perfil, perfil.consentimientoAceptado {
                if perfil.bloqueoBiometricoActivo && !desbloqueada {
                    // Lo que va entre llaves es un CLOSURE: código que BloqueoView ejecutará
                    // cuando la autenticación sea exitosa («trailing closure»).
                    BloqueoView { desbloqueada = true }
                } else {
                    PrincipalView()
                }
            } else {
                // Al completar la bienvenida, marcamos la app como desbloqueada para no
                // pedir Face ID justo después de haberlo configurado.
                BienvenidaView { desbloqueada = true }
            }
        }
        // `.onChange(of:)` ejecuta código cada vez que cambia el valor observado.
        // Recibe el valor anterior y el nuevo; `_` ignora el anterior porque no lo usamos.
        .onChange(of: faseEscena) { _, nuevaFase in
            // Al pasar a segundo plano, la app se vuelve a bloquear.
            if nuevaFase == .background {
                desbloqueada = false
            }
            // Sprint 2: al volver a primer plano se revisa el permiso de notificaciones,
            // por si el usuario lo cambió en la app Ajustes del iPhone.
            if nuevaFase == .active {
                Task { await actualizarPermisoNotificaciones() }
                // Sprint 5: al volver a la app se renueva la programación de los consejos
                // semanales (siempre quedan 4 lunes programados).
                if let perfil, perfil.consentimientoAceptado {
                    ServicioConsejos(contexto: contexto).prepararAlIniciar()
                }
            }
        }
        // `.task` también se ejecuta al abrir la app por primera vez.
        .task { await actualizarPermisoNotificaciones() }
    }

    /// Sincroniza `notificacionesActivas` del perfil con el permiso real de iOS.
    /// Así el Gestor de Alertas sabe si puede enviar avisos (CU-04, flujo alternativo).
    private func actualizarPermisoNotificaciones() async {
        guard let perfil, perfil.consentimientoAceptado else { return }
        let autorizado = await ServicioNotificaciones.estaAutorizado()
        if perfil.notificacionesActivas != autorizado {
            perfil.notificacionesActivas = autorizado
            try? contexto.save()
        }
    }
}

// `#Preview` muestra la vista en el lienzo de Xcode (Canvas) sin ejecutar la app.
// Puede haber varias, con nombre, para ver distintos escenarios.
#Preview("Con perfil") {
    ContentView()
        .modelContainer(DatosDePrueba.contenedor)          // Base con datos de ejemplo.
}

#Preview("Primer inicio") {
    ContentView()
        .modelContainer(ContenedorDatos.crear(enMemoria: true))   // Base vacía → Bienvenida.
}
