//
//  BarraAvance.swift
//  ControlDeGastos
//
//  CAPA: Presentación — COMPONENTE reutilizable: barra horizontal de avance.
//  Se usa en Presupuestos (Sprint 2) y se reutilizará en el panel de Inicio (Sprint 3).
//

import SwiftUI

struct BarraAvance: View {
    /// Avance entre 0 y 1 (por ejemplo, 0,82 = 82 %).
    let fraccion: Double
    /// Color del tramo avanzado.
    let color: Color
    /// Alto de la barra en puntos.
    var alto: CGFloat = 8

    var body: some View {
        // `GeometryReader` entrega el ancho disponible, para calcular cuánto pintar.
        GeometryReader { geometria in
            // `ZStack` superpone: abajo el fondo gris y encima el tramo de color.
            ZStack(alignment: .leading) {
                Capsule().fill(Color(.systemGray5))
                Capsule()
                    .fill(color)
                    // `max(…, alto)`: aunque el avance sea muy pequeño, se ve un punto de color.
                    .frame(width: fraccion > 0 ? max(geometria.size.width * fraccion, alto) : 0)
            }
        }
        .frame(height: alto)
        // Accesibilidad: VoiceOver lee «82 por ciento».
        .accessibilityElement()
        .accessibilityValue(Text("\(Int(fraccion * 100)) %"))
    }
}

#Preview {
    VStack(spacing: 16) {
        BarraAvance(fraccion: 0.45, color: .green)
        BarraAvance(fraccion: 0.82, color: .orange)
        BarraAvance(fraccion: 0.95, color: .red)
    }
    .padding()
}
