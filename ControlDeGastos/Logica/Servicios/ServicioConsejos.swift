//
//  ServicioConsejos.swift
//  ControlDeGastos
//
//  CAPA: Lógica de negocio — Servicio de Consejos (Sprint 5: CU-07, RF-20, RF-22 y RF-23).
//

import Foundation
import SwiftData

// MARK: - Aviso de consejo (independiente de iOS)

/// Datos de una notificación de consejo.
struct AvisoConsejo: Equatable {
    let identificador: String
    let titulo: String
    let subtitulo: String
    let cuerpo: String
    /// Fecha programada; `nil` = mostrar de inmediato.
    let fecha: Date?
}

/// PROTOCOLO para programar y cancelar avisos de consejos (inyección de dependencias, igual que `Notificador`
/// en GestorAlertas.swift).
protocol ProgramadorConsejos {
    /// Programa un aviso de consejo como notificación.
    func programar(_ aviso: AvisoConsejo)
    /// Cancela los avisos pendientes con esos identificadores.
    func cancelar(identificadores: [String])
}

// MARK: - Formato del archivo ConsejosIniciales.json

/// Un consejo tal como viene escrito en el archivo JSON.
struct ConsejoJSON: Decodable {
    let orden: Int
    let categoria: CategoriaConsejo
    let titulo: String
    let contenido: String
    let ejemplo: String?
    let icono: String?
}

/// Errores del servicio.
enum ErrorConsejos: LocalizedError {
    case archivoNoEncontrado
    var errorDescription: String? { "No se encontró el archivo de consejos iniciales." }
}

// MARK: - Servicio

/// Precarga, programa y registra los consejos de educación financiera (CU-07).
struct ServicioConsejos {
    let contexto: ModelContext
    var programador: any ProgramadorConsejos = ProgramadorConsejosLocal()
    var calendario: Calendar = .current

    /// Cuántos lunes por adelantado se dejan programados. iOS permite hasta 64 notificaciones pendientes por
    /// app; con 4 sobra espacio y la lista se renueva cada vez que se abre la app.
    static let semanasProgramadas = 4
    /// Día y hora del consejo semanal: lunes (2 en el calendario gregoriano) a las 9:00.
    static let diaSemanal = 2
    static let horaSemanal = 9

    // MARK: 1. Precarga

    /// Carga los consejos del archivo JSON si la tabla está vacía.
    @discardableResult
    func precargarSiHaceFalta(bundle: Bundle = .main) throws -> Int {
        guard try contexto.fetchCount(FetchDescriptor<Consejo>()) == 0 else { return 0 }
        guard let url = bundle.url(forResource: "ConsejosIniciales", withExtension: "json") else {
            throw ErrorConsejos.archivoNoEncontrado
        }
        return try precargar(desde: Data(contentsOf: url))
    }

    /// Inserta los consejos contenidos en un JSON (se separa para poder probarlo).
    @discardableResult
    func precargar(desde datos: Data) throws -> Int {
        let lista = try JSONDecoder().decode([ConsejoJSON].self, from: datos)
        for item in lista {
            contexto.insert(Consejo(
                titulo: item.titulo,
                contenido: item.contenido,
                ejemplo: item.ejemplo,
                categoria: item.categoria,
                orden: item.orden,
                icono: item.icono
            ))
        }
        try contexto.save()
        return lista.count
    }

    // MARK: Consultas

    /// Consejos activos, en el orden de la secuencia semanal.
    func consejosActivos() throws -> [Consejo] {
        let descriptor = FetchDescriptor<Consejo>(
            predicate: #Predicate { $0.activo },
            sortBy: [SortDescriptor(\.orden)]
        )
        return try contexto.fetch(descriptor)
    }

    /// Todos los envíos, del más antiguo al más reciente.
    func envios() throws -> [EnvioConsejo] {
        try contexto.fetch(FetchDescriptor<EnvioConsejo>(sortBy: [SortDescriptor(\.fechaEnvio)]))
    }

    /// Envíos ya «recibidos» (fecha menor o igual a ahora), del más reciente al más antiguo.
    func recibidos(ahora: Date = .now) throws -> [EnvioConsejo] {
        let descriptor = FetchDescriptor<EnvioConsejo>(
            predicate: #Predicate { $0.fechaEnvio <= ahora },
            sortBy: [SortDescriptor(\.fechaEnvio, order: .reverse)]
        )
        return try contexto.fetch(descriptor)
    }

    /// El perfil del usuario (puede no existir en las pruebas).
    private func perfil() throws -> PerfilUsuario? {
        try contexto.fetch(FetchDescriptor<PerfilUsuario>()).first
    }

    // MARK: 2. Consejo semanal (RF-20)

    /// Próximo lunes a las 9:00 estrictamente posterior a `fecha`.
    func proximoLunes(despuesDe fecha: Date) -> Date? {
        calendario.nextDate(
            after: fecha,
            matching: DateComponents(hour: Self.horaSemanal, minute: 0, weekday: Self.diaSemanal),
            matchingPolicy: .nextTime
        )
    }

    /// El consejo que sigue a `anterior` en la secuencia.
    static func siguiente(despuesDe anterior: Consejo?, en consejos: [Consejo]) -> Consejo? {
        guard let anterior else { return consejos.first }
        return consejos.first { $0.orden > anterior.orden } ?? consejos.first
    }

    /// CU-07, pasos 1, 2 y 4: deja programados los próximos consejos semanales. tenga contenido desde el
    /// primer día (sin notificación: el usuario está en la app). programa su notificación, hasta tener
    /// `semanasProgramadas` pendientes.
    func programarSemanal(ahora: Date = .now) throws {
        guard try perfil()?.consejoSemanalActivo ?? true else { return }
        let consejos = try consejosActivos()
        guard !consejos.isEmpty else { return }

        var semanales = try envios().filter { $0.motivo == .semanal }

        if semanales.isEmpty, let primero = consejos.first {
            let envio = EnvioConsejo(consejo: primero, fechaEnvio: ahora, motivo: .semanal)
            contexto.insert(envio)
            semanales.append(envio)
        }

        var pendientes = semanales.filter { $0.fechaEnvio > ahora }
        while pendientes.count < Self.semanasProgramadas,
              let ultimo = semanales.last,
              let fecha = proximoLunes(despuesDe: max(ahora, ultimo.fechaEnvio)),
              let consejo = Self.siguiente(despuesDe: ultimo.consejo, en: consejos) {
            let envio = EnvioConsejo(consejo: consejo, fechaEnvio: fecha, motivo: .semanal)
            contexto.insert(envio)
            semanales.append(envio)
            pendientes.append(envio)
        }
        try contexto.save()

        for envio in pendientes {
            if let aviso = Self.aviso(para: envio) { programador.programar(aviso) }
        }
    }

    /// Flujo alternativo del CU-07: el usuario desactiva el consejo semanal.
    func cancelarSemanal(ahora: Date = .now) throws {
        let futuros = try envios().filter { $0.motivo == .semanal && $0.fechaEnvio > ahora }
        programador.cancelar(identificadores: futuros.map(\.identificadorNotificacion))
        for envio in futuros { contexto.delete(envio) }
        try contexto.save()
    }

    /// Arma la notificación de un envío (mockup P9).
    static func aviso(para envio: EnvioConsejo, cuerpo: String? = nil) -> AvisoConsejo? {
        guard let consejo = envio.consejo else { return nil }
        let esSemanal = envio.motivo == .semanal
        return AvisoConsejo(
            identificador: envio.identificadorNotificacion,
            titulo: consejo.titulo,
            subtitulo: esSemanal ? "Consejo semanal" : "Gasto hormiga detectado",
            cuerpo: cuerpo ?? consejo.primeraOracion,
            fecha: esSemanal ? envio.fechaEnvio : nil
        )
    }

    // MARK: 3. Consejo contextual por gasto hormiga (RF-22)

    /// CU-07, paso 3: revisa si hay un patrón de gasto hormiga en la categoría y, si lo hay, envía de
    /// inmediato un consejo de la temática «Gasto hormiga».
    @discardableResult
    func evaluarGastoHormiga(categoria: CategoriaGasto, ahora: Date = .now) throws -> EnvioConsejo? {
        guard let desde = calendario.date(byAdding: .day, value: -63, to: ahora) else { return nil }
        let recientes = try contexto.fetch(FetchDescriptor<Transaccion>(
            predicate: #Predicate { $0.fecha > desde }
        ))
        var primero = FetchDescriptor<Transaccion>(sortBy: [SortDescriptor(\.fecha)])
        primero.fetchLimit = 1
        guard let primerRegistro = try contexto.fetch(primero).first?.fecha else { return nil }

        guard let patron = MotorAnalitico.detectarGastoHormiga(
            en: recientes, categoria: categoria, primerRegistro: primerRegistro,
            ahora: ahora, calendario: calendario
        ) else { return nil }

        guard let haceUnaSemana = calendario.date(byAdding: .day, value: -7, to: ahora) else { return nil }
        let avisoReciente = try envios().contains {
            $0.motivo == .gastoHormiga && $0.categoriaGasto == categoria && $0.fechaEnvio > haceUnaSemana
        }
        guard !avisoReciente else { return nil }

        let candidatos = try consejosActivos().filter { $0.categoria == .gastoHormiga }
        guard let consejo = candidatos.min(by: { ultimaFecha($0) < ultimaFecha($1) }) else { return nil }

        let envio = EnvioConsejo(consejo: consejo, fechaEnvio: ahora, motivo: .gastoHormiga, categoriaGasto: categoria)
        contexto.insert(envio)
        try contexto.save()
        if let aviso = Self.aviso(para: envio, cuerpo: Self.cuerpoGastoHormiga(patron)) {
            programador.programar(aviso)
        }
        return envio
    }

    /// Fecha del último envío de un consejo (`.distantPast` si nunca se envió).
    private func ultimaFecha(_ consejo: Consejo) -> Date {
        consejo.envios.map(\.fechaEnvio).max() ?? .distantPast
    }

    /// Texto de la notificación contextual, por ejemplo: «Llevas 9 gastos pequeños en Alimentación esta
    /// semana: a este ritmo suman $115.714 al mes.»
    static func cuerpoGastoHormiga(_ patron: PatronGastoHormiga) -> String {
        "Llevas \(patron.frecuencia) gastos pequeños en \(patron.categoria.nombre) esta semana: "
            + "a este ritmo suman \(Formato.pesos(patron.costoMensual)) al mes."
    }

    // MARK: 4. Valoración (RF-23)

    /// CU-07, paso 6: guarda la respuesta a «¿Te fue útil?».
    func valorar(_ envio: EnvioConsejo, util: Bool) throws {
        envio.util = util
        try contexto.save()
    }

    // MARK: Inicio de la app

    /// Se llama al abrir la app (ContentView): precarga y programa.
    func prepararAlIniciar(ahora: Date = .now) {
        _ = try? precargarSiHaceFalta()
        try? programarSemanal(ahora: ahora)
    }
}
