//
//  CapturaBoletaView.swift
//  ControlDeGastos
//
//  CAPA: Presentación — «Escanear boleta» (Sprint 4: CU-06, RF-17, RF-19 y RNF-03; mockup P4).
//
//  FLUJO (Figura 6 del portafolio):
//    1. Se abre la cámara de documentos de Apple (VisionKit), que encuadra y endereza la boleta.
//    2. La foto queda SOLO en memoria y se entrega a ServicioOCR.extraerTotal(imagen).
//    3. Se muestra el resultado: «Monto total detectado» con la fila «TOTAL» marcada en amarillo.
//    4. «Usar este monto» → precarga el monto en el formulario con origen «boleta».
//       «Ingresar manualmente» → vuelve al formulario para escribir el monto (flujo alternativo).
//  Al cerrar esta pantalla la imagen se libera de la memoria: no se guarda ni se transmite.
//

import SwiftUI
import VisionKit   // VNDocumentCameraViewController: la cámara de documentos de Apple.

struct CapturaBoletaView: View {
    /// Acción que cierra esta pantalla (la entrega SwiftUI).
    @Environment(\.dismiss) private var cerrar

    /// Qué hacer con el monto cuando el usuario elige «Usar este monto».
    let alUsarMonto: (Decimal) -> Void
    /// Qué hacer cuando el usuario elige «Ingresar manualmente».
    let alIngresarManual: () -> Void

    /// Etapas de la pantalla. Un `enum` con «valores asociados» guarda datos distintos en cada caso.
    private enum Etapa {
        case camara                              // Mostrando la cámara de documentos.
        case procesando(UIImage)                 // Leyendo el texto de la foto.
        case resultado(UIImage, ResultadoOCR)    // Mostrando lo que se encontró.
        case sinCamara                           // El dispositivo no puede escanear (simulador).
    }

    /// Etapa inicial: la cámara si el dispositivo la soporta; si no, el aviso «sin cámara».
    @State private var etapa: Etapa = VNDocumentCameraViewController.isSupported ? .camara : .sinCamara

    var body: some View {
        // `switch` dentro de una vista: se dibuja una pantalla distinta según la etapa.
        switch etapa {
        case .camara:
            EscanerDocumentos { imagen in
                if let imagen {
                    procesar(imagen)
                } else {
                    cerrar()   // El usuario tocó «Cancelar» en la cámara.
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

    /// Envía la imagen al ServicioOCR. `Task` permite usar `await` desde un botón o un callback.
    private func procesar(_ original: UIImage) {
        let imagen = enderezada(original)
        etapa = .procesando(imagen)
        Task {
            let resultado: ResultadoOCR
            if let cgImage = imagen.cgImage {
                // `try?`: si Vision falla, se trata igual que «no se encontró el total».
                resultado = (try? await ServicioOCR.extraerTotal(de: cgImage)) ?? .sinResultado
            } else {
                resultado = .sinResultado
            }
            etapa = .resultado(imagen, resultado)
        }
    }

    /// Una foto puede venir «girada» (la orientación se guarda aparte de los píxeles).
    /// Vision lee los píxeles tal cual, así que la redibujamos derecha antes de leerla.
    /// Todo ocurre en memoria.
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
    /// `resultado` es `nil` mientras Vision todavía está leyendo.
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
        .preferredColorScheme(.dark)   // Pantalla oscura, como la cámara.
    }

    /// Barra superior: «Cancelar», el título y un botón para volver a escanear.
    private var barraSuperior: some View {
        HStack {
            Button("Cancelar") { cerrar() }
            Spacer()
            Text("Escanear boleta").font(.headline)
            Spacer()
            Button {
                etapa = .camara   // Descarta la foto actual y abre otra vez la cámara.
            } label: {
                Image(systemName: "arrow.counterclockwise")
            }
            .accessibilityLabel("Volver a escanear")
            // Sin cámara (simulador) no tiene sentido «volver a escanear».
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
                // Caso exitoso (flujo principal).
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
                // Flujo alternativo del CU-06: no se encontró la línea «TOTAL».
                Label("No se detectó el total", systemImage: "exclamationmark.triangle.fill")
                    .font(.headline)
                    .foregroundStyle(.orange)
                Text("No encontramos la línea «TOTAL» en la boleta. Puedes escanearla de nuevo o ingresar el monto manualmente.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                // Mientras Vision lee el texto.
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
            .disabled(resultado == nil)   // Se habilita cuando terminó la lectura.
        }
        .padding(18)
        .padding(.bottom, 8)
        .background(
            Color(.systemGroupedBackground),
            in: UnevenRoundedRectangle(topLeadingRadius: 22, topTrailingRadius: 22)
        )
        .environment(\.colorScheme, .light)   // La hoja es clara, como en el mockup.
        .ignoresSafeArea(edges: .bottom)
    }

    // MARK: - Sin cámara

    /// El simulador de Xcode no tiene cámara. Se avisa y, solo en el simulador, se ofrece leer
    /// la boleta de ejemplo para probar el OCR completo.
    private var pantallaSinCamara: some View {
        NavigationStack {
            ContentUnavailableView {
                Label("Cámara no disponible", systemImage: "camera.badge.ellipsis")
            } description: {
                Text("Este dispositivo no permite escanear documentos. Puedes ingresar el monto manualmente.")
            } actions: {
                // `#if targetEnvironment(simulator)`: este botón solo existe al compilar para el simulador.
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
            .scaledToFit()   // La imagen cabe completa, sin deformarse.
            // `overlay` dibuja encima de la imagen y mide exactamente lo mismo que ella.
            .overlay {
                if let caja {
                    // `GeometryReader` entrega el tamaño real con que se dibujó la imagen.
                    GeometryReader { geometria in
                        let ancho = geometria.size.width
                        let alto = geometria.size.height
                        // Conversión de coordenadas: Vision mide desde abajo y la pantalla desde
                        // arriba, por eso la «y» se calcula como (1 − maxY).
                        let marco = CGRect(
                            x: caja.minX * ancho,
                            y: (1 - caja.maxY) * alto,
                            width: caja.width * ancho,
                            height: caja.height * alto
                        ).insetBy(dx: -6, dy: -4)   // Un poco más grande que el texto.
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.yellow.opacity(0.2))                    // Relleno suave…
                            .overlay(RoundedRectangle(cornerRadius: 3)
                                .stroke(Color.yellow, lineWidth: 2.5))          // …y borde amarillo.
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

/// VisionKit está hecho con UIKit, la tecnología anterior a SwiftUI. `UIViewControllerRepresentable`
/// es el «adaptador» que permite usar una pantalla de UIKit dentro de SwiftUI.
private struct EscanerDocumentos: UIViewControllerRepresentable {
    /// Se llama con la imagen escaneada, o con `nil` si el usuario canceló.
    let alTerminar: (UIImage?) -> Void

    /// Crea la pantalla de UIKit (se llama una vez).
    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let camara = VNDocumentCameraViewController()
        camara.delegate = context.coordinator   // El «coordinador» recibe los eventos de la cámara.
        return camara
    }

    /// No hay nada que actualizar: la cámara no depende de datos de SwiftUI.
    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {}

    func makeCoordinator() -> Coordinador { Coordinador(alTerminar: alTerminar) }

    /// En UIKit los eventos llegan a un «delegado» (un objeto que cumple un protocolo).
    /// El coordinador hace ese papel y los traduce a nuestro closure `alTerminar`.
    final class Coordinador: NSObject, VNDocumentCameraViewControllerDelegate {
        let alTerminar: (UIImage?) -> Void
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
