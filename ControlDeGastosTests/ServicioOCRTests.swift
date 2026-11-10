//
//  ServicioOCRTests.swift
//  ControlDeGastosTests
//
//  PRUEBAS del Servicio OCR (Sprint 4). Casos CP-12 y CP-13 del Plan de pruebas (sección 4.4.11):
//  - CP-12: boleta con la línea «TOTAL» → se extrae el monto correcto.
//  - CP-13: boleta sin la línea «TOTAL» → no hay monto y se pasa al ingreso manual.
//
//  La mayoría de las pruebas usan TEXTO (las filas que Vision habría leído), porque así son
//  rápidas y siempre dan el mismo resultado. La última lee una IMAGEN real con Vision.
//

import XCTest
import CoreGraphics
@testable import ControlDeGastos

@MainActor
final class ServicioOCRTests: XCTestCase {

    // MARK: - Lectura de montos

    /// «TOTAL $12.500» → 12500 (el punto separa miles en Chile).
    func testMontoConPuntoDeMiles() {
        XCTAssertEqual(ServicioOCR.ultimoMonto(en: "TOTAL $12.500"), 12_500)
    }

    /// Los decimales se descartan y el signo «$» con espacio no molesta.
    func testMontoConDecimalesYEspacios() {
        XCTAssertEqual(ServicioOCR.ultimoMonto(en: "TOTAL $ 12.500,00"), 12_500)
        XCTAssertEqual(ServicioOCR.ultimoMonto(en: "TOTAL: 1.234.567"), 1_234_567)
    }

    /// Una fila sin números no tiene monto.
    func testFilaSinNumeroNoTieneMonto() {
        XCTAssertNil(ServicioOCR.ultimoMonto(en: "TOTAL"))
    }

    // MARK: - CP-12: boleta con «TOTAL»

    /// CP-12: boleta completa (la del mockup P4) → total $12.500.
    func testCP12ExtraeTotalDeBoleta() {
        let filas = BoletaDeEjemplo.filas.map { "\($0.0) \($0.1)" }
        let resultado = ServicioOCR.extraerTotal(de: filas)
        XCTAssertTrue(resultado.detectado)
        XCTAssertEqual(resultado.monto, 12_500)
        XCTAssertEqual(resultado.linea, "TOTAL $12.500")
    }

    /// «SUBTOTAL» y «TOTAL IVA» no son el total a pagar.
    func testIgnoraSubtotalEIva() {
        let filas = ["SUBTOTAL 10.504", "TOTAL IVA 1.996", "TOTAL $12.500", "EFECTIVO 20.000"]
        XCTAssertEqual(ServicioOCR.extraerTotal(de: filas).monto, 12_500)
    }

    /// No importan mayúsculas ni tildes: «Total», «TOTÁL».
    func testIgnoraMayusculasYTildes() {
        XCTAssertEqual(ServicioOCR.extraerTotal(de: ["Total a pagar 8.990"]).monto, 8_990)
        XCTAssertEqual(ServicioOCR.extraerTotal(de: ["TOTÁL 3.500"]).monto, 3_500)
    }

    /// Si el monto quedó en la fila de abajo, se toma de ahí.
    func testMontoEnLaFilaSiguiente() {
        let resultado = ServicioOCR.extraerTotal(de: ["TOTAL", "$12.500", "GRACIAS"])
        XCTAssertEqual(resultado.monto, 12_500)
        XCTAssertEqual(resultado.linea, "TOTAL $12.500")
    }

    /// Con varias filas «TOTAL», gana la última (el total final).
    func testUsaElUltimoTotal() {
        let filas = ["TOTAL PARCIAL 5.000", "DESCUENTO 500", "TOTAL 4.500"]
        XCTAssertEqual(ServicioOCR.extraerTotal(de: filas).monto, 4_500)
    }

    // MARK: - CP-13: boleta sin «TOTAL»

    /// CP-13: sin la palabra «TOTAL» no hay monto (flujo alternativo: ingreso manual).
    func testCP13SinTotalNoDetecta() {
        let filas = ["MINIMARKET LOS AROMOS", "PAN AMASADO 2.890", "GRACIAS POR SU COMPRA"]
        let resultado = ServicioOCR.extraerTotal(de: filas)
        XCTAssertFalse(resultado.detectado)
        XCTAssertNil(resultado.monto)
    }

    /// CP-13: si solo aparece «SUBTOTAL», tampoco hay total.
    func testCP13SoloSubtotalNoDetecta() {
        XCTAssertNil(ServicioOCR.extraerTotal(de: ["SUBTOTAL 10.504"]).monto)
    }

    /// CP-13: una lista vacía (Vision no leyó nada) no detecta total.
    func testCP13SinTextoNoDetecta() {
        XCTAssertEqual(ServicioOCR.extraerTotal(de: [String]()), .sinResultado)
    }

    // MARK: - Agrupación en filas

    /// Dos bloques a la misma altura se unen de izquierda a derecha;
    /// un bloque más abajo forma otra fila.
    func testAgrupaBloquesDeLaMismaFila() {
        // Recuerda: en Vision la «y» crece hacia ARRIBA.
        let bloques = [
            FilaTexto(texto: "$12.500", caja: CGRect(x: 0.70, y: 0.40, width: 0.20, height: 0.04)),
            FilaTexto(texto: "GRACIAS", caja: CGRect(x: 0.30, y: 0.30, width: 0.40, height: 0.04)),
            FilaTexto(texto: "TOTAL", caja: CGRect(x: 0.10, y: 0.405, width: 0.15, height: 0.04))
        ]
        let filas = ServicioOCR.agruparEnFilas(bloques)
        XCTAssertEqual(filas.map(\.texto), ["TOTAL $12.500", "GRACIAS"])
        // La caja de la fila une ambos bloques: va de x = 0,10 a x = 0,90.
        let caja = filas.first?.caja
        XCTAssertEqual(caja?.minX ?? 0, 0.10, accuracy: 0.001)
        XCTAssertEqual(caja?.maxX ?? 0, 0.90, accuracy: 0.001)
    }

    // MARK: - OCR real con Vision

    /// Lee con Vision la imagen de la boleta de ejemplo y verifica el total (CP-12 de punta a punta).
    func testOCRSobreImagenDeEjemplo() async throws {
        let imagen = try XCTUnwrap(BoletaDeEjemplo.imagen().cgImage)
        let resultado = try await ServicioOCR.extraerTotal(de: imagen)
        XCTAssertEqual(resultado.monto, 12_500)
        XCTAssertNotNil(resultado.caja)   // Hay posición para marcar la fila en amarillo.
    }
}
