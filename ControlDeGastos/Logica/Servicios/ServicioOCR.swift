//
//  ServicioOCR.swift
//  ControlDeGastos
//
//  CAPA: Lógica de negocio — Servicio OCR (Sprint 4: CU-06, RF-18 y RNF-03).
//
//  ¿QUÉ ES OCR?
//  «Optical Character Recognition» (reconocimiento óptico de caracteres): convertir el texto
//  de una imagen en texto que el programa puede leer. Usamos el framework Vision de Apple,
//  que lo hace DENTRO del iPhone, sin internet ni servidores (Privacy by Design, Ley N° 21.719).
//
//  Corresponde a los pasos 3 y 4 del CU-06 y a «extraerTotal(imagen)» de la Figura 6:
//    1. Vision reconoce los bloques de texto de la imagen (VNRecognizeTextRequest).
//    2. Los bloques se ordenan en filas, como se leen en la boleta.
//    3. Se busca la fila «TOTAL» y se extrae su monto.
//  La imagen solo existe en memoria mientras se procesa: este servicio nunca la guarda (RNF-03).
//
//  Los pasos 2 y 3 son funciones «puras» (reciben datos y devuelven datos, sin cámara ni
//  pantalla), por eso se pueden probar con XCTest (casos CP-12 y CP-13).
//

import Foundation
import CoreGraphics   // CGImage y CGRect: imagen y rectángulos.
import Vision         // Framework de Apple para analizar imágenes (texto, rostros, códigos…).

/// Un bloque de texto reconocido por Vision, o una fila ya armada, con su posición en la imagen.
/// `nonisolated`: puede crearse en cualquier hilo (Vision trabaja fuera del hilo principal).
/// `Sendable`: se puede pasar con seguridad de un hilo a otro.
nonisolated struct FilaTexto: Sendable, Equatable {
    let texto: String
    /// Rectángulo NORMALIZADO (valores de 0 a 1, relativos al tamaño de la imagen).
    /// En Vision el origen (0, 0) está ABAJO a la izquierda, al revés que en la pantalla.
    /// Es opcional porque en las pruebas trabajamos solo con texto.
    var caja: CGRect? = nil
}

/// Resultado de leer una boleta.
struct ResultadoOCR: Equatable {
    /// Monto total detectado, o `nil` si no se encontró (flujo alternativo del CU-06).
    let monto: Decimal?
    /// Texto de la fila donde se encontró el total, por ejemplo «TOTAL $12.500».
    let linea: String?
    /// Posición de esa fila en la imagen: la pantalla la marca en amarillo (mockup P4).
    let caja: CGRect?

    /// `true` si se encontró un total.
    var detectado: Bool { monto != nil }

    /// Resultado vacío: «no se encontró el total».
    static let sinResultado = ResultadoOCR(monto: nil, linea: nil, caja: nil)
}

/// `enum` sin casos: solo agrupa funciones estáticas (no hace falta crear un objeto).
enum ServicioOCR {

    // MARK: - 1. Reconocimiento de texto con Vision

    /// CU-06, pasos 3 y 4: reconoce el texto de la boleta y devuelve el total encontrado.
    /// `async`: el reconocimiento tarda un momento y no debe congelar la pantalla mientras ocurre.
    static func extraerTotal(de imagen: CGImage) async throws -> ResultadoOCR {
        // `Task.detached` ejecuta el trabajo pesado FUERA del hilo principal (el de la interfaz);
        // `await` espera el resultado sin bloquear la pantalla.
        let bloques = try await Task.detached(priority: .userInitiated) {
            try reconocerBloques(en: imagen)
        }.value
        return extraerTotal(de: agruparEnFilas(bloques))
    }

    /// Ejecuta Vision sobre la imagen y devuelve los bloques de texto que encontró.
    /// `nonisolated`: puede correr en cualquier hilo, no solo en el principal.
    nonisolated static func reconocerBloques(en imagen: CGImage) throws -> [FilaTexto] {
        let solicitud = VNRecognizeTextRequest()
        solicitud.recognitionLevel = .accurate               // Más lento, pero más preciso.
        solicitud.recognitionLanguages = ["es-ES", "en-US"]  // Idiomas que Vision debe esperar.
        solicitud.usesLanguageCorrection = false             // No «corregir» números como si fueran palabras.

        // El «manejador» aplica la solicitud a UNA imagen. La imagen solo se lee en memoria:
        // no se escribe en disco ni se envía a ningún lado (RNF-03).
        try VNImageRequestHandler(cgImage: imagen, options: [:]).perform([solicitud])

        // Cada «observación» es un bloque de texto. `topCandidates(1)` entrega la lectura más
        // probable; `compactMap` descarta los bloques que no tengan ninguna lectura.
        return (solicitud.results ?? []).compactMap { observacion in
            guard let candidato = observacion.topCandidates(1).first else { return nil }
            return FilaTexto(texto: candidato.string, caja: observacion.boundingBox)
        }
    }

    // MARK: - 2. Ordenar el texto en filas

    /// Vision suele entregar por separado el texto de la izquierda («TOTAL») y el de la derecha
    /// («$12.500»), aunque estén en la misma fila de la boleta. Esta función los vuelve a juntar:
    /// agrupa los bloques que están a la misma altura y los ordena de izquierda a derecha.
    static func agruparEnFilas(_ bloques: [FilaTexto]) -> [FilaTexto] {
        // Solo se pueden ubicar los bloques que tienen posición.
        let conCaja = bloques.compactMap { bloque in bloque.caja.map { (bloque.texto, $0) } }
        // De arriba hacia abajo: en Vision, un `midY` (centro vertical) mayor está más arriba.
        let ordenados = conCaja.sorted { $0.1.midY > $1.1.midY }

        var filas: [[(String, CGRect)]] = []
        for bloque in ordenados {
            // Mismo criterio de fila: la distancia entre centros es menor que media altura de letra.
            if let referencia = filas.last?.first,
               abs(referencia.1.midY - bloque.1.midY) < max(referencia.1.height, bloque.1.height) * 0.5 {
                filas[filas.count - 1].append(bloque)   // Se suma a la fila actual.
            } else {
                filas.append([bloque])                  // Empieza una fila nueva.
            }
        }

        return filas.map { fila in
            let ordenada = fila.sorted { $0.1.minX < $1.1.minX }   // De izquierda a derecha.
            return FilaTexto(
                texto: ordenada.map(\.0).joined(separator: " "),
                // `reduce` une todos los rectángulos de la fila en uno solo que los contiene.
                caja: ordenada.dropFirst().reduce(ordenada[0].1) { $0.union($1.1) }
            )
        }
    }

    // MARK: - 3. Buscar el total

    /// Frases que contienen «TOTAL» pero NO son el total a pagar.
    private static let exclusiones = [
        "SUBTOTAL", "SUB TOTAL", "SUB-TOTAL", "TOTAL NETO", "TOTAL IVA", "IVA TOTAL",
        "TOTAL ITEM", "TOTAL ARTICULO", "TOTAL PRODUCTO", "TOTAL UNIDADES", "TOTAL DESCUENTO"
    ]

    /// Versión para pruebas: recibe solo los textos de las filas, sin posiciones.
    static func extraerTotal(de textos: [String]) -> ResultadoOCR {
        extraerTotal(de: textos.map { FilaTexto(texto: $0) })
    }

    /// CU-06, paso 4: busca la fila que contiene la palabra «TOTAL» y extrae su monto.
    /// - No importan mayúsculas ni tildes («Total», «TOTÁL»).
    /// - Se descartan «SUBTOTAL», «TOTAL IVA», «TOTAL ÍTEMS», etc.
    /// - Si la fila del total no trae número (el monto quedó en la fila de abajo), se mira la siguiente.
    /// - Si hay varias filas válidas, se usa la ÚLTIMA: el total final va después de los parciales.
    static func extraerTotal(de filas: [FilaTexto]) -> ResultadoOCR {
        var resultado = ResultadoOCR.sinResultado
        // `enumerated()` entrega cada fila junto con su posición (índice) en la lista.
        for (indice, fila) in filas.enumerated() {
            let normal = normalizar(fila.texto)
            guard normal.contains("TOTAL"),
                  !exclusiones.contains(where: { normal.contains($0) }) else { continue }

            if let monto = ultimoMonto(en: fila.texto) {
                resultado = ResultadoOCR(monto: monto, linea: fila.texto, caja: fila.caja)
            } else if indice + 1 < filas.count, let monto = ultimoMonto(en: filas[indice + 1].texto) {
                let siguiente = filas[indice + 1]
                resultado = ResultadoOCR(
                    monto: monto,
                    linea: "\(fila.texto) \(siguiente.texto)",
                    caja: unir(fila.caja, siguiente.caja)
                )
            }
        }
        return resultado
    }

    /// Pasa el texto a mayúsculas y le quita las tildes, para comparar sin importar cómo lo leyó la cámara.
    static func normalizar(_ texto: String) -> String {
        texto.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "es_CL"))
            .uppercased()
    }

    /// Convierte el ÚLTIMO número de una fila en un monto: «TOTAL $12.500» → 12500.
    /// En Chile el punto separa los miles. Si el número termina en dos decimales («12.500,00»)
    /// estos se descartan, porque el peso chileno no usa centavos.
    static func ultimoMonto(en fila: String) -> Decimal? {
        // Expresión regular: un dígito seguido de cualquier cantidad de dígitos, puntos o comas.
        guard let patron = try? Regex("\\d[\\d.,]*"),
              let ultimo = fila.matches(of: patron).last else { return nil }
        var texto = String(fila[ultimo.range])

        // Quita un punto o coma suelto al final («12.500.» → «12.500»).
        while let final = texto.last, final == "." || final == "," { texto.removeLast() }
        // Quita los decimales: «12.500,00» → «12.500».
        if texto.count > 3, texto.range(of: "[.,]\\d{2}$", options: .regularExpression) != nil {
            texto.removeLast(3)
        }
        // Deja solo los dígitos y exige que el monto sea mayor que cero.
        guard let monto = Decimal(string: texto.filter(\.isNumber)), monto > 0 else { return nil }
        return monto
    }

    /// Une dos rectángulos opcionales (si alguno falta, devuelve el otro).
    private static func unir(_ a: CGRect?, _ b: CGRect?) -> CGRect? {
        switch (a, b) {
        case let (a?, b?): a.union(b)
        default: a ?? b
        }
    }
}
