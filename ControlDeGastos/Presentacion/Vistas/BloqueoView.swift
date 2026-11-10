//
//  BloqueoView.swift
//  ControlDeGastos
//
//  CAPA: Presentación — pantalla que protege los datos cuando el bloqueo con Face ID
//  está activo (RF-03). Aparece al abrir la app y al volver desde segundo plano.
//

import SwiftUI

/// Pantalla que oculta los datos hasta autenticar al usuario.
struct BloqueoView: View {
    /// Closure que entrega la vista padre (ContentView).
    let alDesbloquear: () -> Void

    /// Se vuelve `true` si la autenticación falla, para mostrar un mensaje en rojo.
    @State private var intentoFallido = false

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "lock.fill")
                .font(.system(size: 56))
                .foregroundStyle(.tint)
            Text("MIGA está bloqueada")
                .font(.title2.bold())
            Text("Desbloquea la aplicación para ver tus datos financieros.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            if intentoFallido {
                Text("No se pudo verificar tu identidad. Inténtalo nuevamente.")
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }
            Spacer()
            Button {
                Task { await desbloquear() }
            } label: {
                Label("Desbloquear con \(ServicioAutenticacion.nombreMetodo)", systemImage: "faceid")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding(24)
        .task { await desbloquear() }
    }

    /// Pide la autenticación y, según el resultado, desbloquea o muestra el error.
    private func desbloquear() async {
        let exito = await ServicioAutenticacion.autenticar(motivo: "Desbloquea MIGA para ver tus datos.")
        if exito {
            alDesbloquear()
        } else {
            intentoFallido = true
        }
    }
}

#Preview {
    BloqueoView(alDesbloquear: {})
}
