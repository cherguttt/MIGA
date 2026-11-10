//
//  ServicioOCR.swift
//  ControlDeGastos
//
//  CAPA: Lógica de negocio — Servicio OCR (Sprint 4: CU-06, RF-18 y RNF-03).
//

import Foundation
import CoreGraphics
import Vision

/// Un bloque de texto reconocido por Vision, o una fila ya armada, con su posición en la imagen.
nonisolated struct FilaTexto: Sendable, Equatable {
    let texto: String
    /// Rectángulo NORMALIZADO (valores de 0 a 1, relativos al tamaño de la imagen).
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
    static func extraerTotal(de imagen: CGImage) async throws -> ResultadoOCR {
        let bloques = try await Task.detached(priority: .userInitiated) {
            try reconocerBloques(en: imagen)
        }.value
        return extraerTotal(de: agruparEnFilas(bloques))
    }

    /// Ejecuta Vision sobre la imagen y devuelve los bloques de texto que encontró.
    nonisolated static func reconocerBloques(en imagen: CGImage) throws -> [FilaTexto] {
        let solicitud = VNRecognizeTextRequest()
        solicitud.recognitionLevel = .accurate
        solicitud.recognitionLanguages = ["es-ES", "en-US"]
        solicitud.usesLanguageCorrection = false

        try VNImageRequestHandler(cgImage: imagen, options: [:]).perform([solicitud])

        return (solicitud.results ?? []).compactMap { observacion in
            guard let candidato = observacion.topCandidates(1).first else { return nil }
            return FilaTexto(texto: candidato.string, caja: observacion.boundingBox)
        }
    }

    // MARK: - 2. Ordenar el texto en filas

    /// Vision suele entregar por separado el texto de la izquierda («TOTAL») y el de la derecha («$12.500»),
    /// aunque estén en la misma fila de la boleta.
    static func agruparEnFilas(_ bloques: [FilaTexto]) -> [FilaTexto] {
        let conCaja = bloques.compactMap { bloque in bloque.caja.map { (bloque.texto, $0) } }
        let ordenados = conCaja.sorted { $0.1.midY > $1.1.midY }

        var filas: [[(String, CGRect)]] = []
        for bloque in ordenados {
            if let referencia = filas.last?.first,
               abs(referencia.1.midY - bloque.1.midY) < max(referencia.1.height, bloque.1.height) * 0.5 {
                filas[filas.count - 1].append(bloque)
            } else {
                filas.append([bloque])
            }
        }

        return filas.map { fila in
            let ordenada = fila.sorted { $0.1.minX < $1.1.minX }
            return FilaTexto(
                texto: ordenada.map(\.0).joined(separator: " "),
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
    static func extraerTotal(de filas: [FilaTexto]) -> ResultadoOCR {
        var resultado = ResultadoOCR.sinResultado
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
    static func ultimoMonto(en fila: String) -> Decimal? {
        guard let patron = try? Regex("\\d[\\d.,]*"),
              let ultimo = fila.matches(of: patron).last else { return nil }
        var texto = String(fila[ultimo.range])

        while let final = texto.last, final == "." || final == "," { texto.removeLast() }
        if texto.count > 3, texto.range(of: "[.,]\\d{2}$", options: .regularExpression) != nil {
            texto.removeLast(3)
        }
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
