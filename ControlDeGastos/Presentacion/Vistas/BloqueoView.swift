//
//  BloqueoView.swift
//  ControlDeGastos
//
//  CAPA: Presentación — pantalla que protege los datos cuando el bloqueo con Face ID
//  está activo (RF-03). Aparece al abrir la app y al volver desde segundo plano.
//

import SwiftUI

struct BloqueoView: View {

    /// Closure que entrega la vista padre (ContentView). Su tipo `() -> Void` significa:
    /// «función que no recibe parámetros y no devuelve nada». La llamamos al desbloquear.
    let alDesbloquear: () -> Void

    /// Se vuelve `true` si la autenticación falla, para mostrar un mensaje en rojo.
    @State private var intentoFallido = false

    var body: some View {
        // `VStack` apila vistas en VERTICAL (HStack = horizontal, ZStack = superpuestas).
        // `spacing: 20` = 20 puntos de separación entre cada elemento.
        VStack(spacing: 20) {
            Spacer()   // Espacio flexible: empuja el contenido hacia el centro.
            Image(systemName: "lock.fill")       // Ícono de SF Symbols.
                .font(.system(size: 56))         // Los SF Symbols se escalan como texto.
                .foregroundStyle(.tint)          // Color de acento de la app.
            Text("MIGA está bloqueada")
                .font(.title2.bold())
            Text("Desbloquea la aplicación para ver tus datos financieros.")
                .font(.subheadline)
                .foregroundStyle(.secondary)     // Gris secundario del sistema.
                .multilineTextAlignment(.center)
            // Este texto solo existe en pantalla cuando `intentoFallido` es true.
            if intentoFallido {
                Text("No se pudo verificar tu identidad. Inténtalo nuevamente.")
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }
            Spacer()
            Button {
                // Un botón ejecuta código normal (síncrono). Para llamar a una función `async`
                // creamos una `Task` (tarea), que puede usar `await` dentro.
                Task { await desbloquear() }
            } label: {
                // `label` define cómo se VE el botón.
                Label("Desbloquear con \(ServicioAutenticacion.nombreMetodo)", systemImage: "faceid")
                    .frame(maxWidth: .infinity)  // Ocupa todo el ancho disponible.
            }
            .buttonStyle(.borderedProminent)     // Botón relleno con el color de acento.
            .controlSize(.large)
        }
        .padding(24)   // Margen interior en los cuatro lados.
        // `.task` ejecuta código asíncrono cuando la vista APARECE en pantalla:
        // así Face ID se solicita automáticamente, sin que el usuario toque el botón.
        .task { await desbloquear() }
    }

    /// Pide la autenticación y, según el resultado, desbloquea o muestra el error.
    private func desbloquear() async {
        let exito = await ServicioAutenticacion.autenticar(motivo: "Desbloquea MIGA para ver tus datos.")
        if exito {
            alDesbloquear()        // Avisamos a ContentView, que mostrará la pantalla principal.
        } else {
            intentoFallido = true
        }
    }
}

#Preview {
    BloqueoView(alDesbloquear: {})   // `{}` = closure vacío: en la vista previa no hace nada.
}
