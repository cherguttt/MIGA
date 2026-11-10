//
//  PeriodoMensual.swift
//  ControlDeGastos
//
//  CAPA: Utilidades — identifica un CICLO DE GASTO por su mes y año (por ejemplo, octubre de 2026).
//
//  Los presupuestos, las alertas y el panel trabajan siempre «por ciclo». En vez de pasar
//  fechas sueltas y recalcular el ciclo en cada lugar, usamos este tipo pequeño y claro.
//
//  Por defecto el ciclo es el mes calendario (del 1 al último día). Si el usuario elige otro
//  día de inicio (por ejemplo, el 25), las fechas reales del ciclo las calcula
//  CalendarioCiclos.swift; este tipo solo guarda el identificador (mes y año).
//

import Foundation

/// Identificador de un ciclo. Es un `struct` (tipo de valor) y `Hashable`, así que se
/// puede comparar con `==` y usar como clave de diccionarios.
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

    /// Crea el período del ciclo que contiene una fecha. Sin argumentos, es el ciclo actual.
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
    /// Se calcula con aritmética simple: contamos los meses desde el año 0 y volvemos a separarlos.
    /// Ejemplo: diciembre de 2026 + 1 → enero de 2027. Como los ciclos se numeran seguidos,
    /// «+ 1» es siempre el ciclo siguiente, aunque el usuario haya cambiado el día de inicio.
    func desplazado(meses: Int) -> PeriodoMensual {
        let total = anio * 12 + (mes - 1) + meses
        // `/` y `%` con enteros: división entera y resto. Funciona también para totales positivos grandes.
        return PeriodoMensual(mes: total % 12 + 1, anio: total / 12)
    }

    /// Ciclo anterior y ciclo siguiente (propiedades calculadas).
    var anterior: PeriodoMensual { desplazado(meses: -1) }
    var siguiente: PeriodoMensual { desplazado(meses: 1) }

    /// Indica si una fecha cae dentro de este ciclo.
    func contiene(_ fecha: Date, calendario: Calendar = .current) -> Bool {
        let intervalo = intervalo(calendario)
        return fecha >= intervalo.start && fecha < intervalo.end   // [inicio, fin)
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
