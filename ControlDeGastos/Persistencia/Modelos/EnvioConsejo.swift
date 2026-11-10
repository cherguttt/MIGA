//
//  EnvioConsejo.swift
//  ControlDeGastos
//
//  CAPA: Persistencia (modelo de datos) — entidad EnvioConsejo, sección 4.6.6 del portafolio.
//  Sprint 5 (CU-07, RF-20 y RF-23).
//
//  Cada fila registra UN consejo enviado al usuario: cuándo, por qué motivo y si le fue útil.
//  Sirve para el historial «Recibidos recientemente» y para saber cuál es el siguiente
//  consejo de la secuencia semanal.
//
//  Los consejos semanales se registran al PROGRAMARLOS, con la fecha futura en que iOS
//  mostrará la notificación (lunes a las 9:00). Por eso la pestaña Educación solo muestra
//  los envíos con `fechaEnvio` menor o igual a la fecha actual.
//

import Foundation
import SwiftData

@Model  // Tabla ZENVIOCONSEJO de la base de datos SQLite.
final class EnvioConsejo {

    /// Identificador único del envío. También forma el identificador de la notificación.
    @Attribute(.unique) var id: UUID

    /// Fecha y hora de la notificación (puede ser futura si está programada).
    var fechaEnvio: Date

    /// Motivo del envío: semanal o gasto hormiga.
    var motivo: MotivoEnvio

    /// Valoración «¿Te fue útil?»: true = sí, false = no, nil = aún no responde (RF-23).
    var util: Bool?

    /// Solo para el motivo «gasto hormiga»: categoría de gasto donde se detectó el patrón.
    /// Permite enviar a lo más un aviso por categoría cada siete días.
    var categoriaGasto: CategoriaGasto?

    /// RELACIÓN N:1 con el consejo enviado (el otro lado es `Consejo.envios`).
    var consejo: Consejo?

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
