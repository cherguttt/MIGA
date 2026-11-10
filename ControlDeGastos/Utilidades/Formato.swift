//
//  Formato.swift
//  ControlDeGastos
//
//  CAPA: Utilidades — funciones de formato para montos en pesos chilenos y fechas.
//  Se usan desde varias capas (vistas, view models, validador), por eso viven aparte.
//

import Foundation

// `enum` sin casos usado como «caja de herramientas» de funciones estáticas.
// Se llaman así: Formato.pesos(12500) → "$12.500".
enum Formato {

    /// Configuración regional de Chile: punto para miles, coma para decimales, nombres en español.
    private static let localeChile = Locale(identifier: "es_CL")

    /// Formatea un monto como moneda chilena, por ejemplo: $12.500
    /// El `_` antes de `monto` significa que al llamar NO se escribe la etiqueta:
    /// `Formato.pesos(x)` en vez de `Formato.pesos(monto: x)`.
    static func pesos(_ monto: Decimal) -> String {
        // Cuando una función tiene una sola expresión, se puede omitir `return`.
        monto.formatted(
            .currency(code: "CLP")             // Formato de moneda en pesos chilenos.
            .locale(localeChile)               // Con las reglas de Chile.
            .precision(.fractionLength(0))     // Sin decimales (el peso no usa centavos).
        )
    }

    /// Agrega separadores de miles a una cadena de dígitos: "12500" → "12.500".
    /// Se usa mientras el usuario escribe el monto.
    static func miles(_ digitos: String) -> String {
        // Encadenamos varias operaciones sobre el texto:
        // 1. `filter(\.isNumber)`: deja solo los caracteres que son números.
        // 2. `drop(while: { $0 == "0" })`: quita los ceros a la izquierda ("007" → "7").
        //    `{ $0 == "0" }` es un CLOSURE (función anónima); `$0` es el carácter que recibe.
        // 3. `prefix(12)`: toma como máximo 12 dígitos para evitar montos absurdos.
        let soloDigitos = String(digitos.filter(\.isNumber).drop(while: { $0 == "0" }).prefix(12))

        // `guard` = «asegúrate de que…; si no, sal de la función».
        // Si no quedaron dígitos: devolvemos "0" si el usuario escribió ceros, o "" si no escribió nada.
        // `condición ? a : b` es el operador ternario: si la condición es verdadera, a; si no, b.
        guard !soloDigitos.isEmpty else { return digitos.contains("0") ? "0" : "" }

        // Recorremos los dígitos de DERECHA a IZQUIERDA y ponemos un punto cada tres.
        var resultado = ""
        for (indice, caracter) in soloDigitos.reversed().enumerated() {
            // `%` es el resto de la división: cada vez que el índice es múltiplo de 3, va un punto.
            if indice > 0 && indice % 3 == 0 { resultado.append(".") }
            resultado.append(caracter)
        }
        // Como construimos el texto al revés, lo damos vuelta al final.
        return String(resultado.reversed())
    }

    /// Convierte un texto con separadores de miles en un monto: "12.500" → 12500.
    /// Devuelve `Decimal?` (opcional): `nil` si el texto no contiene ningún número.
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
    /// `prefix(1)` toma la primera letra y `dropFirst()` el resto del texto.
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

    /// Ciclo de gastos: rango de fechas, por ejemplo «25 oct. – 24 nov. 2026» o, si cruza de
    /// año, «25 dic. 2026 – 24 ene. 2027». El fin del ciclo es exclusivo, así que se muestra
    /// el día anterior.
    static func rangoCiclo(_ ciclo: Ciclo, calendario: Calendar = .current) -> String {
        let ultimoDia = calendario.date(byAdding: .day, value: -1, to: ciclo.fin) ?? ciclo.fin
        let anio = { (fecha: Date) in String(calendario.component(.year, from: fecha)) }
        if anio(ciclo.inicio) == anio(ultimoDia) {
            return "\(diaMesCorto(ciclo.inicio)) – \(diaMesCorto(ultimoDia)) \(anio(ultimoDia))"
        }
        return "\(diaMesCorto(ciclo.inicio)) \(anio(ciclo.inicio)) – \(diaMesCorto(ultimoDia)) \(anio(ultimoDia))"
    }

    /// Sprint 5: día de la semana, día y mes, por ejemplo: «lunes 5 de octubre» (mockup P7).
    /// El formato de Apple escribe «lunes, 5 de octubre»; se quita la coma.
    static func fechaLarga(_ fecha: Date) -> String {
        fecha.formatted(Date.FormatStyle().weekday(.wide).day().month(.wide).locale(localeChile))
            .replacingOccurrences(of: ",", with: "")
    }

    /// Sprint 5: antigüedad en palabras: «hoy», «ayer» o «hace 7 días» (mockup P6).
    /// Compara días del calendario (no horas): algo de anoche a las 23:00 ya es «ayer».
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
/// Los montos se guardan como `Decimal` por exactitud, pero las barras de progreso de SwiftUI
/// necesitan un `Double`. Esta conversión solo se usa para DIBUJAR, nunca para calcular dinero.
extension Decimal {
    var comoDouble: Double { NSDecimalNumber(decimal: self).doubleValue }
}
