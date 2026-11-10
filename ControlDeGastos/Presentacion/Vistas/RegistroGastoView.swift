//
//  RegistroGastoView.swift
//  ControlDeGastos
//
//  CAPA: Presentación — pestaña «Registrar» (CU-02): formulario de registro manual de gastos.
//  Sprint 4: tarjeta «Escanear boleta» (CU-06, mockup P3) que abre CapturaBoletaView.
//

import SwiftUI
import SwiftData

/// Pestaña Registrar: formulario de registro de gastos (CU-02).
struct RegistroGastoView: View {
    @Environment(\.modelContext) private var contexto

    /// El ViewModel.
    @State private var modelo = RegistroGastoViewModel()

    /// `@FocusState` controla qué campo tiene el teclado abierto.
    @FocusState private var montoEnfocado: Bool

    /// Sprint 4: `true` mientras se muestra la pantalla «Escanear boleta».
    @State private var mostrarEscaner = false
    /// Sprint 4: si es `true`, al cerrar el escáner se abre el teclado del monto (ingreso manual).
    @State private var enfocarMontoAlCerrar = false

    /// Definición de la grilla de categorías: 3 columnas flexibles con 8 puntos de separación.
    private let columnas = Array(repeating: GridItem(.flexible(), spacing: 8), count: 3)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    tarjetaEscanear
                    tarjetaMonto
                    seccionCategorias
                    tarjetaDetalle
                    botonConfirmar
                }
                .padding(16)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Registrar gasto")
            .scrollDismissesKeyboard(.interactively)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Listo") { montoEnfocado = false }
                }
            }
            .fullScreenCover(isPresented: $mostrarEscaner, onDismiss: {
                if enfocarMontoAlCerrar {
                    enfocarMontoAlCerrar = false
                    montoEnfocado = true
                }
            }) {
                CapturaBoletaView(
                    alUsarMonto: { monto in modelo.precargar(monto: monto) },
                    alIngresarManual: { enfocarMontoAlCerrar = true }
                )
            }
            .alert("Gasto registrado", isPresented: Binding(
                get: { modelo.mensajeConfirmacion != nil },
                set: { if !$0 { modelo.mensajeConfirmacion = nil } }
            )) {
                Button("Aceptar", role: .cancel) {}
            } message: {
                Text(modelo.mensajeConfirmacion ?? "")
            }
        }
    }

    // MARK: - Escanear boleta (Sprint 4)

    /// Tarjeta superior del mockup P3: «Escanear boleta · Extrae el total automáticamente».
    private var tarjetaEscanear: some View {
        Button {
            montoEnfocado = false
            mostrarEscaner = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "text.viewfinder")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 38, height: 38)
                    .background(Color.accentColor.opacity(0.15), in: Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text("Escanear boleta")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.accentColor)
                    Text("Extrae el total automáticamente")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(.background, in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.accentColor.opacity(0.2), lineWidth: 1.5))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Monto

    /// Tarjeta con el campo grande del monto.
    private var tarjetaMonto: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Monto del gasto")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("$")
                    .font(.system(size: 40, weight: .bold))
                TextField("0", text: $modelo.montoTexto)
                    .font(.system(size: 40, weight: .bold))
                    .keyboardType(.numberPad)
                    .focused($montoEnfocado)
                    .onChange(of: modelo.montoTexto) { _, nuevo in
                        modelo.normalizarMonto(nuevo)
                    }
            }
            if modelo.origen == .boleta {
                Label("Monto leído desde la boleta · puedes corregirlo", systemImage: "text.viewfinder")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            if modelo.errores.contains(.montoNoPositivo) {
                Text(ErrorValidacion.montoNoPositivo.mensaje)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background, in: RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Categorías

    /// Grilla con las categorías.
    private static let filaInferior: [CategoriaGasto] = [.pagoCreditos, .otros]

    private var seccionCategorias: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("CATEGORÍA")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.leading, 4)
            LazyVGrid(columns: columnas, spacing: 8) {
                ForEach(CategoriaGasto.allCases.filter { !Self.filaInferior.contains($0) }) { categoria in
                    botonCategoria(categoria)
                }
            }
            HStack(spacing: 8) {
                ForEach(Self.filaInferior) { categoria in
                    botonCategoria(categoria, horizontal: true)
                }
            }
        }
    }

    /// Botón de UNA categoría.
    private func botonCategoria(_ categoria: CategoriaGasto, horizontal: Bool = false) -> some View {
        let seleccionada = modelo.categoria == categoria
        return Button {
            modelo.categoria = categoria
        } label: {
            let disposicion = horizontal ? AnyLayout(HStackLayout(spacing: 8)) : AnyLayout(VStackLayout(spacing: 6))
            disposicion {
                Image(systemName: categoria.icono)
                    .font(.title3)
                    .foregroundStyle(seleccionada ? .white : categoria.color)
                Text(categoria.nombre)
                    .font(.caption)
                    .foregroundStyle(seleccionada ? .white : .primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                seleccionada ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(.background),
                in: RoundedRectangle(cornerRadius: 12)
            )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(seleccionada ? .isSelected : [])
    }

    // MARK: - Fecha y descripción

    /// Tarjeta con el selector de fecha/hora y la descripción opcional.
    private var tarjetaDetalle: some View {
        VStack(spacing: 0) {
            DatePicker(
                "Fecha y hora",
                selection: $modelo.fecha,
                in: ...Date.now,
                displayedComponents: [.date, .hourAndMinute]
            )
            .environment(\.locale, Locale(identifier: "es_CL"))
            .padding(.vertical, 10)
            Divider()
            VStack(alignment: .leading, spacing: 4) {
                Text("Descripción (opcional)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("Ej.: almuerzo del trabajo", text: $modelo.descripcion)
            }
            .padding(.vertical, 10)
        }
        .padding(.horizontal, 16)
        .background(.background, in: RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Confirmación

    /// Botón «Confirmar gasto» y mensajes de ayuda o error.
    private var botonConfirmar: some View {
        VStack(spacing: 8) {
            Button {
                montoEnfocado = false
                modelo.confirmar(con: ServicioTransacciones(contexto: contexto))
            } label: {
                Text("Confirmar gasto")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(!modelo.puedeConfirmar)

            if !modelo.puedeConfirmar {
                Text(mensajePendiente)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            if let error = modelo.mensajeError {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
        }
    }

    /// Mensaje que explica qué falta para habilitar el botón.
    private var mensajePendiente: String {
        modelo.errores
            .filter { $0 != .montoNoPositivo }
            .map(\.mensaje)
            .joined(separator: " ")
    }
}

#Preview {
    RegistroGastoView()
        .modelContainer(DatosDePrueba.contenedor)
}
