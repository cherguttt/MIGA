//
//  CapturaBoletaView.swift
//  ControlDeGastos
//
//  CAPA: Presentación — «Escanear boleta» (Sprint 4: CU-06, RF-17, RF-19 y RNF-03; mockup P4).
//

import SwiftUI
import VisionKit

/// Captura de la boleta con la cámara y lectura del total (CU-06).
struct CapturaBoletaView: View {
    /// Acción que cierra esta pantalla (la entrega SwiftUI).
    @Environment(\.dismiss) private var cerrar

    /// Qué hacer con el monto cuando el usuario elige «Usar este monto».
    let alUsarMonto: (Decimal) -> Void
    /// Qué hacer cuando el usuario elige «Ingresar manualmente».
    let alIngresarManual: () -> Void

    /// Etapas de la pantalla.
    private enum Etapa {
        case camara
        case procesando(UIImage)
        case resultado(UIImage, ResultadoOCR)
        case sinCamara
    }

    /// Etapa inicial: la cámara si el dispositivo la soporta; si no, el aviso «sin cámara».
    @State private var etapa: Etapa = VNDocumentCameraViewController.isSupported ? .camara : .sinCamara

    var body: some View {
        switch etapa {
        case .camara:
            EscanerDocumentos { imagen in
                if let imagen {
                    procesar(imagen)
                } else {
                    cerrar()
                }
            }
            .ignoresSafeArea()
        case .procesando(let imagen):
            pantallaResultado(imagen: imagen, resultado: nil)
        case .resultado(let imagen, let resultado):
            pantallaResultado(imagen: imagen, resultado: resultado)
        case .sinCamara:
            pantallaSinCamara
        }
    }

    // MARK: - Lógica

    /// Envía la imagen al ServicioOCR.
    private func procesar(_ original: UIImage) {
        let imagen = enderezada(original)
        etapa = .procesando(imagen)
        Task {
            let resultado: ResultadoOCR
            if let cgImage = imagen.cgImage {
                resultado = (try? await ServicioOCR.extraerTotal(de: cgImage)) ?? .sinResultado
            } else {
                resultado = .sinResultado
            }
            etapa = .resultado(imagen, resultado)
        }
    }

    /// Una foto puede venir «girada» (la orientación se guarda aparte de los píxeles).
    private func enderezada(_ imagen: UIImage) -> UIImage {
        guard imagen.imageOrientation != .up else { return imagen }
        let formato = UIGraphicsImageRendererFormat()
        formato.scale = imagen.scale
        return UIGraphicsImageRenderer(size: imagen.size, format: formato).image { _ in
            imagen.draw(in: CGRect(origin: .zero, size: imagen.size))
        }
    }

    /// RF-19: el monto pasa al formulario y se cierra la pantalla (la imagen se descarta).
    private func usar(_ monto: Decimal) {
        alUsarMonto(monto)
        cerrar()
    }

    /// Flujo alternativo: se vuelve al formulario para escribir el monto a mano.
    private func ingresarManualmente() {
        alIngresarManual()
        cerrar()
    }

    // MARK: - Pantalla de resultado (mockup P4)

    /// Fondo oscuro con la boleta, la leyenda de privacidad y la hoja inferior con el resultado.
    private func pantallaResultado(imagen: UIImage, resultado: ResultadoOCR?) -> some View {
        VStack(spacing: 0) {
            barraSuperior
            ImagenBoleta(imagen: imagen, caja: resultado?.caja)
                .padding(.horizontal, 22)
                .padding(.top, 14)
                .frame(maxHeight: .infinity)
            Text("Texto reconocido en el dispositivo · la imagen no se guarda")
                .font(.footnote)
                .foregroundStyle(Color(white: 0.68))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            hojaResultado(resultado)
        }
        .background(Color(white: 0.11).ignoresSafeArea())
        .preferredColorScheme(.dark)
    }

    /// Barra superior: «Cancelar», el título y un botón para volver a escanear.
    private var barraSuperior: some View {
        HStack {
            Button("Cancelar") { cerrar() }
            Spacer()
            Text("Escanear boleta").font(.headline)
            Spacer()
            Button {
                etapa = .camara
            } label: {
                Image(systemName: "arrow.counterclockwise")
            }
            .accessibilityLabel("Volver a escanear")
            .opacity(VNDocumentCameraViewController.isSupported ? 1 : 0)
            .disabled(!VNDocumentCameraViewController.isSupported)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 8)
    }

    /// Hoja clara inferior con el monto detectado y los dos botones del mockup P4.
    private func hojaResultado(_ resultado: ResultadoOCR?) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if let resultado, let monto = resultado.monto {
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Monto total detectado")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        Text(Formato.pesos(monto))
                            .font(.system(size: 34, weight: .heavy))
                            .monospacedDigit()
                    }
                    Spacer()
                    Label("Línea «TOTAL»", systemImage: "checkmark")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.green)
                }
                Button { usar(monto) } label: {
                    Text("Usar este monto").font(.headline).frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            } else if resultado != nil {
                Label("No se detectó el total", systemImage: "exclamationmark.triangle.fill")
                    .font(.headline)
                    .foregroundStyle(.orange)
                Text("No encontramos la línea «TOTAL» en la boleta. Puedes escanearla de nuevo o ingresar el monto manualmente.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                HStack(spacing: 10) {
                    ProgressView()
                    Text("Leyendo la boleta…").foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 60)
            }

            Button { ingresarManualmente() } label: {
                Text("Ingresar manualmente").font(.headline).frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .disabled(resultado == nil)
        }
        .padding(18)
        .padding(.bottom, 8)
        .background(
            Color(.systemGroupedBackground),
            in: UnevenRoundedRectangle(topLeadingRadius: 22, topTrailingRadius: 22)
        )
        .environment(\.colorScheme, .light)
        .ignoresSafeArea(edges: .bottom)
    }

    // MARK: - Sin cámara

    /// El simulador de Xcode no tiene cámara.
    private var pantallaSinCamara: some View {
        NavigationStack {
            ContentUnavailableView {
                Label("Cámara no disponible", systemImage: "camera.badge.ellipsis")
            } description: {
                Text("Este dispositivo no permite escanear documentos. Puedes ingresar el monto manualmente.")
            } actions: {
                #if targetEnvironment(simulator)
                Button("Probar con boleta de ejemplo") { procesar(BoletaDeEjemplo.imagen()) }
                    .buttonStyle(.borderedProminent)
                #endif
                Button("Ingresar manualmente") { ingresarManualmente() }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { cerrar() }
                }
            }
        }
    }
}

// MARK: - Imagen con la fila «TOTAL» marcada

/// Muestra la foto de la boleta y dibuja un recuadro amarillo sobre la fila del total.
private struct ImagenBoleta: View {
    let imagen: UIImage
    /// Rectángulo normalizado de Vision (origen abajo a la izquierda), o `nil` si no hay marca.
    let caja: CGRect?

    var body: some View {
        Image(uiImage: imagen)
            .resizable()
            .scaledToFit()
            .overlay {
                if let caja {
                    GeometryReader { geometria in
                        let ancho = geometria.size.width
                        let alto = geometria.size.height
                        let marco = CGRect(
                            x: caja.minX * ancho,
                            y: (1 - caja.maxY) * alto,
                            width: caja.width * ancho,
                            height: caja.height * alto
                        ).insetBy(dx: -6, dy: -4)
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.yellow.opacity(0.2))
                            .overlay(RoundedRectangle(cornerRadius: 3)
                                .stroke(Color.yellow, lineWidth: 2.5))
                            .frame(width: marco.width, height: marco.height)
                            .position(x: marco.midX, y: marco.midY)
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .shadow(color: .black.opacity(0.5), radius: 15, y: 10)
            .accessibilityLabel("Boleta escaneada")
    }
}

// MARK: - Puente con VisionKit (UIKit)

/// VisionKit está hecho con UIKit, la tecnología anterior a SwiftUI.
private struct EscanerDocumentos: UIViewControllerRepresentable {
    /// Se llama con la imagen escaneada, o con `nil` si el usuario canceló.
    let alTerminar: (UIImage?) -> Void

    /// Crea la pantalla de UIKit (se llama una vez).
    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let camara = VNDocumentCameraViewController()
        camara.delegate = context.coordinator
        return camara
    }

    /// No hay nada que actualizar: la cámara no depende de datos de SwiftUI.
    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {}

    /// Crea el coordinador que recibe los eventos de la cámara.
    func makeCoordinator() -> Coordinador { Coordinador(alTerminar: alTerminar) }

    /// En UIKit los eventos llegan a un «delegado» (un objeto que cumple un protocolo).
    final class Coordinador: NSObject, VNDocumentCameraViewControllerDelegate {
        let alTerminar: (UIImage?) -> Void
        /// Guarda la acción que se ejecuta al terminar el escaneo.
        init(alTerminar: @escaping (UIImage?) -> Void) { self.alTerminar = alTerminar }

        /// El usuario escaneó una o más páginas: usamos solo la primera (una boleta).
        func documentCameraViewController(_ controller: VNDocumentCameraViewController,
                                          didFinishWith scan: VNDocumentCameraScan) {
            alTerminar(scan.pageCount > 0 ? scan.imageOfPage(at: 0) : nil)
        }

        /// El usuario tocó «Cancelar».
        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            alTerminar(nil)
        }

        /// Ocurrió un error con la cámara (por ejemplo, permiso denegado): se trata como cancelar.
        func documentCameraViewController(_ controller: VNDocumentCameraViewController,
                                          didFailWithError error: Error) {
            alTerminar(nil)
        }
    }
}

#Preview("Sin cámara (simulador)") {
    CapturaBoletaView(alUsarMonto: { _ in }, alIngresarManual: {})
}
