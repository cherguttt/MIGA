//
//  GastoHormigaTests.swift
//  ControlDeGastosTests
//
//  PRUEBAS UNITARIAS del Pipeline 3 del Motor Analítico: detección de gasto hormiga
//  (Sprint 5, RF-22). Caso CP-15 del Plan de pruebas (sección 4.4.11):
//  «9 gastos de $3.000 en 7 días; promedio histórico 4 → patrón detectado,
//  Costo_mes ≈ $115.714 > $20.000».
//

import XCTest
import SwiftData
@testable import ControlDeGastos

@MainActor
final class GastoHormigaTests: XCTestCase {

    /// Calendario fijo (gregoriano, hora de Chile) para que las pruebas no dependan del iPhone.
    private var calendario: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "America/Santiago")!
        return c
    }

    /// «Ahora» de las pruebas: miércoles 28 de octubre de 2026, 15:00.
    private var ahora: Date {
        calendario.date(from: DateComponents(year: 2026, month: 10, day: 28, hour: 15))!
    }

    /// Fecha `dias` días antes de `ahora` (y una hora antes, para quedar dentro de la ventana).
    private func haceDias(_ dias: Int) -> Date {
        calendario.date(byAdding: .hour, value: -(dias * 24 + 1), to: ahora)!
    }

    /// Crea un gasto (no hace falta guardarlo en la base de datos para esta función pura).
    private func gasto(_ monto: Decimal, _ dias: Int, _ categoria: CategoriaGasto = .alimentacion) -> Transaccion {
        Transaccion(monto: monto, categoria: categoria, fecha: haceDias(dias))
    }

    /// Escenario del CP-15: 9 gastos de $3.000 esta semana y 4 por semana en las 8 anteriores.
    /// El primer registro es de hace 70 días, así hay 8 semanas completas de historial.
    private func escenarioCP15(gastosSemanaActual: Int = 9, monto: Decimal = 3_000) -> [Transaccion] {
        var lista: [Transaccion] = []
        for i in 0..<gastosSemanaActual { lista.append(gasto(monto, i % 7)) }
        for semana in 1...8 {
            for k in 1...4 { lista.append(gasto(3_000, 7 * semana + k - 1)) }
        }
        return lista
    }

    private func detectar(_ lista: [Transaccion], primerRegistro: Int = 70) -> PatronGastoHormiga? {
        MotorAnalitico.detectarGastoHormiga(
            en: lista, categoria: .alimentacion, primerRegistro: haceDias(primerRegistro),
            ahora: ahora, calendario: calendario
        )
    }

    /// CP-15: se detecta el patrón y Costo_mes = 9 × 3.000 × 30 / 7 ≈ $115.714.
    func testCP15DetectaPatron() throws {
        let patron = try XCTUnwrap(detectar(escenarioCP15()))
        XCTAssertEqual(patron.frecuencia, 9)
        XCTAssertEqual(patron.promedioHistorico, 4, accuracy: 0.001)
        XCTAssertEqual(patron.montoPromedio, 3_000)
        XCTAssertEqual(patron.costoMensual, 115_714)
    }

    /// 6 gastos no superan 1,5 × 4 = 6: no hay patrón (la condición es «mayor que»).
    func testFrecuenciaIgualAlUmbralNoDetecta() {
        XCTAssertNil(detectar(escenarioCP15(gastosSemanaActual: 6)))
    }

    /// Con menos de dos semanas de historial no se evalúa.
    func testHistorialInsuficienteNoDetecta() {
        XCTAssertNil(detectar(escenarioCP15(), primerRegistro: 10))
    }

    /// Los gastos de $5.000 o más no son «pequeños».
    func testMontosDeCincoMilNoCuentan() {
        XCTAssertNil(detectar(escenarioCP15(monto: 5_000)))
    }

    /// Si el costo mensual estimado no supera $20.000, no se avisa:
    /// 2 × $2.000 × 30 / 7 ≈ $17.143.
    func testCostoBajoNoDetecta() {
        XCTAssertNil(detectar([gasto(2_000, 1), gasto(2_000, 2)], primerRegistro: 20))
    }

    /// Los gastos de otra categoría no cuentan.
    func testOtraCategoriaNoCuenta() {
        let lista = (0..<9).map { gasto(3_000, $0 % 7, .transporte) }
        XCTAssertNil(detectar(lista, primerRegistro: 20))
    }

    /// Los pagos de créditos nunca se consideran gasto hormiga.
    func testPagoCreditosNoEsGastoHormiga() {
        let lista = (0..<9).map { gasto(3_000, $0 % 7, .pagoCreditos) }
        XCTAssertNil(MotorAnalitico.detectarGastoHormiga(
            en: lista, categoria: .pagoCreditos, primerRegistro: haceDias(70),
            ahora: ahora, calendario: calendario
        ))
    }
}
