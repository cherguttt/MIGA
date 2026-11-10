//
//  Formato.swift
//  ControlDeGastos
//
//  CAPA: Utilidades — funciones de formato para montos en pesos chilenos y fechas.
//  Se usan desde varias capas (vistas, view models, validador), por eso viven aparte.
//

import Foundation

/// Formato de montos en pesos chilenos y de fechas.
enum Formato {
    /// Configuración regional de Chile: punto para miles, coma para decimales, nombres en español.
    private static let localeChile = Locale(identifier: "es_CL")

    /// Formatea un monto como moneda chilena, por ejemplo: $12.500 El `_` antes de `monto` significa que al
    /// llamar NO se escribe la etiqueta: `Formato.pesos(x)` en vez de `Formato.pesos(monto: x)`.
    static func pesos(_ monto: Decimal) -> String {
        monto.formatted(
            .currency(code: "CLP")
            .locale(localeChile)
            .precision(.fractionLength(0))
        )
    }

    /// Agrega separadores de miles a una cadena de dígitos: "12500" → "12.500".
    static func miles(_ digitos: String) -> String {
        let soloDigitos = String(digitos.filter(\.isNumber).drop(while: { $0 == "0" }).prefix(12))

        guard !soloDigitos.isEmpty else { return digitos.contains("0") ? "0" : "" }

        var resultado = ""
        for (indice, caracter) in soloDigitos.reversed().enumerated() {
            if indice > 0 && indice % 3 == 0 { resultado.append(".") }
            resultado.append(caracter)
        }
        return String(resultado.reversed())
    }

    /// Convierte un texto con separadores de miles en un monto: "12.500" → 12500.
    static func monto(desde texto: String) -> Decimal? {
        let digitos = texto.filter(\.isNumber)
        guard !digitos.isEmpty else { return nil }
        return Decimal(string: digitos)
    }

    /// Fecha corta con hora, por ejemplo: 04-10-2026, 14:32
    static func fechaHora(_ fecha: Date) -> String {
        fecha.formatted(
            Date.FormatStyle(date: .numeric, time: .shortened).locale(localeChile)
        )
    }

    /// Nombre del mes abreviado, por ejemplo: «Sept.» (Sprint 2, selector de mes).
    static func mesCorto(_ fecha: Date) -> String {
        capitalizar(fecha.formatted(Date.FormatStyle().month(.abbreviated).locale(localeChile)))
    }

    /// Nombre del mes completo en minúsculas, por ejemplo: «octubre».
    static func nombreMes(_ fecha: Date) -> String {
        fecha.formatted(Date.FormatStyle().month(.wide).locale(localeChile))
    }

    /// Pone en mayúscula solo la primera letra: «octubre de 2026» → «Octubre de 2026».
    static func capitalizar(_ texto: String) -> String {
        texto.prefix(1).uppercased() + texto.dropFirst()
    }

    /// Nombre del mes y año, por ejemplo: octubre de 2026
    static func mesAnio(_ fecha: Date) -> String {
        fecha.formatted(
            Date.FormatStyle().month(.wide).year().locale(localeChile)
        )
    }

    /// Ciclo de gastos: día y mes completo, por ejemplo «24 de noviembre».
    static func diaMesLargo(_ fecha: Date) -> String {
        fecha.formatted(Date.FormatStyle().day().month(.wide).locale(localeChile))
    }

    /// Ciclo de gastos: día y mes abreviado, por ejemplo «25 oct.».
    static func diaMesCorto(_ fecha: Date) -> String {
        fecha.formatted(Date.FormatStyle().day().month(.abbreviated).locale(localeChile))
    }

    /// Ciclo de gastos: rango de fechas, por ejemplo «25 oct. – 24 nov. 2026» o, si cruza de año, «25 dic.
    /// 2026 – 24 ene. 2027».
    static func rangoCiclo(_ ciclo: Ciclo, calendario: Calendar = .current) -> String {
        let ultimoDia = calendario.date(byAdding: .day, value: -1, to: ciclo.fin) ?? ciclo.fin
        let anio = { (fecha: Date) in String(calendario.component(.year, from: fecha)) }
        if anio(ciclo.inicio) == anio(ultimoDia) {
            return "\(diaMesCorto(ciclo.inicio)) – \(diaMesCorto(ultimoDia)) \(anio(ultimoDia))"
        }
        return "\(diaMesCorto(ciclo.inicio)) \(anio(ciclo.inicio)) – \(diaMesCorto(ultimoDia)) \(anio(ultimoDia))"
    }

    /// Sprint 5: día de la semana, día y mes, por ejemplo: «lunes 5 de octubre» (mockup P7).
    static func fechaLarga(_ fecha: Date) -> String {
        fecha.formatted(Date.FormatStyle().weekday(.wide).day().month(.wide).locale(localeChile))
            .replacingOccurrences(of: ",", with: "")
    }

    /// Sprint 5: antigüedad en palabras: «hoy», «ayer» o «hace 7 días» (mockup P6).
    static func haceDias(_ fecha: Date, ahora: Date = .now, calendario: Calendar = .current) -> String {
        let dias = calendario.dateComponents(
            [.day],
            from: calendario.startOfDay(for: fecha),
            to: calendario.startOfDay(for: ahora)
        ).day ?? 0
        switch dias {
        case ..<1: return "hoy"
        case 1: return "ayer"
        default: return "hace \(dias) días"
        }
    }
}

// MARK: - Conversión de Decimal a Double

/// EXTENSIÓN: agrega una propiedad nueva a un tipo que ya existe (aquí, `Decimal` de Apple).
extension Decimal {
    var comoDouble: Double { NSDecimalNumber(decimal: self).doubleValue }
}
