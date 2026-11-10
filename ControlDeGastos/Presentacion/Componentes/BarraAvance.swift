//
//  BarraAvance.swift
//  ControlDeGastos
//
//  CAPA: Presentación — COMPONENTE reutilizable: barra horizontal de avance.
//  Se usa en Presupuestos (Sprint 2) y se reutilizará en el panel de Inicio (Sprint 3).
//

import SwiftUI

/// Barra horizontal que muestra el avance del gasto frente a su límite.
struct BarraAvance: View {
    /// Avance entre 0 y 1 (por ejemplo, 0,82 = 82 %).
    let fraccion: Double
    /// Color del tramo avanzado.
    let color: Color
    /// Alto de la barra en puntos.
    var alto: CGFloat = 8

    var body: some View {
        GeometryReader { geometria in
            ZStack(alignment: .leading) {
                Capsule().fill(Color(.systemGray5))
                Capsule()
                    .fill(color)
                    .frame(width: fraccion > 0 ? max(geometria.size.width * fraccion, alto) : 0)
            }
        }
        .frame(height: alto)
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
