//
//  NotificadorSimulado.swift
//  ControlDeGastosTests
//
//  «Doble de prueba» del notificador: en vez de enviar notificaciones reales a iOS,
//  guarda las alertas en una lista para que las pruebas puedan revisarlas.
//  Es posible gracias al protocolo `Notificador` (inyección de dependencias).
//

import Foundation
@testable import ControlDeGastos

@MainActor
final class NotificadorSimulado: Notificador {
    /// Alertas «enviadas», en orden.
    private(set) var enviadas: [AlertaPresupuesto] = []

    func enviar(_ alerta: AlertaPresupuesto) {
        enviadas.append(alerta)
    }
}

/// Sprint 5: «doble de prueba» del programador de consejos. Guarda los avisos programados
/// y los identificadores cancelados, sin tocar el centro de notificaciones de iOS.
@MainActor
final class ProgramadorConsejosSimulado: ProgramadorConsejos {
    private(set) var programados: [AvisoConsejo] = []
    private(set) var cancelados: [String] = []

    func programar(_ aviso: AvisoConsejo) { programados.append(aviso) }
    func cancelar(identificadores: [String]) { cancelados.append(contentsOf: identificadores) }
}
