//
//  InicioView.swift
//  ControlDeGastos
//
//  CAPA: Presentación — pestaña «Inicio»: panel estadístico del mes (Sprint 3, CU-05, RF-16).
//  Diseño del mockup P2 del portafolio:
//    1. Tarjeta con el gasto del mes frente al presupuesto total.
//    2. Proyección al cierre del mes con su estado y el gráfico de gasto diario (Swift Charts).
//    3. Avance de cada categoría.
//    4. Lista de los gastos del mes (Sprint 1), con la opción de eliminarlos.
//

import SwiftUI
import SwiftData
import Charts   // Swift Charts: framework de Apple para gráficos (iOS 16+).

struct InicioView: View {

    /// Closure para saltar a la pestaña «Registrar» (lo entrega PrincipalView).
    let irARegistrar: () -> Void

    @Environment(\.modelContext) private var contexto

    // Consultas automáticas a la base de datos: si cambian, la vista se vuelve a dibujar.
    @Query(sort: \Transaccion.fecha, order: .reverse) private var transacciones: [Transaccion]
    @Query private var presupuestos: [Presupuesto]
    @Query private var perfiles: [PerfilUsuario]

    @State private var modelo = InicioViewModel()
    @State private var mensajeError: String?

    /// Gastos del mes en curso, para la lista inferior.
    private var gastosDelMes: [Transaccion] {
        let periodo = PeriodoMensual()
        return transacciones.filter { periodo.contiene($0.fecha) }
    }

    var body: some View {
        NavigationStack {
            List {
                if let resumen = modelo.resumen, !modelo.sinGastos {
                    Section {
                        TarjetaGastoMes(resumen: resumen)
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(Color.clear)
                    }
                    Section {
                        TarjetaProyeccion(resumen: resumen)
                    }
                    if !resumen.categorias.isEmpty {
                        Section("Por categoría") {
                            ForEach(resumen.categorias) { avance in
                                FilaAvanceCategoria(avance: avance)
                            }
                        }
                    }
                    Section("Gastos de \(Formato.mesAnio(.now))") {
                        ForEach(gastosDelMes) { transaccion in
                            FilaGasto(transaccion: transaccion)
                        }
                        .onDelete(perform: eliminar)   // Deslizar para eliminar.
                    }
                } else {
                    // Flujo alternativo del CU-05: aún no hay gastos en el mes.
                    Section {
                        ContentUnavailableView {
                            Label("Sin gastos este mes", systemImage: "chart.bar.xaxis")
                        } description: {
                            Text("Registra tu primer gasto para ver tu proyección y el avance de tus presupuestos.")
                        } actions: {
                            Button("Registrar gasto", action: irARegistrar)
                                .buttonStyle(.borderedProminent)
                        }
                    }
                }
            }
            .navigationTitle(saludo)
            // CU-05, paso 2: la vista pide el resumen al abrir la pestaña…
            .onAppear { cargar() }
            // …y cada vez que cambian los gastos o los presupuestos.
            .onChange(of: transacciones) { cargar() }
            .onChange(of: presupuestos) { cargar() }
            .alert("No se pudo eliminar el gasto", isPresented: Binding(
                get: { mensajeError != nil },
                set: { if !$0 { mensajeError = nil } }
            )) {
                Button("Aceptar", role: .cancel) {}
            } message: {
                Text(mensajeError ?? "")
            }
        }
    }

    private func cargar() {
        modelo.cargarResumen(transacciones: transacciones, presupuestos: presupuestos)
    }

    /// Título: «Hola, Camila» o «Inicio» si no hay nombre.
    private var saludo: String {
        if let nombre = perfiles.first?.nombre, !nombre.isEmpty { return "Hola, \(nombre)" }
        return "Inicio"
    }

    /// Elimina los gastos deslizados (ver explicación en el Sprint 1).
    private func eliminar(en posiciones: IndexSet) {
        let servicio = ServicioTransacciones(contexto: contexto)
        let seleccionados = posiciones.map { gastosDelMes[$0] }
        for transaccion in seleccionados {
            do { try servicio.eliminar(transaccion) } catch { mensajeError = error.localizedDescription }
        }
    }
}

// MARK: - 1. Tarjeta del gasto del mes

/// Tarjeta azul oscura: «Gasto de octubre de 2026 · día 18 de 31», total, presupuesto y barra.
private struct TarjetaGastoMes: View {
    let resumen: ResumenMensual

    private var tituloPeriodo: String {
        resumen.periodo.esMesCalendario
            ? "Gasto de \(Formato.mesAnio(resumen.periodo.inicio()))"
            : "Ciclo \(resumen.periodo.nombre)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Con el ciclo calendario: «Gasto de octubre de 2026 · día 18 de 31»;
            // con otro día de inicio: «Ciclo 25 oct. – 24 nov. 2026 · día 12 de 31».
            Text("\(tituloPeriodo) · día \(resumen.diasTranscurridos) de \(resumen.diasDelMes)")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.8))
            Text(Formato.pesos(resumen.gastoTotal))
                .font(.system(size: 36, weight: .bold))
                .foregroundStyle(.white)
                .monospacedDigit()
            if resumen.presupuestoTotal > 0 {
                Text("de \(Formato.pesos(resumen.presupuestoTotal)) presupuestados")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.8))
                BarraAvance(
                    fraccion: min(1, (resumen.gastoTotal / resumen.presupuestoTotal).comoDouble),
                    color: Color(red: 0.38, green: 0.65, blue: 1.0)
                )
                .padding(.top, 4)
                if let porcentaje = resumen.porcentajeUtilizado {
                    Text("\(porcentaje) % utilizado")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.8))
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            } else {
                Text("Define tus límites en la pestaña Presupuestos para ver tu avance.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.8))
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(colors: [Color(red: 0.11, green: 0.23, blue: 0.43), Color(red: 0.06, green: 0.14, blue: 0.28)],
                           startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: 16)
        )
    }
}

// MARK: - 2. Tarjeta de proyección y gráfico

/// Proyección al cierre (P), su estado y el gráfico de gasto diario.
private struct TarjetaProyeccion: View {
    let resumen: ResumenMensual

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Proyección al cierre del mes")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(Formato.pesos(resumen.proyeccion))
                        .font(.system(size: 30, weight: .bold))
                        .foregroundStyle(resumen.estado == .sinPresupuesto ? Color.primary : resumen.estado.color)
                        .monospacedDigit()
                }
                Spacer()
                if resumen.estado != .sinPresupuesto {
                    Label(resumen.estado.titulo, systemImage: resumen.estado.icono)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(resumen.estado.color)
                        .multilineTextAlignment(.trailing)
                }
            }

            // GRÁFICO DE BARRAS con Swift Charts: una barra por día; el día de hoy en un tono más fuerte.
            Chart(resumen.gastoPorDia) { dia in
                BarMark(
                    x: .value("Día", dia.dia),
                    y: .value("Gasto", dia.monto.comoDouble)
                )
                .foregroundStyle(dia.dia == resumen.diasTranscurridos ? Color.blue : Color.blue.opacity(0.45))
                .cornerRadius(3)
            }
            .chartXScale(domain: 0...(resumen.diasDelMes + 1))   // Eje X: todo el mes, aunque falten días.
            .chartXAxis {
                AxisMarks(values: [1, 10, 20, resumen.diasDelMes]) { _ in
                    AxisValueLabel()   // Solo algunas etiquetas para no saturar el eje.
                }
            }
            .chartYAxis(.hidden)
            .frame(height: 110)
            .accessibilityLabel("Gráfico de gasto diario del mes")

            Text("Gasto diario · velocidad promedio \(Formato.pesos(resumen.velocidadDiaria)) / día")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 6)
    }
}

// MARK: - 3. Fila de avance por categoría

private struct FilaAvanceCategoria: View {
    let avance: AvanceCategoria

    private var estado: EstadoAvance { EstadoAvance.para(gastado: avance.gastado, montoMaximo: avance.montoMaximo) }

    var body: some View {
        HStack(spacing: 12) {
            IconoCategoria(categoria: avance.categoria, tamano: 40)
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(avance.categoria.nombre).font(.headline)
                    Spacer()
                    if let porcentaje = avance.porcentaje {
                        Text("\(porcentaje) %")
                            .font(.headline)
                            .foregroundStyle(estado.color)
                            .monospacedDigit()
                    }
                }
                if let limite = avance.montoMaximo {
                    Text("\(Formato.pesos(avance.gastado)) de \(Formato.pesos(limite))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    BarraAvance(fraccion: min(1, (avance.gastado / limite).comoDouble), color: estado.color)
                } else {
                    Text("\(Formato.pesos(avance.gastado)) · sin límite definido")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    InicioView(irARegistrar: {})
        .modelContainer(DatosDePrueba.contenedor)
}
