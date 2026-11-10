//
//  PeriodoMensual.swift
//  ControlDeGastos
//
//  CAPA: Utilidades — identifica un CICLO DE GASTO por su mes y año (por ejemplo, octubre de 2026).
//

import Foundation

/// Identificador de un ciclo.
struct PeriodoMensual: Hashable {
    /// Mes, de 1 (enero) a 12 (diciembre).
    let mes: Int
    /// Año, por ejemplo 2026.
    let anio: Int

    /// Crea un período indicando mes y año directamente.
    init(mes: Int, anio: Int) {
        self.mes = mes
        self.anio = anio
    }

    /// Crea el período del ciclo que contiene una fecha.
    init(_ fecha: Date = .now, ciclos: CalendarioCiclos = .compartido) {
        self = ciclos.ciclo(contiene: fecha).clave
    }

    /// Igual que el anterior, pero con un calendario propio (lo usan las pruebas).
    init(_ fecha: Date, calendario: Calendar) {
        self.init(fecha, ciclos: CalendarioCiclos.compartido.con(calendario))
    }

    /// Fechas reales del ciclo.
    func ciclo(_ ciclos: CalendarioCiclos = .compartido) -> Ciclo { ciclos.ciclo(clave: self) }

    /// Primer instante del ciclo (día de inicio a las 00:00).
    func inicio(_ calendario: Calendar = .current) -> Date {
        ciclo(CalendarioCiclos.compartido.con(calendario)).inicio
    }

    /// Intervalo [inicio, fin) del ciclo; se usa en las consultas a la base de datos.
    func intervalo(_ calendario: Calendar = .current) -> DateInterval {
        ciclo(CalendarioCiclos.compartido.con(calendario)).intervalo
    }

    /// Devuelve el período desplazado `meses` hacia adelante (positivo) o hacia atrás (negativo).
    func desplazado(meses: Int) -> PeriodoMensual {
        let total = anio * 12 + (mes - 1) + meses
        return PeriodoMensual(mes: total % 12 + 1, anio: total / 12)
    }

    /// Ciclo anterior y ciclo siguiente (propiedades calculadas).
    var anterior: PeriodoMensual { desplazado(meses: -1) }
    var siguiente: PeriodoMensual { desplazado(meses: 1) }

    /// Indica si una fecha cae dentro de este ciclo.
    func contiene(_ fecha: Date, calendario: Calendar = .current) -> Bool {
        let intervalo = intervalo(calendario)
        return fecha >= intervalo.start && fecha < intervalo.end
    }

    // MARK: - Textos para la pantalla

    /// `true` si el ciclo coincide con un mes calendario completo (del 1 al último día).
    var esMesCalendario: Bool {
        let c = ciclo()
        let calendario = Calendar.current
        return calendario.component(.day, from: c.inicio) == 1
            && calendario.date(byAdding: .month, value: 1, to: c.inicio) == c.fin
    }

    /// Nombre completo: «Octubre de 2026» o, si no es un mes calendario, «25 oct. – 24 nov. 2026».
    var nombre: String {
        esMesCalendario ? Formato.capitalizar(Formato.mesAnio(inicio())) : Formato.rangoCiclo(ciclo())
    }

    /// Nombre corto para el selector: «Sept.» o «25 sept.».
    var nombreCorto: String {
        esMesCalendario ? Formato.mesCorto(inicio()) : Formato.diaMesCorto(inicio())
    }

    /// Para frases: «octubre» o «el ciclo 25 oct. – 24 nov. 2026».
    var nombreMes: String {
        esMesCalendario ? Formato.nombreMes(inicio()) : "el ciclo \(Formato.rangoCiclo(ciclo()))"
    }

    /// «mes» o «ciclo», para frases como «Llevas el 82 % de tu presupuesto del mes».
    var unidad: String { esMesCalendario ? "mes" : "ciclo" }
}
