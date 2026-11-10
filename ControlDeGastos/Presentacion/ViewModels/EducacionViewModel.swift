//
//  EducacionViewModel.swift
//  ControlDeGastos
//
//  CAPA: Presentación — estado y lógica de la pestaña «Educación» (Sprint 5, CU-07, RF-21 y RF-23).
//  Mockups P6 (Educación) y P7 (Detalle de consejo).
//
//  Las funciones que calculan lo que se muestra son «puras» (reciben listas y devuelven
//  resultados), así se pueden probar con XCTest sin dibujar la pantalla.
//

import Foundation
import Observation
import SwiftData

/// Una tarjeta de la grilla «Explorar por tema»: temática y cantidad de consejos.
struct TemaConsejos: Identifiable, Equatable {
    let categoria: CategoriaConsejo
    let cantidad: Int
    var id: CategoriaConsejo { categoria }

    /// «6 consejos» o «1 consejo».
    var textoCantidad: String { cantidad == 1 ? "1 consejo" : "\(cantidad) consejos" }
}

/// Destinos de navegación dentro de la pestaña Educación.
/// `Hashable` es requisito de `NavigationStack(path:)`.
enum DestinoEducacion: Hashable {
    case tema(CategoriaConsejo)   // Lista de consejos de una temática.
    case consejo(Consejo)         // Detalle de un consejo de la biblioteca.
    case envio(EnvioConsejo)      // Detalle de un consejo recibido (con valoración).
}

@Observable
final class EducacionViewModel {

    /// Pila de navegación: cada elemento es una pantalla abierta encima de la anterior.
    var ruta: [DestinoEducacion] = []

    /// Cantidad máxima de filas en «Recibidos recientemente».
    static let maximoRecientes = 10

    // MARK: Cálculos (funciones puras)

    /// Envíos ya recibidos (fecha menor o igual a ahora), del más reciente al más antiguo.
    /// Los consejos semanales programados para lunes futuros todavía no se muestran.
    static func recibidos(_ envios: [EnvioConsejo], ahora: Date = .now) -> [EnvioConsejo] {
        envios
            .filter { $0.fechaEnvio <= ahora && $0.consejo != nil }
            .sorted { $0.fechaEnvio > $1.fechaEnvio }
    }

    /// «Consejo de esta semana»: el último consejo semanal recibido
    /// (o, si no hay ninguno, el último recibido por cualquier motivo).
    static func consejoDeLaSemana(_ recibidos: [EnvioConsejo]) -> EnvioConsejo? {
        recibidos.first { $0.motivo == .semanal } ?? recibidos.first
    }

    /// Las seis temáticas con su cantidad de consejos activos (grilla del mockup P6).
    static func temas(_ consejos: [Consejo]) -> [TemaConsejos] {
        CategoriaConsejo.allCases.map { categoria in
            TemaConsejos(categoria: categoria, cantidad: consejos.filter { $0.activo && $0.categoria == categoria }.count)
        }
    }

    /// Consejos activos de una temática, en orden.
    static func consejos(de categoria: CategoriaConsejo, en consejos: [Consejo]) -> [Consejo] {
        consejos.filter { $0.activo && $0.categoria == categoria }.sorted { $0.orden < $1.orden }
    }

    /// Envío con el que se valora un consejo abierto desde la biblioteca: el más reciente
    /// ya recibido. Si el consejo nunca se ha enviado, no hay valoración (`nil`).
    static func envioParaValorar(_ consejo: Consejo, ahora: Date = .now) -> EnvioConsejo? {
        consejo.envios.filter { $0.fechaEnvio <= ahora }.max { $0.fechaEnvio < $1.fechaEnvio }
    }

    /// Texto bajo el título del detalle, por ejemplo:
    /// «Consejo semanal · recibido el lunes 5 de octubre» (mockup P7).
    static func descripcionEnvio(_ envio: EnvioConsejo?) -> String {
        guard let envio else { return "Biblioteca de consejos" }
        let fecha = Formato.fechaLarga(envio.fechaEnvio)
        switch envio.motivo {
        case .semanal:
            return "Consejo semanal · recibido el \(fecha)"
        case .gastoHormiga:
            let donde = envio.categoriaGasto.map { " en \($0.nombre)" } ?? ""
            return "Aviso de gasto hormiga\(donde) · recibido el \(fecha)"
        }
    }

    /// Consejo emergente al abrir la app: uno al azar entre los activos, distinto del último
    /// que se mostró (si hay más de uno). Devuelve `nil` si no hay consejos.
    /// `generador` permite fijar el azar en las pruebas; en la app se usa el del sistema.
    static func consejoAleatorio<G: RandomNumberGenerator>(
        de consejos: [Consejo],
        excepto ultimo: UUID?,
        generador: inout G
    ) -> Consejo? {
        let activos = consejos.filter(\.activo)
        let candidatos = activos.count > 1 ? activos.filter { $0.id != ultimo } : activos
        // `randomElement(using:)` elige un elemento al azar con el generador indicado.
        return candidatos.randomElement(using: &generador)
    }

    /// Versión con el generador de números aleatorios del sistema.
    static func consejoAleatorio(de consejos: [Consejo], excepto ultimo: UUID?) -> Consejo? {
        var generador = SystemRandomNumberGenerator()
        return consejoAleatorio(de: consejos, excepto: ultimo, generador: &generador)
    }

    // MARK: Acciones

    /// RF-23: guarda la respuesta a «¿Te fue útil este consejo?».
    func valorar(_ envio: EnvioConsejo, util: Bool, contexto: ModelContext) {
        try? ServicioConsejos(contexto: contexto).valorar(envio, util: util)
    }

    /// CU-07, paso 5: abre el consejo cuya notificación tocó el usuario.
    /// Devuelve `true` si lo encontró.
    @discardableResult
    func abrirEnvio(id: UUID, en envios: [EnvioConsejo]) -> Bool {
        guard let envio = envios.first(where: { $0.id == id }) else { return false }
        ruta = [.envio(envio)]
        return true
    }

    /// Abre el detalle de un consejo de la biblioteca (desde el aviso emergente).
    @discardableResult
    func abrirConsejo(id: UUID, en consejos: [Consejo]) -> Bool {
        guard let consejo = consejos.first(where: { $0.id == id }) else { return false }
        ruta = [.consejo(consejo)]
        return true
    }
}
