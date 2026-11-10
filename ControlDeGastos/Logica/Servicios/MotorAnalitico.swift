//
//  MotorAnalitico.swift
//  ControlDeGastos
//
//  CAPA: Lógica de negocio — Motor Analítico (sección 4.4.2.1 del portafolio).
//
//  El portafolio define tres «pipelines» (procesos de cálculo):
//    1. Alertas por umbral (CU-04) ............ Sprint 2  ← este archivo
//    2. Proyección al cierre del mes (CU-05) .. Sprint 3  ← este archivo
//    3. Detección de gasto hormiga (CU-07) .... Sprint 5  ← este archivo
//
//  Pipeline 1: calcula el GASTO ACUMULADO REAL de una categoría en un mes y coordina la
//  evaluación de umbrales (pasos 1 a 7 del diagrama de secuencia de la Figura 4).
//  Pipeline 2: calcula el RESUMEN MENSUAL del panel de Inicio: velocidad diaria de gasto,
//  proyección al cierre y avance por categoría (diagrama de secuencia de la Figura 5).
//  Los valores calculados NO se guardan: se calculan cada vez desde las transacciones,
//  lo que evita inconsistencias (sección 4.4.5).
//

import Foundation
import SwiftData

struct MotorAnalitico {
    let contexto: ModelContext
    var calendario: Calendar = .current
    /// Calendario de ciclos de gasto. Si es nil, se usa el de la app (CalendarioCiclos.compartido).
    var ciclos: CalendarioCiclos? = nil

    /// Ciclos efectivos con el calendario de este motor.
    private var ciclosEfectivos: CalendarioCiclos { (ciclos ?? .compartido).con(calendario) }

    /// Transacciones de un mes (todas las categorías).
    func transacciones(de periodo: PeriodoMensual) throws -> [Transaccion] {
        let intervalo = periodo.ciclo(ciclosEfectivos).intervalo   // Fechas reales del ciclo.
        let inicio = intervalo.start
        let fin = intervalo.end
        // Consulta tipada: equivale a SELECT * FROM ZTRANSACCION WHERE fecha >= inicio AND fecha < fin.
        let descriptor = FetchDescriptor<Transaccion>(
            predicate: #Predicate { $0.fecha >= inicio && $0.fecha < fin }
        )
        return try contexto.fetch(descriptor)
    }

    /// Suma los montos de una categoría dentro de una lista de transacciones.
    /// Es una función «pura» y `static`: no usa la base de datos, por eso es fácil de probar.
    /// Nota: el filtro por categoría se hace en Swift y no en `#Predicate`, porque en iOS 17
    /// SwiftData no siempre permite comparar enumeraciones dentro de una consulta.
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
    /// Ejemplo: 106.600 de 130.000 → 82. Se trunca para no mostrar «70 %» cuando es 69,6 %.
    /// Devuelve `nil` si el total es cero (no se puede dividir por cero).
    static func porcentaje(_ parte: Decimal, de total: Decimal) -> Int? {
        guard total > 0 else { return nil }
        var valor = parte * 100 / total
        var truncado = Decimal()
        NSDecimalRound(&truncado, &valor, 0, .down)   // Función de Apple para redondear Decimal.
        return NSDecimalNumber(decimal: truncado).intValue
    }

    /// CU-04 completo: se llama cada vez que se registra un gasto (paso 7 del CU-02).
    /// 1. Calcula el gasto acumulado de la categoría en el mes del gasto.
    /// 2. Busca el presupuesto de esa categoría y mes. Si no hay, termina.
    /// 3. Entrega ambos datos al Gestor de Alertas, que decide si notificar.
    @discardableResult
    func gastoRegistrado(categoria: CategoriaGasto, fecha: Date, gestor: GestorAlertas) throws -> AlertaPresupuesto? {
        let periodo = PeriodoMensual(fecha, ciclos: ciclosEfectivos)   // Ciclo del gasto.
        let acumulado = try gastoAcumulado(categoria: categoria, periodo: periodo)
        guard let presupuesto = try ServicioPresupuestos(contexto: contexto)
            .presupuesto(categoria: categoria, periodo: periodo) else {
            return nil   // Precondición del CU-04: la categoría debe tener presupuesto ese mes.
        }
        // Si no hay perfil (solo ocurre en pruebas), se asume que las notificaciones están activas.
        let perfil = try contexto.fetch(FetchDescriptor<PerfilUsuario>()).first
        return try gestor.evaluar(
            acumulado: acumulado,
            presupuesto: presupuesto,
            notificacionesActivas: perfil?.notificacionesActivas ?? true
        )
    }

    /// Vuelve a calcular los indicadores de alerta de una categoría y mes.
    /// Se usa al eliminar un gasto: si el acumulado baja de un umbral, ese umbral podrá
    /// notificarse otra vez (mismo criterio que el flujo alternativo del CU-03).
    func sincronizarIndicadores(categoria: CategoriaGasto, periodo: PeriodoMensual) throws {
        guard let presupuesto = try ServicioPresupuestos(contexto: contexto)
            .presupuesto(categoria: categoria, periodo: periodo) else { return }
        GestorAlertas.restablecer(presupuesto, acumulado: try gastoAcumulado(categoria: categoria, periodo: periodo))
        try contexto.save()
    }

    // MARK: - Pipeline 2: resumen mensual y proyección (Sprint 3, CU-05)

    /// CU-05, pasos 3 a 7: obtiene las transacciones y presupuestos del mes desde la base
    /// de datos y calcula el resumen. `ahora` se recibe como parámetro para poder probar
    /// la función con fechas fijas (por ejemplo, «día 10 de un mes de 30 días»).
    func resumenMensual(_ periodo: PeriodoMensual = PeriodoMensual(), ahora: Date = .now) throws -> ResumenMensual {
        let gastos = try transacciones(de: periodo)
        let limites = try ServicioPresupuestos(contexto: contexto).presupuestos(de: periodo)
        return Self.calcularResumen(transacciones: gastos, presupuestos: limites, periodo: periodo,
                                    ahora: ahora, calendario: calendario, ciclos: ciclosEfectivos)
    }

    /// Cálculo PURO del resumen (no toca la base de datos). Lo usan `resumenMensual`, el
    /// ViewModel de Inicio y las pruebas. Ignora los datos que no sean del período indicado.
    static func calcularResumen(
        transacciones: [Transaccion],
        presupuestos: [Presupuesto],
        periodo: PeriodoMensual,
        ahora: Date = .now,
        calendario: Calendar = .current,
        ciclos: CalendarioCiclos? = nil
    ) -> ResumenMensual {
        // Ciclo de gastos: por defecto el mes calendario; si el usuario eligió otro día de
        // inicio, por ejemplo del 25 de octubre al 24 de noviembre.
        let ciclos = (ciclos ?? .compartido).con(calendario)
        let ciclo = periodo.ciclo(ciclos)
        let delMes = transacciones.filter { $0.fecha >= ciclo.inicio && $0.fecha < ciclo.fin }
        let limites = presupuestos.filter { $0.periodo == periodo }

        /// Número de día dentro del ciclo: el primer día del ciclo es el 1.
        func diaDelCiclo(_ fecha: Date) -> Int {
            (calendario.dateComponents([.day], from: ciclo.inicio, to: calendario.startOfDay(for: fecha)).day ?? 0) + 1
        }

        // Días del ciclo (28 a 31 en un ciclo normal; un ciclo de transición puede ser más corto o largo).
        let diasDelMes = diaDelCiclo(ciclo.fin) - 1

        // Días transcurridos: en el ciclo actual, hasta hoy (el día 18 del ciclo cuenta como 18 días);
        // en un ciclo pasado, el ciclo completo; en un ciclo futuro, cero.
        let actual = PeriodoMensual(ahora, ciclos: ciclos)
        let diasTranscurridos: Int
        if periodo == actual {
            diasTranscurridos = diaDelCiclo(ahora)
        } else if (periodo.anio, periodo.mes) < (actual.anio, actual.mes) {   // Comparación de tuplas.
            diasTranscurridos = diasDelMes
        } else {
            diasTranscurridos = 0
        }

        // Gasto de cada día del ciclo, del 1 al último día transcurrido (los días sin gastos valen 0).
        var porDia = [Int: Decimal]()   // Diccionario: día del ciclo → monto.
        for gasto in delMes {
            porDia[diaDelCiclo(gasto.fecha), default: 0] += gasto.monto
        }
        let gastoPorDia = diasTranscurridos > 0
            ? (1...diasTranscurridos).map { GastoDiario(dia: $0, monto: porDia[$0] ?? 0) }
            : []

        // Avance de cada categoría que tenga gastos o límite en el mes.
        let categorias = CategoriaGasto.allCases.compactMap { categoria -> AvanceCategoria? in
            let gastado = acumulado(de: delMes, categoria: categoria)
            let limite = limites.first { $0.categoria == categoria }?.montoMaximo
            guard gastado > 0 || limite != nil else { return nil }
            return AvanceCategoria(categoria: categoria, gastado: gastado, montoMaximo: limite)
        }
        // Orden del mockup P2: primero las que tienen límite, de mayor a menor avance.
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
    case dentroDelPresupuesto   // P < 90 % del presupuesto total
    case cercaDelLimite         // 90 % ≤ P ≤ 100 %
    case sobreElPresupuesto     // P > 100 %
    case sinPresupuesto         // No hay límites definidos en el mes

    var titulo: String {
        switch self {
        case .dentroDelPresupuesto: return "Dentro del presupuesto"
        case .cercaDelLimite: return "Cerca del límite"
        case .sobreElPresupuesto: return "Sobre el presupuesto"
        case .sinPresupuesto: return "Sin presupuesto definido"
        }
    }
}

/// Resultado del pipeline 2. Los valores derivados (V, P, estado) son propiedades
/// CALCULADAS: no se guardan en la base de datos, se recalculan en cada consulta
/// (nota de la Figura 5 del portafolio).
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

    /// RF-14: velocidad diaria de gasto. V = Gasto_mes / días transcurridos.
    var velocidadDiaria: Decimal {
        diasTranscurridos > 0 ? gastoTotal / Decimal(diasTranscurridos) : 0
    }

    /// RF-15: proyección lineal al cierre del mes. P = V × días del mes.
    var proyeccion: Decimal { velocidadDiaria * Decimal(diasDelMes) }

    /// Porcentaje del presupuesto total ya utilizado (por ejemplo, 57).
    var porcentajeUtilizado: Int? { MotorAnalitico.porcentaje(gastoTotal, de: presupuestoTotal) }

    /// CU-05, paso 6. Se compara sin dividir (P × 100 frente a total × 90) para ser exactos.
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
    ///
    /// Pasos:
    /// 1. Toma los gastos pequeños (< $5.000) de la categoría.
    /// 2. Cuenta los de los últimos 7 días (frecuencia f).
    /// 3. Calcula el promedio semanal de las semanas anteriores (hasta 8).
    /// 4. Si f > 1,5 × promedio, estima Costo_mes = f × monto promedio × 30 / 7.
    /// 5. Si Costo_mes > $20.000, devuelve el patrón; si no, `nil`.
    /// Requiere al menos dos semanas de historial (contadas desde el primer gasto registrado).
    ///
    /// - Parameters:
    ///   - transacciones: gastos del usuario (de cualquier categoría) de las últimas semanas.
    ///   - primerRegistro: fecha del primer gasto que el usuario registró en la app.
    static func detectarGastoHormiga(
        en transacciones: [Transaccion],
        categoria: CategoriaGasto,
        primerRegistro: Date,
        ahora: Date = .now,
        calendario: Calendar = .current
    ) -> PatronGastoHormiga? {
        // `date(byAdding:)` suma (o resta, con números negativos) días a una fecha.
        guard
            let inicioVentana = calendario.date(byAdding: .day, value: -7, to: ahora),
            let haceDosSemanas = calendario.date(byAdding: .day, value: -14, to: ahora),
            primerRegistro <= haceDosSemanas          // Mínimo dos semanas de historial.
        else { return nil }

        // Los pagos de créditos no son gastos hormiga: son compromisos ya adquiridos.
        guard categoria != .pagoCreditos else { return nil }

        // 1. Gastos pequeños de la categoría.
        let pequenos = transacciones.filter { $0.categoria == categoria && $0.monto < montoMaximoHormiga }

        // 2. Frecuencia de la semana actual: (inicioVentana, ahora].
        let semanaActual = pequenos.filter { $0.fecha > inicioVentana && $0.fecha <= ahora }
        let frecuencia = semanaActual.count
        guard frecuencia > 0 else { return nil }

        // 3. Semanas completas de historial antes de la ventana (entre 1 y 8).
        let diasHistorial = calendario.dateComponents([.day], from: primerRegistro, to: inicioVentana).day ?? 0
        let semanas = min(semanasHistorial, max(1, diasHistorial / 7))
        guard let inicioHistorial = calendario.date(byAdding: .day, value: -7 * semanas, to: inicioVentana) else { return nil }
        let anteriores = pequenos.filter { $0.fecha > inicioHistorial && $0.fecha <= inicioVentana }
        let promedio = Double(anteriores.count) / Double(semanas)

        // 4. ¿La frecuencia actual supera 1,5 veces el promedio?
        guard Double(frecuencia) > factorFrecuencia * promedio else { return nil }

        // Costo_mes = f × monto promedio × 30 / 7. Como f × monto promedio es la suma de la
        // semana, se calcula como suma × 30 / 7 y se redondea al peso.
        let suma = semanaActual.reduce(Decimal(0)) { $0 + $1.monto }
        let montoPromedio = suma / Decimal(frecuencia)
        var costo = suma * 30 / 7
        var costoRedondeado = Decimal()
        NSDecimalRound(&costoRedondeado, &costo, 0, .plain)

        // 5. ¿El costo mensual supera los $20.000?
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
