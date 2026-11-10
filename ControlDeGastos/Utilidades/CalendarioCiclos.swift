//
//  CalendarioCiclos.swift
//  ControlDeGastos
//
//  CAPA: Utilidades — calcula los CICLOS DE GASTO (después del Sprint 5).
//

import Foundation
import Observation

/// Un cambio de día de inicio, como valor simple (copia de la entidad CambioCiclo).
struct DatosCambioCiclo: Equatable {
    let diaInicio: Int
    let fechaCambio: Date
    let vigenteDesde: Date
}

/// Un ciclo concreto: su identificador y sus fechas.
struct Ciclo: Equatable {
    /// Identificador (mes y año) que usan los presupuestos.
    let clave: PeriodoMensual
    /// Primer instante del ciclo (00:00 del día de inicio).
    let inicio: Date
    /// Primer instante DESPUÉS del ciclo (exclusivo): el ciclo es [inicio, fin).
    let fin: Date

    var intervalo: DateInterval { DateInterval(start: inicio, end: fin) }
}

/// Calcula las fechas de cada ciclo de gastos según los cambios de día de inicio.
struct CalendarioCiclos {
    /// Calendario para sumar meses y obtener días (gregoriano, zona horaria del iPhone).
    var calendario: Calendar = .current
    /// Historial de cambios, ordenado por `vigenteDesde` (vacío = meses calendario).
    var cambios: [DatosCambioCiclo] = []

    /// Días que se pueden elegir como inicio del ciclo.
    static let diasPermitidos = 1...28

    /// Calendario que usa la app (se carga desde la base de datos al abrirla).
    static var compartido: CalendarioCiclos { CiclosActuales.compartidos.calendario }

    /// Copia con otro calendario (lo usan las pruebas con zona horaria fija).
    func con(_ calendario: Calendar) -> CalendarioCiclos {
        CalendarioCiclos(calendario: calendario, cambios: cambios)
    }

    // MARK: - Tramos

    /// Un TRAMO es un conjunto de ciclos seguidos con el mismo día de inicio.
    private struct Tramo {
        let dia: Int
        let primerInicio: Date?
        let primeraClave: Int?
        let ultimoInicio: Date?
        let ultimaClave: Int?
        let fin: Date?
    }

    private var tramos: [Tramo] {
        var resultado: [Tramo] = []
        var dia = 1
        var primerInicio: Date?
        var primeraClave: Int?
        for cambio in cambios.sorted(by: { $0.vigenteDesde < $1.vigenteDesde }) {
            let ultimo = inicioMasReciente(dia: dia, hasta: cambio.fechaCambio, desde: primerInicio)
            let ultimaClave = clave(de: ultimo, primerInicio: primerInicio, primeraClave: primeraClave)
            resultado.append(Tramo(dia: dia, primerInicio: primerInicio, primeraClave: primeraClave,
                                   ultimoInicio: ultimo, ultimaClave: ultimaClave, fin: cambio.vigenteDesde))
            dia = cambio.diaInicio
            primerInicio = cambio.vigenteDesde
            primeraClave = ultimaClave + 1
        }
        resultado.append(Tramo(dia: dia, primerInicio: primerInicio, primeraClave: primeraClave,
                               ultimoInicio: nil, ultimaClave: nil, fin: nil))
        return resultado
    }

    // MARK: - Consultas

    /// Ciclo que contiene una fecha.
    func ciclo(contiene fecha: Date) -> Ciclo {
        let tramo = tramos.last { $0.primerInicio == nil || $0.primerInicio! <= fecha } ?? tramos[0]
        var inicio = inicioMasReciente(dia: tramo.dia, hasta: fecha, desde: tramo.primerInicio)
        if let ultimo = tramo.ultimoInicio, inicio > ultimo { inicio = ultimo }
        return armar(inicio: inicio, tramo: tramo)
    }

    /// Ciclo correspondiente a un identificador (mes y año).
    func ciclo(clave periodo: PeriodoMensual) -> Ciclo {
        let k = Self.indice(periodo)
        let tramo = tramos.first { tramo in
            let desdeOK = tramo.primeraClave.map { k >= $0 } ?? true
            let hastaOK = tramo.ultimaClave.map { k <= $0 } ?? true
            return desdeOK && hastaOK
        } ?? tramos[tramos.count - 1]
        let inicio: Date
        if let primerInicio = tramo.primerInicio, let primeraClave = tramo.primeraClave {
            inicio = sumarMeses(k - primeraClave, a: primerInicio)
        } else {
            inicio = fechaDe(dia: tramo.dia, mes: periodo.mes, anio: periodo.anio)
        }
        return armar(inicio: inicio, tramo: tramo)
    }

    /// Día de inicio de los ciclos vigente en una fecha.
    func diaInicio(en fecha: Date = .now) -> Int {
        (tramos.last { $0.primerInicio == nil || $0.primerInicio! <= fecha } ?? tramos[0]).dia
    }

    /// Día de inicio que regirá en el futuro (incluye un cambio ya programado).
    var diaInicioFinal: Int { tramos.last?.dia ?? 1 }

    // MARK: - Cambio del día de inicio

    /// Fecha en que empezaría el primer ciclo con el nuevo día si se cambia `hoy`: el primer día `nuevoDia`
    /// desde hoy en adelante (puede ser hoy mismo).
    func primerInicio(conDia nuevoDia: Int, cambiandoEl hoy: Date) -> Date {
        let dia = calendario.startOfDay(for: hoy)
        let partes = calendario.dateComponents([.year, .month, .day], from: dia)
        let esteMes = fechaDe(dia: nuevoDia, mes: partes.month!, anio: partes.year!)
        return esteMes >= dia ? esteMes : sumarMeses(1, a: esteMes)
    }

    /// Devuelve el calendario que resultaría de cambiar el día de inicio `ahora`. de opinión): así nunca se
    /// acumulan transiciones de un solo día.
    func cambiando(diaInicio nuevoDia: Int, ahora: Date = .now) -> CalendarioCiclos {
        let hoy = calendario.startOfDay(for: ahora)
        var copia = self
        copia.cambios = cambios.filter { $0.vigenteDesde <= ahora && $0.fechaCambio < hoy }
        guard nuevoDia != copia.diaInicio(en: ahora) else { return copia }
        copia.cambios.append(DatosCambioCiclo(
            diaInicio: nuevoDia,
            fechaCambio: hoy,
            vigenteDesde: copia.primerInicio(conDia: nuevoDia, cambiandoEl: hoy)
        ))
        return copia
    }

    // MARK: - Funciones auxiliares

    /// Arma el ciclo que empieza en `inicio` dentro de un tramo.
    private func armar(inicio: Date, tramo: Tramo) -> Ciclo {
        let k = clave(de: inicio, primerInicio: tramo.primerInicio, primeraClave: tramo.primeraClave)
        let fin = (inicio == tramo.ultimoInicio ? tramo.fin : nil) ?? sumarMeses(1, a: inicio)
        return Ciclo(clave: Self.periodo(k), inicio: inicio, fin: fin)
    }

    /// Índice del ciclo que empieza en `inicio`.
    private func clave(de inicio: Date, primerInicio: Date?, primeraClave: Int?) -> Int {
        guard let primerInicio, let primeraClave else { return indiceMes(inicio) }
        return primeraClave + indiceMes(inicio) - indiceMes(primerInicio)
    }

    /// Último inicio de ciclo (día `dia`, a las 00:00) que no es posterior a `fecha`.
    private func inicioMasReciente(dia: Int, hasta fecha: Date, desde minimo: Date?) -> Date {
        let partes = calendario.dateComponents([.year, .month, .day], from: fecha)
        var inicio = fechaDe(dia: dia, mes: partes.month!, anio: partes.year!)
        if inicio > fecha { inicio = sumarMeses(-1, a: inicio) }
        if let minimo, inicio < minimo { inicio = minimo }
        return inicio
    }

    /// Fecha del día, mes y año indicados.
    private func fechaDe(dia: Int, mes: Int, anio: Int) -> Date {
        calendario.date(from: DateComponents(year: anio, month: mes, day: dia)) ?? .now
    }

    /// Suma (o resta) meses a una fecha.
    private func sumarMeses(_ meses: Int, a fecha: Date) -> Date {
        calendario.date(byAdding: .month, value: meses, to: fecha) ?? fecha
    }

    /// Meses contados desde el año 0 (enero de 2026 = 2026 × 12 + 0).
    private func indiceMes(_ fecha: Date) -> Int {
        let partes = calendario.dateComponents([.year, .month], from: fecha)
        return partes.year! * 12 + partes.month! - 1
    }

    /// Convierte un período en un número de mes correlativo.
    static func indice(_ periodo: PeriodoMensual) -> Int { periodo.anio * 12 + periodo.mes - 1 }
    /// Convierte un número de mes correlativo en su período.
    static func periodo(_ indice: Int) -> PeriodoMensual { PeriodoMensual(mes: indice % 12 + 1, anio: indice / 12) }
}

// MARK: - Calendario vigente en la app

/// Guarda el calendario de ciclos que usa la app.
@Observable
final class CiclosActuales {
    static let compartidos = CiclosActuales()
    var calendario = CalendarioCiclos()
}
