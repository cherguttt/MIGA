//
//  EditorPresupuestoView.swift
//  ControlDeGastos
//
//  CAPA: Presentación — hoja para definir o modificar el límite mensual de una categoría
//  (CU-03, pasos 3 y 4). Se abre desde la pestaña Presupuestos.
//

import SwiftUI

struct EditorPresupuestoView: View {
    /// `@Bindable` permite enlazar ($) las propiedades del ViewModel compartido.
    @Bindable var modelo: PresupuestosViewModel
    let categoria: CategoriaGasto
    /// Gasto acumulado de la categoría en el mes que se está viendo.
    let gastado: Decimal
    /// Si la categoría ya tiene un límite (para mostrar «Quitar límite»).
    let tieneLimite: Bool
    /// Ingreso mensual de referencia del perfil, para mostrar la proporción.
    let ingreso: Decimal?
    /// Acciones que entrega la pantalla de Presupuestos.
    let alGuardar: () -> Void
    let alQuitar: () -> Void

    @Environment(\.dismiss) private var cerrar
    @FocusState private var montoEnfocado: Bool

    var body: some View {
        NavigationStack {
            Form {
                // Encabezado con la categoría y el mes.
                Section {
                    HStack(spacing: 14) {
                        IconoCategoria(categoria: categoria, tamano: 48)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(categoria.nombre).font(.headline)
                            Text(modelo.periodo.nombre).font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                }

                // Campo del límite.
                Section {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("$").font(.title.bold())
                        TextField("0", text: $modelo.montoTexto)
                            .font(.title.bold())
                            .keyboardType(.numberPad)
                            .focused($montoEnfocado)
                            .onChange(of: modelo.montoTexto) { _, nuevo in modelo.normalizarMonto(nuevo) }
                    }
                    if let texto = textoIngreso {
                        Text(texto).font(.footnote).foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Límite mensual")
                } footer: {
                    if let error = modelo.mensajeError {
                        Text(error).foregroundStyle(.red)
                    } else if !modelo.montoTexto.isEmpty && !modelo.puedeGuardar {
                        Text(ErrorPresupuesto.montoInvalido.localizedDescription).foregroundStyle(.red)
                    }
                }

                // Cómo quedaría el avance con el límite escrito.
                Section("Gasto del mes") {
                    LabeledContent("Gastado hasta hoy", value: Formato.pesos(gastado))
                    if let monto = modelo.montoIngresado, monto > 0,
                       let porcentaje = MotorAnalitico.porcentaje(gastado, de: monto) {
                        LabeledContent("Avance con este límite", value: "\(porcentaje) %")
                        BarraAvance(
                            fraccion: min(1, (gastado / monto).comoDouble),
                            color: EstadoAvance.para(gastado: gastado, montoMaximo: monto).color
                        )
                    }
                }

                if tieneLimite {
                    Section {
                        Button("Quitar límite", role: .destructive) { alQuitar() }
                    } footer: {
                        Text("La categoría quedará sin presupuesto en \(modelo.periodo.nombreMes) y no recibirás alertas por ella.")
                    }
                }
            }
            .navigationTitle("Límite de \(categoria.nombre)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { cerrar() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") { alGuardar() }
                        .disabled(!modelo.puedeGuardar)
                }
            }
            // Al abrir la hoja, el teclado aparece directamente en el campo del monto.
            .onAppear { montoEnfocado = true }
        }
        // La hoja ocupa media pantalla y se puede expandir.
        .presentationDetents([.medium, .large])
    }

    /// Por ejemplo: «Equivale al 16 % de tu ingreso de referencia».
    private var textoIngreso: String? {
        guard let monto = modelo.montoIngresado, let ingreso,
              let porcentaje = MotorAnalitico.porcentaje(monto, de: ingreso) else { return nil }
        return "Equivale al \(porcentaje) % de tu ingreso de referencia."
    }
}

#Preview {
    EditorPresupuestoView(
        modelo: PresupuestosViewModel(),
        categoria: .alimentacion,
        gastado: 106_600,
        tieneLimite: true,
        ingreso: 800_000,
        alGuardar: {},
        alQuitar: {}
    )
}
