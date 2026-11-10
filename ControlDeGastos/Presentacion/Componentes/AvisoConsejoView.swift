//
//  AvisoConsejoView.swift
//  ControlDeGastos
//
//  CAPA: Presentación — COMPONENTE: ventana emergente con un consejo al abrir la app
//  (complemento del Sprint 5, CU-07).
//
//  Tiene el mismo diseño de la notificación del mockup P9 (ícono de color, nombre de la app,
//  etiqueta, título y primera oración), pero se dibuja DENTRO de la app: por eso funciona
//  aunque el usuario no haya autorizado las notificaciones de iOS.
//
//  - Tocar el aviso abre el detalle del consejo.
//  - La «X» o deslizarlo hacia arriba lo cierra. Si no se toca, se cierra solo (PrincipalView).
//

import SwiftUI

struct AvisoConsejoView: View {
    let consejo: Consejo
    /// Acción al tocar el aviso (abrir el consejo).
    let alAbrir: () -> Void
    /// Acción al cerrar el aviso.
    let alCerrar: () -> Void

    /// Cuánto se ha arrastrado el aviso (para cerrarlo deslizando hacia arriba).
    @State private var arrastre: CGFloat = 0

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            // Ícono cuadrado con el color de la temática.
            Image(systemName: consejo.iconoVisible)
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 38, height: 38)
                .background(consejo.categoria.color, in: RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text("MIGA").font(.subheadline.weight(.semibold))
                    Spacer()
                    Text("ahora").font(.footnote).foregroundStyle(.secondary)
                }
                Text("CONSEJO · \(consejo.categoria.nombre.uppercased())")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(consejo.categoria.color)
                Text(consejo.titulo)
                    .font(.subheadline.weight(.bold))
                Text(consejo.primeraOracion)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                Text("Toca para leer el consejo completo")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.top, 2)
            }

            Button(action: alCerrar) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Cerrar consejo")
        }
        .padding(14)
        // `.regularMaterial`: fondo translúcido con desenfoque, como las notificaciones de iOS.
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22))
        .shadow(color: .black.opacity(0.18), radius: 16, y: 6)
        .padding(.horizontal, 12)
        // Solo se mueve hacia arriba (`min(0, …)`), nunca hacia abajo.
        .offset(y: min(0, arrastre))
        .contentShape(RoundedRectangle(cornerRadius: 22))
        .onTapGesture(perform: alAbrir)
        // Deslizar hacia arriba más de 40 puntos lo cierra; si no, vuelve a su lugar.
        .gesture(
            DragGesture()
                .onChanged { arrastre = $0.translation.height }
                .onEnded { valor in
                    if valor.translation.height < -40 { alCerrar() } else { arrastre = 0 }
                }
        )
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("Abre el consejo completo")
    }
}
