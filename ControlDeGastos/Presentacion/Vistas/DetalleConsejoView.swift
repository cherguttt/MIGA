//
//  DetalleConsejoView.swift
//  ControlDeGastos
//
//  CAPA: Presentación — detalle de un consejo (Sprint 5, CU-07, RF-21 y RF-23). Mockup P7.
//
//  Muestra el texto completo, el ejemplo práctico y la pregunta «¿Te fue útil este consejo?».
//  La valoración se guarda en el EnvioConsejo; por eso solo aparece si el consejo ya fue
//  recibido (un consejo de la biblioteca que nunca se ha enviado no tiene envío que valorar).
//

import SwiftUI
import SwiftData

struct DetalleConsejoView: View {
    @Environment(\.modelContext) private var contexto
    @State private var modelo = EducacionViewModel()

    let consejo: Consejo
    /// Envío desde el que se abrió el consejo (o el más reciente). `nil` si nunca se envió.
    let envio: EnvioConsejo?

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                cabecera
                VStack(alignment: .leading, spacing: 14) {
                    Text(EducacionViewModel.descripcionEnvio(envio))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    ForEach(consejo.parrafosPrincipales, id: \.self) { parrafo in
                        Text(parrafo)
                            .font(.body)
                            .lineSpacing(3)
                    }
                    if !consejo.filasEjemplo.isEmpty { tarjetaEjemplo }
                    if let fuente = consejo.fuente {
                        Text(fuente)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if let envio { valoracion(envio) }
                }
                .padding(16)
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Consejo")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Cabecera con degradado

    private var cabecera: some View {
        VStack(spacing: 10) {
            Image(systemName: consejo.iconoVisible)
                .font(.system(size: 30))
                .frame(width: 58, height: 58)
                .background(.white.opacity(0.18), in: RoundedRectangle(cornerRadius: 16))
            Text(consejo.categoria.nombre)
                .font(.footnote.weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 3)
                .background(.white.opacity(0.2), in: Capsule())
            Text(consejo.titulo)
                .font(.title2.weight(.heavy))
                .multilineTextAlignment(.center)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 20)
        .padding(.vertical, 22)
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(colors: [consejo.categoria.colorOscuro, consejo.categoria.color],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        )
    }

    // MARK: - Ejemplo práctico

    private var tarjetaEjemplo: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Ejemplo práctico")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(consejo.categoria.colorOscuro)
            ForEach(consejo.filasEjemplo) { fila in
                HStack(alignment: .firstTextBaseline) {
                    Text(fila.texto)
                    Spacer()
                    if let valor = fila.valor {
                        Text(valor)
                            .fontWeight(fila.destacado ? .bold : .regular)
                            .foregroundStyle(fila.destacado ? consejo.categoria.color : .secondary)
                            .multilineTextAlignment(.trailing)
                    }
                }
                .font(.subheadline)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background, in: RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - ¿Te fue útil? (RF-23)

    private func valoracion(_ envio: EnvioConsejo) -> some View {
        VStack(spacing: 10) {
            Text("¿Te fue útil este consejo?")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            HStack(spacing: 12) {
                botonValoracion("Sí", icono: "hand.thumbsup", color: .green, elegido: envio.util == true) {
                    modelo.valorar(envio, util: true, contexto: contexto)
                }
                botonValoracion("No", icono: "hand.thumbsdown", color: .red, elegido: envio.util == false) {
                    modelo.valorar(envio, util: false, contexto: contexto)
                }
            }
            if envio.util != nil {
                Text("¡Gracias! Tu respuesta nos ayuda a mejorar los consejos.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 6)
    }

    /// Botón «Sí» o «No». Al elegirlo se rellena con su color.
    private func botonValoracion(_ texto: String, icono: String, color: Color, elegido: Bool,
                                 accion: @escaping () -> Void) -> some View {
        Button(action: accion) {
            Label(texto, systemImage: elegido ? icono + ".fill" : icono)
                .font(.headline)
                .foregroundStyle(elegido ? .white : color)
                .padding(.horizontal, 22)
                .padding(.vertical, 10)
                .background(elegido ? color : color.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(color, lineWidth: 2))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(elegido ? .isSelected : [])
    }
}
