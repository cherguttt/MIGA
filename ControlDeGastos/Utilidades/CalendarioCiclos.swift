//
//  CalendarioCiclos.swift
//  ControlDeGastos
//
//  CAPA: Utilidades — calcula los CICLOS DE GASTO (después del Sprint 5).
//
//  ¿QUÉ ES UN CICLO?
//  Es el período en que se agrupan los gastos y se aplican los presupuestos. Por defecto va
//  del día 1 al último día del mes. Si el usuario elige, por ejemplo, el día 25 (porque ese
//  día le pagan), cada ciclo va del 25 de un mes al 24 del mes siguiente.
//
//  CAMBIO A MITAD DE CICLO: «CICLO DE TRANSICIÓN»
//  Si el usuario cambia el día con un ciclo en curso, ese ciclo no se rehace: se alarga o
//  se acorta hasta el día anterior al primer inicio con el nuevo día. Ejemplo (hoy 5 de nov.):
//
//      Ciclos pasados   → no cambian (octubre sigue siendo del 1 al 31)
//      Ciclo actual     → 1 nov – 24 nov   (transición)
//      Desde el 25 nov  → 25 nov – 24 dic, 25 dic – 24 ene, …
//
//  Las compras nunca se modifican: cada gasto conserva su fecha y el ciclo solo decide en qué
//  grupo se suma.
//
//  IDENTIFICADOR DE CADA CICLO
//  Cada ciclo se identifica con un PeriodoMensual (mes y año), que es lo que guarda cada
//  Presupuesto. Los ciclos se numeran en orden, sin saltos ni repeticiones: el ciclo
//  siguiente siempre es «mes + 1». Con el día 1, el identificador es el mes calendario.
//

import Foundation
import Observation

/// Un cambio de día de inicio, como valor simple (copia de la entidad CambioCiclo).
/// Así los cálculos no dependen de la base de datos y se pueden probar fácilmente.
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
    /// El primero (sin `primerInicio`) viene desde siempre con el día 1.
    private struct Tramo {
        let dia: Int
        let primerInicio: Date?      // nil = tramo base (sin límite hacia atrás)
        let primeraClave: Int?       // índice del primer ciclo (nil en el tramo base)
        let ultimoInicio: Date?      // inicio del ciclo de transición (nil = último tramo)
        let ultimaClave: Int?
        let fin: Date?               // fin del ciclo de transición (= inicio del tramo siguiente)
    }

    private var tramos: [Tramo] {
        var resultado: [Tramo] = []
        var dia = 1
        var primerInicio: Date?
        var primeraClave: Int?
        for cambio in cambios.sorted(by: { $0.vigenteDesde < $1.vigenteDesde }) {
            // El ciclo en curso el día del cambio es el último de este tramo (transición).
            let ultimo = inicioMasReciente(dia: dia, hasta: cambio.fechaCambio, desde: primerInicio)
            let ultimaClave = clave(de: ultimo, primerInicio: primerInicio, primeraClave: primeraClave)
            resultado.append(Tramo(dia: dia, primerInicio: primerInicio, primeraClave: primeraClave,
                                   ultimoInicio: ultimo, ultimaClave: ultimaClave, fin: cambio.vigenteDesde))
            dia = cambio.diaInicio
            primerInicio = cambio.vigenteDesde
            primeraClave = ultimaClave + 1   // Numeración seguida: sin saltos ni repeticiones.
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

    /// Fecha en que empezaría el primer ciclo con el nuevo día si se cambia `hoy`:
    /// el primer día `nuevoDia` desde hoy en adelante (puede ser hoy mismo).
    func primerInicio(conDia nuevoDia: Int, cambiandoEl hoy: Date) -> Date {
        let dia = calendario.startOfDay(for: hoy)
        let partes = calendario.dateComponents([.year, .month, .day], from: dia)
        let esteMes = fechaDe(dia: nuevoDia, mes: partes.month!, anio: partes.year!)
        return esteMes >= dia ? esteMes : sumarMeses(1, a: esteMes)
    }

    /// Devuelve el calendario que resultaría de cambiar el día de inicio `ahora`.
    /// - Se descartan los cambios que aún no rigen y los hechos hoy mismo (el usuario cambió
    ///   de opinión): así nunca se acumulan transiciones de un solo día.
    /// - Si el nuevo día es el que ya rige, solo se descarta lo pendiente.
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

    private func fechaDe(dia: Int, mes: Int, anio: Int) -> Date {
        calendario.date(from: DateComponents(year: anio, month: mes, day: dia)) ?? .now
    }

    private func sumarMeses(_ meses: Int, a fecha: Date) -> Date {
        calendario.date(byAdding: .month, value: meses, to: fecha) ?? fecha
    }

    /// Meses contados desde el año 0 (enero de 2026 = 2026 × 12 + 0).
    private func indiceMes(_ fecha: Date) -> Int {
        let partes = calendario.dateComponents([.year, .month], from: fecha)
        return partes.year! * 12 + partes.month! - 1
    }

    static func indice(_ periodo: PeriodoMensual) -> Int { periodo.anio * 12 + periodo.mes - 1 }
    static func periodo(_ indice: Int) -> PeriodoMensual { PeriodoMensual(mes: indice % 12 + 1, anio: indice / 12) }
}

// MARK: - Calendario vigente en la app

/// Guarda el calendario de ciclos que usa la app. Es `@Observable`: cuando el usuario cambia
/// el día de inicio, todas las pantallas que muestran ciclos se vuelven a dibujar solas.
@Observable
final class CiclosActuales {
    static let compartidos = CiclosActuales()
    var calendario = CalendarioCiclos()
}
