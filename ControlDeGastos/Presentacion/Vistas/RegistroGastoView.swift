//
//  RegistroGastoView.swift
//  ControlDeGastos
//
//  CAPA: Presentación — pestaña «Registrar» (CU-02): formulario de registro manual de gastos.
//  Sprint 4: tarjeta «Escanear boleta» (CU-06, mockup P3) que abre CapturaBoletaView.
//
//  Esta vista solo DIBUJA. El estado del formulario y la acción de guardar viven en
//  RegistroGastoViewModel (patrón MVVM).
//

import SwiftUI
import SwiftData

struct RegistroGastoView: View {
    @Environment(\.modelContext) private var contexto

    /// El ViewModel. Con `@State` la vista lo crea una sola vez y lo conserva mientras exista;
    /// como el ViewModel es `@Observable`, la vista se redibuja cuando cambian sus propiedades.
    @State private var modelo = RegistroGastoViewModel()

    /// `@FocusState` controla qué campo tiene el teclado abierto.
    /// Si lo ponemos en false, el teclado se cierra.
    @FocusState private var montoEnfocado: Bool

    /// Sprint 4: `true` mientras se muestra la pantalla «Escanear boleta».
    @State private var mostrarEscaner = false
    /// Sprint 4: si es `true`, al cerrar el escáner se abre el teclado del monto (ingreso manual).
    @State private var enfocarMontoAlCerrar = false

    /// Definición de la grilla de categorías: 3 columnas flexibles con 8 puntos de separación.
    /// `Array(repeating:count:)` crea un arreglo repitiendo el mismo elemento 3 veces.
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
            .scrollDismissesKeyboard(.interactively)   // Deslizar hacia abajo cierra el teclado.
            .toolbar {
                // El teclado numérico no tiene botón «Listo», así que agregamos uno encima del teclado.
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Listo") { montoEnfocado = false }
                }
            }
            // Sprint 4: el escáner ocupa toda la pantalla. `onDismiss` se ejecuta al cerrarse.
            .fullScreenCover(isPresented: $mostrarEscaner, onDismiss: {
                if enfocarMontoAlCerrar {
                    enfocarMontoAlCerrar = false
                    montoEnfocado = true   // Flujo alternativo: abre el teclado para escribir el monto.
                }
            }) {
                CapturaBoletaView(
                    alUsarMonto: { monto in modelo.precargar(monto: monto) },   // RF-19.
                    alIngresarManual: { enfocarMontoAlCerrar = true }
                )
            }
            // Alerta de confirmación: aparece cuando el ViewModel llena `mensajeConfirmacion`.
            // (Mismo truco de Binding personalizado explicado en InicioView.swift).
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
            // Borde azul suave, como en el mockup.
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
            // `.firstTextBaseline` alinea el «$» y el número por la línea base del texto.
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("$")
                    .font(.system(size: 40, weight: .bold))
                // `$modelo.montoTexto`: binding hacia una propiedad del ViewModel.
                TextField("0", text: $modelo.montoTexto)
                    .font(.system(size: 40, weight: .bold))
                    .keyboardType(.numberPad)
                    .focused($montoEnfocado)    // Conecta este campo con @FocusState.
                    // Cada vez que cambia el texto, el ViewModel le pone los puntos de miles.
                    .onChange(of: modelo.montoTexto) { _, nuevo in
                        modelo.normalizarMonto(nuevo)
                    }
            }
            // Sprint 4 (CU-06, paso 6): recuerda que el monto vino de la boleta y se puede corregir.
            if modelo.origen == .boleta {
                Label("Monto leído desde la boleta · puedes corregirlo", systemImage: "text.viewfinder")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            // Error visible solo si el monto es 0 (el monto vacío se informa abajo, junto al botón).
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

    /// Grilla con las categorías. Las seis principales van en una grilla de 3 × 2; debajo,
    /// «Pago Créditos» y «Otros» comparten una fila, para que la grilla no quede con un botón suelto.
    /// Categorías que van en la fila inferior, fuera de la grilla de 3 × 2.
    private static let filaInferior: [CategoriaGasto] = [.pagoCreditos, .otros]

    private var seccionCategorias: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("CATEGORÍA")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.leading, 4)
            // `LazyVGrid` = grilla vertical; «Lazy» porque crea las celdas a medida que se necesitan.
            LazyVGrid(columns: columnas, spacing: 8) {
                // `allCases` existe gracias a `CaseIterable` (ver Enumeraciones.swift).
                // `filter` deja fuera a las categorías de la fila inferior, que se dibujan aparte.
                ForEach(CategoriaGasto.allCases.filter { !Self.filaInferior.contains($0) }) { categoria in
                    botonCategoria(categoria)
                }
            }
            // Fila inferior: dos botones horizontales del mismo ancho.
            HStack(spacing: 8) {
                ForEach(Self.filaInferior) { categoria in
                    botonCategoria(categoria, horizontal: true)
                }
            }
        }
    }

    /// Botón de UNA categoría. Se pinta con el color de acento si está seleccionada.
    /// Con `horizontal: true` el ícono va a la izquierda del nombre (fila inferior).
    private func botonCategoria(_ categoria: CategoriaGasto, horizontal: Bool = false) -> some View {
        let seleccionada = modelo.categoria == categoria
        // Como la función tiene más de una instrucción, aquí `return` es obligatorio.
        return Button {
            modelo.categoria = categoria
        } label: {
            // `AnyLayout` permite elegir entre apilar en vertical u horizontal con el mismo contenido.
            let disposicion = horizontal ? AnyLayout(HStackLayout(spacing: 8)) : AnyLayout(VStackLayout(spacing: 6))
            disposicion {
                Image(systemName: categoria.icono)
                    .font(.title3)
                    .foregroundStyle(seleccionada ? .white : categoria.color)
                Text(categoria.nombre)
                    .font(.caption)
                    .foregroundStyle(seleccionada ? .white : .primary)
                    .lineLimit(1)               // Una sola línea…
                    .minimumScaleFactor(0.8)    // …y si no cabe, el texto se achica hasta un 80 %.
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                // `AnyShapeStyle` «envuelve» dos estilos de tipos distintos (un Color y el
                // fondo del sistema) para que el operador ternario devuelva un único tipo.
                seleccionada ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(.background),
                in: RoundedRectangle(cornerRadius: 12)
            )
        }
        .buttonStyle(.plain)   // Sin el estilo azul por defecto: usamos nuestro propio diseño.
        // Accesibilidad: VoiceOver dirá «seleccionado» en la categoría elegida.
        .accessibilityAddTraits(seleccionada ? .isSelected : [])
    }

    // MARK: - Fecha y descripción

    /// Tarjeta con el selector de fecha/hora y la descripción opcional.
    private var tarjetaDetalle: some View {
        VStack(spacing: 0) {
            DatePicker(
                "Fecha y hora",
                selection: $modelo.fecha,
                // `...Date.now` es un RANGO abierto: «cualquier fecha hasta ahora».
                // Así el selector ni siquiera permite elegir fechas futuras.
                in: ...Date.now,
                displayedComponents: [.date, .hourAndMinute]
            )
            // Fuerza el formato chileno (día-mes-año, meses en español) solo en este selector.
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
                montoEnfocado = false   // Cerramos el teclado.
                // Creamos el servicio con el contexto de la base de datos y se lo pasamos
                // al ViewModel, que valida y guarda (CU-02, pasos 5 y 6).
                modelo.confirmar(con: ServicioTransacciones(contexto: contexto))
            } label: {
                Text("Confirmar gasto")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(!modelo.puedeConfirmar)

            // Explica qué falta para poder confirmar (RF-06).
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
    /// Encadena tres operaciones sobre la lista de errores:
    /// 1. `filter`: quita el error de monto en cero (ya se muestra en la tarjeta del monto);
    /// 2. `map(\.mensaje)`: convierte cada error en su texto;
    /// 3. `joined`: une los textos en uno solo, separados por un espacio.
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
