//
//  GestorAlertas.swift
//  ControlDeGastos
//
//  CAPA: Lógica de negocio — Gestor de Alertas (sección 4.4.2 del portafolio).
//  Sprint 2: CU-04 «Evaluar umbral y notificar», RF-10 a RF-13.
//
//  ¿QUÉ HACE?
//  Recibe el gasto acumulado REAL de una categoría y su presupuesto del mes, calcula el
//  avance (acumulado / monto máximo) y, si se alcanzó un umbral (70 %, 80 % o 90 %) que
//  todavía no se había notificado, pide enviar una notificación local y marca el umbral.
//
//  Corresponde a los pasos 7 a 10 del diagrama de secuencia de la Figura 4.
//

import Foundation
import SwiftData

// MARK: - Umbrales

/// Los tres umbrales de alerta. El `rawValue` es el porcentaje.
/// `Comparable` permite escribir `.setenta < .noventa`.
enum UmbralAlerta: Int, CaseIterable, Comparable {
    case setenta = 70
    case ochenta = 80
    case noventa = 90

    /// Requisito de `Comparable`: un umbral es «menor» si su porcentaje es menor.
    static func < (a: UmbralAlerta, b: UmbralAlerta) -> Bool { a.rawValue < b.rawValue }
}

// MARK: - Alerta

/// Datos de una alerta lista para enviarse. Es independiente de iOS: así se puede
/// probar con XCTest sin enviar notificaciones reales.
struct AlertaPresupuesto: Equatable {
    let categoria: CategoriaGasto
    let umbral: UmbralAlerta
    let acumulado: Decimal
    let montoMaximo: Decimal
    let periodo: PeriodoMensual

    /// Título, por ejemplo: «Alimentación alcanzó el 80 %» (mockup P9 del portafolio).
    var titulo: String { "\(categoria.nombre) alcanzó el \(umbral.rawValue) %" }

    /// Subtítulo que identifica el tipo de aviso.
    var subtitulo: String { "Alerta de presupuesto" }

    /// Cuerpo, por ejemplo: «Llevas $104.000 de $130.000 este mes.» (o «este ciclo», si el
    /// usuario eligió otro día de inicio). Si el gasto es de otro ciclo (se registró tarde),
    /// se nombra: «en octubre» o «en el ciclo 25 sept. – 24 oct. 2026».
    func cuerpo(ahora: Date = .now) -> String {
        let cuando = periodo == PeriodoMensual(ahora) ? "este \(periodo.unidad)" : "en \(periodo.nombreMes)"
        return "Llevas \(Formato.pesos(acumulado)) de \(Formato.pesos(montoMaximo)) \(cuando)."
    }

    /// Identificador único de la notificación (categoría + mes + umbral).
    var identificador: String { "alerta-\(categoria.rawValue)-\(periodo.anio)-\(periodo.mes)-\(umbral.rawValue)" }
}

// MARK: - Envío de notificaciones (protocolo)

/// PROTOCOLO: describe QUÉ debe saber hacer un notificador, sin decir CÓMO.
/// - En la app se usa `NotificadorLocal` (ServicioNotificaciones.swift), que habla con iOS.
/// - En las pruebas se usa un notificador simulado que solo guarda las alertas en una lista.
/// Esta técnica se llama «inyección de dependencias» y hace el código fácil de probar.
protocol Notificador {
    func enviar(_ alerta: AlertaPresupuesto)
}

// MARK: - Indicadores del presupuesto

/// EXTENSIÓN de Presupuesto con la lógica de sus indicadores. Se escribe aquí (capa de
/// lógica) para que el modelo de datos quede limpio.
extension Presupuesto {

    /// ¿Ya se notificó este umbral en el mes?
    func yaNotificado(_ umbral: UmbralAlerta) -> Bool {
        switch umbral {
        case .setenta: return alerta70Enviada
        case .ochenta: return alerta80Enviada
        case .noventa: return alerta90Enviada
        }
    }

    /// Cambia el indicador de un umbral.
    func marcar(_ umbral: UmbralAlerta, enviado: Bool) {
        switch umbral {
        case .setenta: alerta70Enviada = enviado
        case .ochenta: alerta80Enviada = enviado
        case .noventa: alerta90Enviada = enviado
        }
    }
}

// MARK: - Gestor de Alertas

struct GestorAlertas {
    let contexto: ModelContext
    /// Por defecto se usa el notificador real de iOS; las pruebas entregan uno simulado.
    var notificador: any Notificador = NotificadorLocal()

    /// Mayor umbral alcanzado por un avance, o `nil` si no se alcanza ninguno.
    ///
    /// Para evitar errores de redondeo NO dividimos: en vez de preguntar
    /// «¿acumulado / monto ≥ 0,70?» preguntamos «¿acumulado × 100 ≥ monto × 70?»,
    /// que es equivalente y exacto con `Decimal`.
    static func umbralAlcanzado(acumulado: Decimal, montoMaximo: Decimal) -> UmbralAlerta? {
        guard montoMaximo > 0 else { return nil }
        // Recorremos de mayor a menor (90, 80, 70) y devolvemos el primero que se cumple.
        for umbral in UmbralAlerta.allCases.reversed()
        where acumulado * 100 >= montoMaximo * Decimal(umbral.rawValue) {
            return umbral
        }
        return nil
    }

    /// CU-04, pasos 4 a 6: evalúa el avance y, si corresponde, notifica.
    /// - Returns: la alerta enviada, o `nil` si no se envió ninguna.
    @discardableResult
    func evaluar(acumulado: Decimal, presupuesto: Presupuesto, notificacionesActivas: Bool) throws -> AlertaPresupuesto? {
        // Paso 4: mayor umbral alcanzado. Si no se alcanzó ninguno, no hay nada que hacer.
        guard let umbral = Self.umbralAlcanzado(acumulado: acumulado, montoMaximo: presupuesto.montoMaximo) else {
            return nil
        }
        // Paso 5: solo si ese umbral NO se notificó antes en el mes (RF-13).
        guard !presupuesto.yaNotificado(umbral) else { return nil }
        // Flujo alternativo: si el usuario no autorizó las notificaciones, no se envía nada.
        // Tampoco se marca el umbral, para poder avisar si el usuario las activa más tarde.
        guard notificacionesActivas else { return nil }

        let alerta = AlertaPresupuesto(
            categoria: presupuesto.categoria,
            umbral: umbral,
            acumulado: acumulado,
            montoMaximo: presupuesto.montoMaximo,
            periodo: presupuesto.periodo
        )
        notificador.enviar(alerta)

        // Paso 6: se marca el umbral alcanzado Y los inferiores. Si el gasto salta del
        // 50 % al 95 %, se envía solo la alerta del 90 % y no llegan después las del 70 y 80 %.
        for otro in UmbralAlerta.allCases where otro <= umbral {
            presupuesto.marcar(otro, enviado: true)
        }
        try contexto.save()
        return alerta
    }

    /// CU-03, flujo alternativo: si el gasto acumulado quedó BAJO un umbral ya notificado
    /// (porque se subió el límite o se eliminó un gasto), se restablece su indicador para
    /// permitir una nueva alerta. Los umbrales que siguen alcanzados no se tocan.
    static func restablecer(_ presupuesto: Presupuesto, acumulado: Decimal) {
        let alcanzado = umbralAlcanzado(acumulado: acumulado, montoMaximo: presupuesto.montoMaximo)
        for umbral in UmbralAlerta.allCases {
            // `alcanzado == nil` → ningún umbral alcanzado → se restablecen todos.
            if let alcanzado, umbral <= alcanzado { continue }
            presupuesto.marcar(umbral, enviado: false)
        }
    }
}
