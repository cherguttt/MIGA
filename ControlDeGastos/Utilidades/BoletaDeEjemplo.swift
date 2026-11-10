//
//  BoletaDeEjemplo.swift
//  ControlDeGastos
//
//  CAPA: Utilidades — boleta de ejemplo dibujada por código (Sprint 4).
//

import UIKit

/// Imagen de una boleta de ejemplo para probar el OCR en el simulador.
enum BoletaDeEjemplo {
    /// Filas de la boleta: texto a la izquierda y monto a la derecha (vacío si no hay).
    static let filas: [(String, String)] = [
        ("MINIMARKET LOS AROMOS", ""),
        ("BOLETA ELECTRÓNICA N° 004512", ""),
        ("PAN AMASADO 1 KG", "2.890"),
        ("LECHE ENTERA 1 L", "1.190"),
        ("QUESO LAMINADO", "4.350"),
        ("CAFÉ GRANO 250 G", "4.070"),
        ("TOTAL", "$12.500"),
        ("GRACIAS POR SU COMPRA", "")
    ]

    /// Dibuja la boleta en memoria con `UIGraphicsImageRenderer` (un «lienzo» que entrega una imagen).
    static func imagen() -> UIImage {
        let ancho: CGFloat = 720
        let altoFila: CGFloat = 64
        let tamano = CGSize(width: ancho, height: 80 + CGFloat(filas.count) * altoFila)
        let atributos: [NSAttributedString.Key: Any] = [
            .font: UIFont.monospacedSystemFont(ofSize: 30, weight: .semibold),
            .foregroundColor: UIColor.black
        ]
        let formato = UIGraphicsImageRendererFormat()
        formato.scale = 1
        return UIGraphicsImageRenderer(size: tamano, format: formato).image { _ in
            UIColor(white: 0.98, alpha: 1).setFill()
            UIRectFill(CGRect(origin: .zero, size: tamano))
            for (indice, (izquierda, derecha)) in filas.enumerated() {
                let y = 40 + CGFloat(indice) * altoFila
                (izquierda as NSString).draw(at: CGPoint(x: 40, y: y), withAttributes: atributos)
                let medida = (derecha as NSString).size(withAttributes: atributos)
                (derecha as NSString).draw(at: CGPoint(x: ancho - 40 - medida.width, y: y), withAttributes: atributos)
            }
        }
    }
}
