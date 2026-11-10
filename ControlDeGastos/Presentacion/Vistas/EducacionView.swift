//
//  EducacionView.swift
//  ControlDeGastos
//
//  CAPA: Presentación — pestaña «Educación» (Sprint 5, CU-07, RF-21). Mockup P6 del portafolio.
//
//  Tres secciones:
//  1. «Consejo de esta semana»: tarjeta verde con el último consejo semanal recibido.
//  2. «Explorar por tema»: grilla con las seis temáticas y su cantidad de consejos.
//  3. «Recibidos recientemente»: historial de consejos enviados.
//

import SwiftUI
import SwiftData

struct EducacionView: View {
    // Consultas automáticas: se actualizan solas cuando cambia la base de datos.
    @Query(sort: \Consejo.orden) private var consejos: [Consejo]
    @Query(sort: \EnvioConsejo.fechaEnvio, order: .reverse) private var envios: [EnvioConsejo]

    @State private var modelo = EducacionViewModel()

    /// Navegación pedida al tocar una notificación (ver ServicioNotificaciones.swift).
    private let navegacion = NavegacionConsejos.compartida

    /// Grilla de 3 columnas, como la de categorías de «Registrar».
    private let columnas = Array(repeating: GridItem(.flexible(), spacing: 8), count: 3)

    // Valores calculados por el ViewModel.
    private var recibidos: [EnvioConsejo] { EducacionViewModel.recibidos(envios) }
    private var consejoSemana: EnvioConsejo? { EducacionViewModel.consejoDeLaSemana(recibidos) }

    var body: some View {
        // `NavigationStack(path:)`: la pila de pantallas la controla el ViewModel,
        // así se puede abrir un consejo por código (desde una notificación).
        NavigationStack(path: $modelo.ruta) {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if let envio = consejoSemana, let consejo = envio.consejo {
                        NavigationLink(value: DestinoEducacion.envio(envio)) {
                            TarjetaConsejoSemana(consejo: consejo)
                        }
                        .buttonStyle(.plain)
                    }
                    encabezado("Explorar por tema")
                    LazyVGrid(columns: columnas, spacing: 8) {
                        ForEach(EducacionViewModel.temas(consejos)) { tema in
                            NavigationLink(value: DestinoEducacion.tema(tema.categoria)) {
                                TarjetaTema(tema: tema)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    if !recibidos.isEmpty {
                        encabezado("Recibidos recientemente")
                        listaRecibidos
                    }
                }
                .padding(16)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Educación")
            // Cada tipo de destino abre su pantalla.
            .navigationDestination(for: DestinoEducacion.self) { destino in
                switch destino {
                case .tema(let categoria):
                    ListaTemaView(
                        categoria: categoria,
                        consejos: EducacionViewModel.consejos(de: categoria, en: consejos)
                    )
                case .consejo(let consejo):
                    DetalleConsejoView(consejo: consejo, envio: EducacionViewModel.envioParaValorar(consejo))
                case .envio(let envio):
                    if let consejo = envio.consejo {
                        DetalleConsejoView(consejo: consejo, envio: envio)
                    }
                }
            }
        }
        // CU-07, paso 5: si el usuario tocó la notificación de un consejo, se abre su detalle.
        .onAppear { abrirPendiente() }
        .onChange(of: navegacion.envioPorAbrir) { _, _ in abrirPendiente() }
        .onChange(of: navegacion.consejoPorAbrir) { _, _ in abrirPendiente() }
    }

    /// Abre el envío (notificación) o el consejo (aviso emergente) pendiente, si lo hay.
    private func abrirPendiente() {
        if let id = navegacion.envioPorAbrir, modelo.abrirEnvio(id: id, en: envios) {
            navegacion.envioPorAbrir = nil
        }
        if let id = navegacion.consejoPorAbrir, modelo.abrirConsejo(id: id, en: consejos) {
            navegacion.consejoPorAbrir = nil
        }
    }

    /// Título de sección en mayúsculas pequeñas, como en las demás pestañas.
    private func encabezado(_ texto: String) -> some View {
        Text(texto.uppercased())
            .font(.footnote.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.leading, 4)
            .padding(.top, 8)
    }

    /// Tarjeta blanca con los últimos consejos recibidos.
    private var listaRecibidos: some View {
        VStack(spacing: 0) {
            // `prefix` toma como máximo los 10 primeros; `enumerated` entrega también la posición
            // para dibujar el separador entre filas (no antes de la primera).
            ForEach(Array(recibidos.prefix(EducacionViewModel.maximoRecientes).enumerated()), id: \.element.id) { indice, envio in
                if indice > 0 { Divider().padding(.leading, 50) }
                if let consejo = envio.consejo {
                    NavigationLink(value: DestinoEducacion.envio(envio)) {
                        FilaConsejo(
                            consejo: consejo,
                            detalle: "\(consejo.categoria.nombre) · \(Formato.haceDias(envio.fechaEnvio))"
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, 14)
        .background(.background, in: RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: - Componentes de la pestaña

/// Tarjeta verde «CONSEJO DE ESTA SEMANA» (mockup P6).
private struct TarjetaConsejoSemana: View {
    let consejo: Consejo

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("CONSEJO DE ESTA SEMANA", systemImage: "lightbulb.fill")
                .font(.caption.weight(.bold))
                .foregroundStyle(Color(hex: 0xBBF7D0))
            Text(consejo.titulo)
                .font(.title2.weight(.heavy))
                .multilineTextAlignment(.leading)
            Text(consejo.categoria.nombre)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 3)
                .background(.white.opacity(0.18), in: Capsule())
            Text(consejo.resumen)
                .font(.subheadline)
                .foregroundStyle(Color(hex: 0xECFDF5))
                .lineLimit(3)
                .multilineTextAlignment(.leading)
        }
        .foregroundStyle(.white)
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(colors: [Color(hex: 0x14532D), Color(hex: 0x0F766E)],
                           startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: 14)
        )
    }
}

/// Tarjeta de color de una temática (grilla «Explorar por tema»).
private struct TarjetaTema: View {
    let tema: TemaConsejos

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: tema.categoria.icono)
                .font(.title2)
            Text(tema.categoria.nombre)
                .font(.footnote.weight(.bold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(tema.textoCantidad)
                .font(.caption2)
                .opacity(0.75)
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .padding(.horizontal, 6)
        .background(tema.categoria.color, in: RoundedRectangle(cornerRadius: 14))
    }
}

/// Fila de un consejo: ícono circular, título, detalle y flecha.
struct FilaConsejo: View {
    let consejo: Consejo
    let detalle: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: consejo.iconoVisible)
                .font(.system(size: 17))
                .foregroundStyle(consejo.categoria.color)
                .frame(width: 38, height: 38)
                .background(consejo.categoria.color.opacity(0.15), in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(consejo.titulo)
                    .font(.subheadline.weight(.semibold))
                    .multilineTextAlignment(.leading)
                Text(detalle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 10)
        .contentShape(Rectangle())   // Toda la fila responde al toque, no solo el texto.
    }
}

/// Lista de los consejos de una temática (RF-21).
private struct ListaTemaView: View {
    let categoria: CategoriaConsejo
    let consejos: [Consejo]

    var body: some View {
        List(consejos) { consejo in
            NavigationLink(value: DestinoEducacion.consejo(consejo)) {
                FilaConsejo(consejo: consejo, detalle: consejo.primeraOracion)
            }
        }
        .navigationTitle(categoria.nombre)
    }
}

#Preview {
    EducacionView()
        .modelContainer(DatosDePrueba.contenedor)
}
