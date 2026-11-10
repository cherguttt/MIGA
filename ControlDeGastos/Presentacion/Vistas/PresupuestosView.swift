//
//  PresupuestosView.swift
//  ControlDeGastos
//
//  CAPA: Presentación — pestaña «Presupuestos» (CU-03, RF-08). Mockup P5 del portafolio.
//

import SwiftUI
import SwiftData

/// Pestaña Presupuestos: límites por categoría del mes.
struct PresupuestosView: View {
    @Environment(\.modelContext) private var contexto

    @Query private var presupuestos: [Presupuesto]
    @Query private var transacciones: [Transaccion]
    @Query private var perfiles: [PerfilUsuario]

    @State private var modelo = PresupuestosViewModel()

    /// Filas calculadas por el ViewModel para el mes seleccionado.
    private var filas: [FilaPresupuesto] {
        modelo.filas(presupuestos: presupuestos, transacciones: transacciones)
    }

    private var servicio: ServicioPresupuestos { ServicioPresupuestos(contexto: contexto) }

    var body: some View {
        NavigationStack {
            List {
                Section { selectorMes }
                Section { resumen }

                Section {
                    ForEach(filas) { fila in
                        Button { modelo.editar(fila) } label: { FilaPresupuestoView(fila: fila) }
                            .buttonStyle(.plain)
                    }
                } header: {
                    Text("Límite mensual por categoría")
                } footer: {
                    Text("Recibirás una alerta cuando el gasto acumulado de una categoría alcance el 70 %, 80 % y 90 % de su límite.")
                }

                if modelo.puedeCopiarMesAnterior(presupuestos: presupuestos) {
                    Section {
                        Button {
                            modelo.copiarMesAnterior(con: servicio)
                        } label: {
                            Label(textoCopiar, systemImage: "doc.on.doc")
                        }
                    }
                }
            }
            .navigationTitle("Presupuestos")
            .sheet(item: $modelo.categoriaEditando) { categoria in
                let fila = filas.first { $0.categoria == categoria }
                EditorPresupuestoView(
                    modelo: modelo,
                    categoria: categoria,
                    gastado: fila?.gastado ?? 0,
                    tieneLimite: fila?.montoMaximo != nil,
                    ingreso: perfiles.first?.ingresoMensualReferencia,
                    alGuardar: { modelo.guardar(con: servicio) },
                    alQuitar: { modelo.quitarLimite(con: servicio) }
                )
            }
        }
    }

    /// «Copiar los límites de octubre» o, con otro día de inicio, «…del ciclo anterior».
    private var textoCopiar: String {
        let anterior = modelo.periodo.anterior
        return anterior.esMesCalendario ? "Copiar los límites de \(anterior.nombreMes)" : "Copiar los límites del ciclo anterior"
    }

    // MARK: - Selector de mes (CU-03, paso 1)

    private var selectorMes: some View {
        HStack {
            Button {
                modelo.mesAnterior()
            } label: {
                Label(modelo.periodo.anterior.nombreCorto, systemImage: "chevron.left")
            }
            Spacer()
            Text(modelo.periodo.nombre)
                .font(.headline)
                .onTapGesture { modelo.irAlMesActual() }
            Spacer()
            Button {
                modelo.mesSiguiente()
            } label: {
                HStack(spacing: 4) {
                    Text(modelo.periodo.siguiente.nombreCorto)
                    Image(systemName: "chevron.right")
                }
            }
        }
        .font(.subheadline)
        .buttonStyle(.borderless)
    }

    // MARK: - Resumen (CU-03, paso 5)

    private var resumen: some View {
        let total = modelo.totalPresupuestado(filas)
        let ingreso = perfiles.first?.ingresoMensualReferencia ?? 0
        let porcentaje = MotorAnalitico.porcentaje(total, de: ingreso)
        return HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Total presupuestado")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(Formato.pesos(total))
                    .font(.title.bold())
                    .monospacedDigit()
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text("Ingreso de referencia")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(Formato.pesos(ingreso))
                    .font(.headline)
                    .monospacedDigit()
                if let porcentaje {
                    Text(porcentaje <= 100 ? "\(porcentaje) % del ingreso" : "Supera tu ingreso (\(porcentaje) %)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(porcentaje <= 100 ? .green : .red)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Fila de una categoría

/// Vista de UNA fila: ícono, nombre, límite, barra de avance y detalle.
private struct FilaPresupuestoView: View {
    let fila: FilaPresupuesto

    var body: some View {
        HStack(spacing: 12) {
            IconoCategoria(categoria: fila.categoria)
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(fila.categoria.nombre)
                    Spacer()
                    if let monto = fila.montoMaximo {
                        Text(Formato.pesos(monto))
                            .fontWeight(.semibold)
                            .monospacedDigit()
                    } else {
                        Text("Sin límite").foregroundStyle(.secondary)
                    }
                }
                if fila.montoMaximo != nil {
                    BarraAvance(fraccion: fila.fraccion, color: fila.estado.color)
                }
                Text(detalle)
                    .font(.caption)
                    .foregroundStyle(fila.estado == .critico ? Color.red : Color.secondary)
            }
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }

    /// Texto bajo la barra, por ejemplo «$106.600 gastados · 82 %».
    private var detalle: String {
        if let porcentaje = fila.porcentaje {
            return "\(Formato.pesos(fila.gastado)) gastados · \(porcentaje) %"
        }
        return fila.gastado > 0
            ? "\(Formato.pesos(fila.gastado)) gastados · toca para definir un límite"
            : "Toca para definir un límite"
    }
}

#Preview {
    PresupuestosView()
        .modelContainer(DatosDePrueba.contenedor)
}
