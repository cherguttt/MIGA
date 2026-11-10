//
//  GestorAlertas.swift
//  ControlDeGastos
//
//  CAPA: Lógica de negocio — Gestor de Alertas (sección 4.4.2 del portafolio).
//  Sprint 2: CU-04 «Evaluar umbral y notificar», RF-10 a RF-13.
//

import Foundation
import SwiftData

// MARK: - Umbrales

/// Los tres umbrales de alerta.
enum UmbralAlerta: Int, CaseIterable, Comparable {
    case setenta = 70
    case ochenta = 80
    case noventa = 90

    /// Requisito de `Comparable`: un umbral es «menor» si su porcentaje es menor.
    static func < (a: UmbralAlerta, b: UmbralAlerta) -> Bool { a.rawValue < b.rawValue }
}

// MARK: - Alerta

/// Datos de una alerta lista para enviarse.
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

    /// Cuerpo, por ejemplo: «Llevas $104.000 de $130.000 este mes.» (o «este ciclo», si el usuario eligió
    /// otro día de inicio).
    func cuerpo(ahora: Date = .now) -> String {
        let cuando = periodo == PeriodoMensual(ahora) ? "este \(periodo.unidad)" : "en \(periodo.nombreMes)"
        return "Llevas \(Formato.pesos(acumulado)) de \(Formato.pesos(montoMaximo)) \(cuando)."
    }

    /// Identificador único de la notificación (categoría + mes + umbral).
    var identificador: String { "alerta-\(categoria.rawValue)-\(periodo.anio)-\(periodo.mes)-\(umbral.rawValue)" }
}

// MARK: - Envío de notificaciones (protocolo)

/// PROTOCOLO: describe QUÉ debe saber hacer un notificador, sin decir CÓMO.
protocol Notificador {
    /// Entrega una alerta de presupuesto al usuario.
    func enviar(_ alerta: AlertaPresupuesto)
}

// MARK: - Indicadores del presupuesto

/// EXTENSIÓN de Presupuesto con la lógica de sus indicadores.
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

/// Decide si un gasto alcanzó un umbral (70, 80 o 90 %) no notificado y envía la alerta (CU-04).
struct GestorAlertas {
    let contexto: ModelContext
    /// Por defecto se usa el notificador real de iOS; las pruebas entregan uno simulado.
    var notificador: any Notificador = NotificadorLocal()

    /// Mayor umbral alcanzado por un avance, o `nil` si no se alcanza ninguno.
    static func umbralAlcanzado(acumulado: Decimal, montoMaximo: Decimal) -> UmbralAlerta? {
        guard montoMaximo > 0 else { return nil }
        for umbral in UmbralAlerta.allCases.reversed()
        where acumulado * 100 >= montoMaximo * Decimal(umbral.rawValue) {
            return umbral
        }
        return nil
    }

    /// CU-04, pasos 4 a 6: evalúa el avance y, si corresponde, notifica.
    @discardableResult
    func evaluar(acumulado: Decimal, presupuesto: Presupuesto, notificacionesActivas: Bool) throws -> AlertaPresupuesto? {
        guard let umbral = Self.umbralAlcanzado(acumulado: acumulado, montoMaximo: presupuesto.montoMaximo) else {
            return nil
        }
        guard !presupuesto.yaNotificado(umbral) else { return nil }
        guard notificacionesActivas else { return nil }

        let alerta = AlertaPresupuesto(
            categoria: presupuesto.categoria,
            umbral: umbral,
            acumulado: acumulado,
            montoMaximo: presupuesto.montoMaximo,
            periodo: presupuesto.periodo
        )
        notificador.enviar(alerta)

        for otro in UmbralAlerta.allCases where otro <= umbral {
            presupuesto.marcar(otro, enviado: true)
        }
        try contexto.save()
        return alerta
    }

    /// CU-03, flujo alternativo: si el gasto acumulado quedó BAJO un umbral ya notificado (porque se subió el
    /// límite o se eliminó un gasto), se restablece su indicador para permitir una nueva alerta.
    static func restablecer(_ presupuesto: Presupuesto, acumulado: Decimal) {
        let alcanzado = umbralAlcanzado(acumulado: acumulado, montoMaximo: presupuesto.montoMaximo)
        for umbral in UmbralAlerta.allCases {
            if let alcanzado, umbral <= alcanzado { continue }
            presupuesto.marcar(umbral, enviado: false)
        }
    }
}
