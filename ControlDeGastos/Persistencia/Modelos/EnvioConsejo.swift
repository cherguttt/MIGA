//
//  EnvioConsejo.swift
//  ControlDeGastos
//
//  CAPA: Persistencia (modelo de datos) — entidad EnvioConsejo, sección 4.6.6 del portafolio.
//  Sprint 5 (CU-07, RF-20 y RF-23).
//

import Foundation
import SwiftData

/// Registro de un consejo enviado al usuario y de su valoración.
@Model
final class EnvioConsejo {
    /// Identificador único del envío.
    @Attribute(.unique) var id: UUID

    /// Fecha y hora de la notificación (puede ser futura si está programada).
    var fechaEnvio: Date

    /// Motivo del envío: semanal o gasto hormiga.
    var motivo: MotivoEnvio

    /// Valoración «¿Te fue útil?»: true = sí, false = no, nil = aún no responde (RF-23).
    var util: Bool?

    /// Solo para el motivo «gasto hormiga»: categoría de gasto donde se detectó el patrón.
    var categoriaGasto: CategoriaGasto?

    /// RELACIÓN N:1 con el consejo enviado (el otro lado es `Consejo.envios`).
    var consejo: Consejo?

    /// Crea el registro de un envío de consejo.
    init(
        consejo: Consejo,
        fechaEnvio: Date,
        motivo: MotivoEnvio,
        categoriaGasto: CategoriaGasto? = nil
    ) {
        self.id = UUID()
        self.consejo = consejo
        self.fechaEnvio = fechaEnvio
        self.motivo = motivo
        self.categoriaGasto = categoriaGasto
        self.util = nil
    }
}

extension EnvioConsejo {
    /// Identificador de la notificación local asociada a este envío.
    var identificadorNotificacion: String { "consejo-\(id.uuidString)" }
}
