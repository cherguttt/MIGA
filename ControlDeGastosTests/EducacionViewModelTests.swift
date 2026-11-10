//
//  EducacionViewModelTests.swift
//  ControlDeGastosTests
//
//  PRUEBAS del ViewModel de la pestaña Educación (Sprint 5, RF-21) y de los nuevos
//  formatos de fecha.
//

import XCTest
import SwiftData
@testable import ControlDeGastos

@MainActor
final class EducacionViewModelTests: XCTestCase {

    /// Base de datos en memoria: los consejos y envíos se insertan en ella para que la
    /// relación Consejo ↔ EnvioConsejo funcione igual que en la app.
    // `lazy`: se crea la primera vez que se usa (dentro de una prueba, en el hilo principal).
    private lazy var contenedor = ContenedorDatos.crear(enMemoria: true)

    private func consejo(_ titulo: String, _ categoria: CategoriaConsejo, orden: Int) -> Consejo {
        let nuevo = Consejo(titulo: titulo, contenido: "Texto.", categoria: categoria, orden: orden)
        contenedor.mainContext.insert(nuevo)
        return nuevo
    }

    /// Los envíos programados para el futuro todavía no aparecen como recibidos.
    func testRecibidosExcluyeFuturos() {
        let c = consejo("A", .ahorro, orden: 1)
        let pasado = EnvioConsejo(consejo: c, fechaEnvio: .now.addingTimeInterval(-3_600), motivo: .semanal)
        let futuro = EnvioConsejo(consejo: c, fechaEnvio: .now.addingTimeInterval(86_400), motivo: .semanal)
        let recibidos = EducacionViewModel.recibidos([futuro, pasado])
        XCTAssertEqual(recibidos.map(\.id), [pasado.id])
    }

    /// El consejo de la semana es el último SEMANAL recibido, aunque haya un aviso de gasto hormiga más nuevo.
    func testConsejoDeLaSemana() {
        let c = consejo("A", .ahorro, orden: 1)
        let semanal = EnvioConsejo(consejo: c, fechaEnvio: .now.addingTimeInterval(-7_200), motivo: .semanal)
        let hormiga = EnvioConsejo(consejo: c, fechaEnvio: .now.addingTimeInterval(-60), motivo: .gastoHormiga)
        let recibidos = EducacionViewModel.recibidos([semanal, hormiga])
        XCTAssertEqual(EducacionViewModel.consejoDeLaSemana(recibidos)?.id, semanal.id)
    }

    /// La grilla muestra las seis temáticas y solo cuenta los consejos activos.
    func testTemas() {
        let inactivo = consejo("C", .deuda, orden: 3)
        inactivo.activo = false
        let temas = EducacionViewModel.temas([consejo("A", .ahorro, orden: 1), consejo("B", .ahorro, orden: 2), inactivo])
        XCTAssertEqual(temas.count, 6)
        XCTAssertEqual(temas.first { $0.categoria == .ahorro }?.textoCantidad, "2 consejos")
        XCTAssertEqual(temas.first { $0.categoria == .deuda }?.cantidad, 0)
    }

    /// Texto del detalle, como en el mockup P7.
    func testDescripcionEnvioSemanal() {
        let lunes = Calendar.current.date(from: DateComponents(year: 2026, month: 10, day: 5, hour: 9))!
        let envio = EnvioConsejo(consejo: consejo("A", .deuda, orden: 1), fechaEnvio: lunes, motivo: .semanal)
        XCTAssertEqual(EducacionViewModel.descripcionEnvio(envio), "Consejo semanal · recibido el lunes 5 de octubre")
        XCTAssertEqual(EducacionViewModel.descripcionEnvio(nil), "Biblioteca de consejos")
    }

    /// «hoy», «ayer» y «hace 7 días» (mockup P6).
    func testHaceDias() {
        let ahora = Date.now
        let calendario = Calendar.current
        XCTAssertEqual(Formato.haceDias(ahora, ahora: ahora), "hoy")
        XCTAssertEqual(Formato.haceDias(calendario.date(byAdding: .day, value: -1, to: ahora)!, ahora: ahora), "ayer")
        XCTAssertEqual(Formato.haceDias(calendario.date(byAdding: .day, value: -7, to: ahora)!, ahora: ahora), "hace 7 días")
    }
}

// MARK: - Consejo emergente al abrir la app

extension EducacionViewModelTests {

    /// Con dos consejos, nunca se repite el último mostrado.
    func testConsejoAleatorioNoRepiteElUltimo() {
        let a = consejo("A", .ahorro, orden: 1)
        let b = consejo("B", .deuda, orden: 2)
        for _ in 0..<20 {
            XCTAssertEqual(EducacionViewModel.consejoAleatorio(de: [a, b], excepto: a.id)?.id, b.id)
        }
    }

    /// Los consejos inactivos no se muestran; sin consejos no hay aviso.
    func testConsejoAleatorioSoloActivos() {
        let inactivo = consejo("C", .habitos, orden: 3)
        inactivo.activo = false
        XCTAssertNil(EducacionViewModel.consejoAleatorio(de: [inactivo], excepto: nil))
        XCTAssertNil(EducacionViewModel.consejoAleatorio(de: [], excepto: nil))
    }

    /// Si hay un solo consejo, se muestra aunque haya sido el último.
    func testConsejoAleatorioConUnSoloConsejo() {
        let unico = consejo("U", .ahorro, orden: 1)
        XCTAssertEqual(EducacionViewModel.consejoAleatorio(de: [unico], excepto: unico.id)?.id, unico.id)
    }

    /// Con muchos consejos, el azar reparte: en 200 intentos aparecen varios distintos.
    func testConsejoAleatorioVaria() {
        let lista = (1...10).map { consejo("C\($0)", .ahorro, orden: $0) }
        let vistos = Set((0..<200).compactMap { _ in EducacionViewModel.consejoAleatorio(de: lista, excepto: nil)?.id })
        XCTAssertGreaterThan(vistos.count, 5)
    }
}
