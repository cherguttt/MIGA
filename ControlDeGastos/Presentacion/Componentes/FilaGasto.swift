//
//  FilaGasto.swift
//  ControlDeGastos
//
//  CAPA: Presentación — COMPONENTES reutilizables.
//  Un componente es una vista pequeña que se usa en varias pantallas. Así, si cambiamos
//  el diseño de la fila aquí, cambia en toda la app.
//

import SwiftUI

/// Fila que muestra un gasto en una lista: ícono, descripción, categoría y fecha, y monto.
struct FilaGasto: View {

    /// El gasto a mostrar. Es `let` porque la fila solo lo muestra, no lo modifica.
    let transaccion: Transaccion

    var body: some View {
        HStack(spacing: 12) {
            IconoCategoria(categoria: transaccion.categoria)
            VStack(alignment: .leading, spacing: 2) {
                // Si no hay descripción (`nil`), `??` muestra el nombre de la categoría.
                Text(transaccion.descripcion ?? transaccion.categoria.nombre)
                    .font(.body)
                    .lineLimit(1)
                Text("\(transaccion.categoria.nombre) · \(Formato.fechaHora(transaccion.fecha))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()   // Empuja el monto hacia el borde derecho.
            Text(Formato.pesos(transaccion.monto))
                .font(.body.weight(.semibold))
                .monospacedDigit()
        }
        .padding(.vertical, 2)
    }
}

/// Ícono circular con el color de la categoría.
struct IconoCategoria: View {
    let categoria: CategoriaGasto

    /// Tamaño del círculo. Al ser `var` con valor por defecto, es OPCIONAL al crear la vista:
    /// `IconoCategoria(categoria: .salud)` o `IconoCategoria(categoria: .salud, tamano: 48)`.
    /// `CGFloat` es el tipo numérico que usa Apple para medidas en pantalla.
    var tamano: CGFloat = 36

    var body: some View {
        Image(systemName: categoria.icono)
            .font(.system(size: tamano * 0.45))   // El ícono ocupa el 45 % del círculo.
            .foregroundStyle(categoria.color)
            .frame(width: tamano, height: tamano)
            .background(categoria.color.opacity(0.15), in: Circle())
    }
}

#Preview {
    List {
        FilaGasto(transaccion: Transaccion(monto: 12_500, categoria: .alimentacion, fecha: .now, descripcion: "Almuerzo"))
        FilaGasto(transaccion: Transaccion(monto: 1_500, categoria: .transporte, fecha: .now))
    }
}
