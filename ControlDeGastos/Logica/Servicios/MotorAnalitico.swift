//
//  MotorAnalitico.swift
//  ControlDeGastos
//
//  CAPA: Lógica de negocio — Motor Analítico (sección 4.4.2.1 del portafolio).
//

import Foundation
import SwiftData

/// Calcula el gasto acumulado, la velocidad diaria, la proyección y el gasto hormiga.
struct MotorAnalitico {
    let contexto: ModelContext
    var calendario: Calendar = .current
    /// Calendario de ciclos de gasto.
    var ciclos: CalendarioCiclos? = nil

    /// Ciclos efectivos con el calendario de este motor.
    private var ciclosEfectivos: CalendarioCiclos { (ciclos ?? .compartido).con(calendario) }

    /// Transacciones de un mes (todas las categorías).
    func transacciones(de periodo: PeriodoMensual) throws -> [Transaccion] {
        let intervalo = periodo.ciclo(ciclosEfectivos).intervalo
        let inicio = intervalo.start
        let fin = intervalo.end
        let descriptor = FetchDescriptor<Transaccion>(
            predicate: #Predicate { $0.fecha >= inicio && $0.fecha < fin }
        )
        return try contexto.fetch(descriptor)
    }

    /// Suma los montos de una categoría dentro de una lista de transacciones.
    static func acumulado(de transacciones: [Transaccion], categoria: CategoriaGasto) -> Decimal {
        transacciones
            .filter { $0.categoria == categoria }
            .reduce(0) { $0 + $1.monto }
    }

    /// RF-09: gasto acumulado real de una categoría en un mes (CU-04, pasos 2 a 4).
    func gastoAcumulado(categoria: CategoriaGasto, periodo: PeriodoMensual) throws -> Decimal {
        Self.acumulado(de: try transacciones(de: periodo), categoria: categoria)
    }

    /// Porcentaje entero (truncado hacia abajo) de `parte` respecto de `total`.
    static func porcentaje(_ parte: Decimal, de total: Decimal) -> Int? {
        guard total > 0 else { return nil }
        var valor = parte * 100 / total
        var truncado = Decimal()
        NSDecimalRound(&truncado, &valor, 0, .down)
        return NSDecimalNumber(decimal: truncado).intValue
    }

    /// CU-04 completo: se llama cada vez que se registra un gasto (paso 7 del CU-02). 1.
    @discardableResult
    func gastoRegistrado(categoria: CategoriaGasto, fecha: Date, gestor: GestorAlertas) throws -> AlertaPresupuesto? {
        let periodo = PeriodoMensual(fecha, ciclos: ciclosEfectivos)
        let acumulado = try gastoAcumulado(categoria: categoria, periodo: periodo)
        guard let presupuesto = try ServicioPresupuestos(contexto: contexto)
            .presupuesto(categoria: categoria, periodo: periodo) else {
            return nil
        }
        let perfil = try contexto.fetch(FetchDescriptor<PerfilUsuario>()).first
        return try gestor.evaluar(
            acumulado: acumulado,
            presupuesto: presupuesto,
            notificacionesActivas: perfil?.notificacionesActivas ?? true
        )
    }

    /// Vuelve a calcular los indicadores de alerta de una categoría y mes.
    func sincronizarIndicadores(categoria: CategoriaGasto, periodo: PeriodoMensual) throws {
        guard let presupuesto = try ServicioPresupuestos(contexto: contexto)
            .presupuesto(categoria: categoria, periodo: periodo) else { return }
        GestorAlertas.restablecer(presupuesto, acumulado: try gastoAcumulado(categoria: categoria, periodo: periodo))
        try contexto.save()
    }

    // MARK: - Pipeline 2: resumen mensual y proyección (Sprint 3, CU-05)

    /// CU-05, pasos 3 a 7: obtiene las transacciones y presupuestos del mes desde la base de datos y calcula
    /// el resumen.
    func resumenMensual(_ periodo: PeriodoMensual = PeriodoMensual(), ahora: Date = .now) throws -> ResumenMensual {
        let gastos = try transacciones(de: periodo)
        let limites = try ServicioPresupuestos(contexto: contexto).presupuestos(de: periodo)
        return Self.calcularResumen(transacciones: gastos, presupuestos: limites, periodo: periodo,
                                    ahora: ahora, calendario: calendario, ciclos: ciclosEfectivos)
    }

    /// Cálculo PURO del resumen (no toca la base de datos).
    static func calcularResumen(
        transacciones: [Transaccion],
        presupuestos: [Presupuesto],
        periodo: PeriodoMensual,
        ahora: Date = .now,
        calendario: Calendar = .current,
        ciclos: CalendarioCiclos? = nil
    ) -> ResumenMensual {
        let ciclos = (ciclos ?? .compartido).con(calendario)
        let ciclo = periodo.ciclo(ciclos)
        let delMes = transacciones.filter { $0.fecha >= ciclo.inicio && $0.fecha < ciclo.fin }
        let limites = presupuestos.filter { $0.periodo == periodo }

        /// Número de día dentro del ciclo: el primer día del ciclo es el 1.
        func diaDelCiclo(_ fecha: Date) -> Int {
            (calendario.dateComponents([.day], from: ciclo.inicio, to: calendario.startOfDay(for: fecha)).day ?? 0) + 1
        }

        let diasDelMes = diaDelCiclo(ciclo.fin) - 1

        let actual = PeriodoMensual(ahora, ciclos: ciclos)
        let diasTranscurridos: Int
        if periodo == actual {
            diasTranscurridos = diaDelCiclo(ahora)
        } else if (periodo.anio, periodo.mes) < (actual.anio, actual.mes) {
            diasTranscurridos = diasDelMes
        } else {
            diasTranscurridos = 0
        }

        var porDia = [Int: Decimal]()
        for gasto in delMes {
            porDia[diaDelCiclo(gasto.fecha), default: 0] += gasto.monto
        }
        let gastoPorDia = diasTranscurridos > 0
            ? (1...diasTranscurridos).map { GastoDiario(dia: $0, monto: porDia[$0] ?? 0) }
            : []

        let categorias = CategoriaGasto.allCases.compactMap { categoria -> AvanceCategoria? in
            let gastado = acumulado(de: delMes, categoria: categoria)
            let limite = limites.first { $0.categoria == categoria }?.montoMaximo
            guard gastado > 0 || limite != nil else { return nil }
            return AvanceCategoria(categoria: categoria, gastado: gastado, montoMaximo: limite)
        }
        .sorted { a, b in
            switch (a.porcentaje, b.porcentaje) {
            case let (x?, y?): return x > y
            case (.some, .none): return true
            case (.none, .some): return false
            case (.none, .none): return a.gastado > b.gastado
            }
        }

        return ResumenMensual(
            periodo: periodo,
            gastoTotal: delMes.reduce(0) { $0 + $1.monto },
            presupuestoTotal: limites.reduce(0) { $0 + $1.montoMaximo },
            cantidadGastos: delMes.count,
            diasDelMes: diasDelMes,
            diasTranscurridos: diasTranscurridos,
            gastoPorDia: gastoPorDia,
            categorias: categorias
        )
    }
}

// MARK: - Tipos del resumen mensual (Sprint 3)

/// Gasto total de un día del mes (una barra del gráfico de Inicio).
struct GastoDiario: Identifiable, Equatable {
    let dia: Int
    let monto: Decimal
    var id: Int { dia }
}

/// Avance de una categoría en el mes: lo gastado frente a su límite (si tiene).
struct AvanceCategoria: Identifiable, Equatable {
    let categoria: CategoriaGasto
    let gastado: Decimal
    let montoMaximo: Decimal?
    var id: String { categoria.id }

    /// Porcentaje entero del límite ya gastado, o `nil` si no tiene límite.
    var porcentaje: Int? { montoMaximo.flatMap { MotorAnalitico.porcentaje(gastado, de: $0) } }
}

/// Clasificación de la proyección frente al presupuesto total (CU-05, paso 6).
enum EstadoProyeccion: Equatable {
    case dentroDelPresupuesto
    case cercaDelLimite
    case sobreElPresupuesto
    case sinPresupuesto

    var titulo: String {
        switch self {
        case .dentroDelPresupuesto: return "Dentro del presupuesto"
        case .cercaDelLimite: return "Cerca del límite"
        case .sobreElPresupuesto: return "Sobre el presupuesto"
        case .sinPresupuesto: return "Sin presupuesto definido"
        }
    }
}

/// Resultado del pipeline 2.
struct ResumenMensual: Equatable {
    let periodo: PeriodoMensual
    /// Gasto acumulado del mes (todas las categorías).
    let gastoTotal: Decimal
    /// Suma de los límites del mes.
    let presupuestoTotal: Decimal
    let cantidadGastos: Int
    let diasDelMes: Int
    let diasTranscurridos: Int
    let gastoPorDia: [GastoDiario]
    let categorias: [AvanceCategoria]

    /// RF-14: velocidad diaria de gasto.
    var velocidadDiaria: Decimal {
        diasTranscurridos > 0 ? gastoTotal / Decimal(diasTranscurridos) : 0
    }

    /// RF-15: proyección lineal al cierre del mes.
    var proyeccion: Decimal { velocidadDiaria * Decimal(diasDelMes) }

    /// Porcentaje del presupuesto total ya utilizado (por ejemplo, 57).
    var porcentajeUtilizado: Int? { MotorAnalitico.porcentaje(gastoTotal, de: presupuestoTotal) }

    /// CU-05, paso 6.
    var estado: EstadoProyeccion {
        guard presupuestoTotal > 0 else { return .sinPresupuesto }
        if proyeccion * 100 < presupuestoTotal * 90 { return .dentroDelPresupuesto }
        if proyeccion <= presupuestoTotal { return .cercaDelLimite }
        return .sobreElPresupuesto
    }
}

// MARK: - Pipeline 3: detección de gasto hormiga (Sprint 5, CU-07, RF-22)

/// Patrón de gasto hormiga detectado en una categoría.
struct PatronGastoHormiga: Equatable {
    let categoria: CategoriaGasto
    /// f: cantidad de gastos pequeños en los últimos 7 días.
    let frecuencia: Int
    /// Promedio semanal de gastos pequeños en las semanas anteriores (hasta 8).
    let promedioHistorico: Double
    /// Monto promedio de los gastos pequeños de la semana.
    let montoPromedio: Decimal
    /// Costo_mes = f × monto promedio × 30 / 7, redondeado al peso.
    let costoMensual: Decimal
}

extension MotorAnalitico {
    /// Un gasto es «pequeño» si es MENOR a este monto.
    static let montoMaximoHormiga: Decimal = 5_000
    /// Solo se avisa si el costo mensual estimado SUPERA este monto.
    static let costoMinimoAviso: Decimal = 20_000
    /// La frecuencia actual debe superar el promedio histórico multiplicado por este factor.
    static let factorFrecuencia = 1.5
    /// Cantidad máxima de semanas anteriores que se promedian.
    static let semanasHistorial = 8

    /// RF-22: detecta un patrón de gasto hormiga en UNA categoría (sección 4.4.2.1, Pipeline 3).
    static func detectarGastoHormiga(
        en transacciones: [Transaccion],
        categoria: CategoriaGasto,
        primerRegistro: Date,
        ahora: Date = .now,
        calendario: Calendar = .current
    ) -> PatronGastoHormiga? {
        guard
            let inicioVentana = calendario.date(byAdding: .day, value: -7, to: ahora),
            let haceDosSemanas = calendario.date(byAdding: .day, value: -14, to: ahora),
            primerRegistro <= haceDosSemanas
        else { return nil }

        guard categoria != .pagoCreditos else { return nil }

        let pequenos = transacciones.filter { $0.categoria == categoria && $0.monto < montoMaximoHormiga }

        let semanaActual = pequenos.filter { $0.fecha > inicioVentana && $0.fecha <= ahora }
        let frecuencia = semanaActual.count
        guard frecuencia > 0 else { return nil }

        let diasHistorial = calendario.dateComponents([.day], from: primerRegistro, to: inicioVentana).day ?? 0
        let semanas = min(semanasHistorial, max(1, diasHistorial / 7))
        guard let inicioHistorial = calendario.date(byAdding: .day, value: -7 * semanas, to: inicioVentana) else { return nil }
        let anteriores = pequenos.filter { $0.fecha > inicioHistorial && $0.fecha <= inicioVentana }
        let promedio = Double(anteriores.count) / Double(semanas)

        guard Double(frecuencia) > factorFrecuencia * promedio else { return nil }

        let suma = semanaActual.reduce(Decimal(0)) { $0 + $1.monto }
        let montoPromedio = suma / Decimal(frecuencia)
        var costo = suma * 30 / 7
        var costoRedondeado = Decimal()
        NSDecimalRound(&costoRedondeado, &costo, 0, .plain)

        guard costoRedondeado > costoMinimoAviso else { return nil }
        return PatronGastoHormiga(
            categoria: categoria,
            frecuencia: frecuencia,
            promedioHistorico: promedio,
            montoPromedio: montoPromedio,
            costoMensual: costoRedondeado
        )
    }
}
