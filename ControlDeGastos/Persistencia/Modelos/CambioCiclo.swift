//
//  CambioCiclo.swift
//  ControlDeGastos
//
//  CAPA: Persistencia (modelo de datos) — entidad CambioCiclo.
//  Ciclo de gastos configurable (después del Sprint 5).
//

import Foundation
import SwiftData

/// Registro de un cambio del día de inicio del ciclo de gastos.
@Model
final class CambioCiclo {
    /// Identificador único del cambio.
    @Attribute(.unique) var id: UUID

    /// Nuevo día de inicio del ciclo (1 a 28; así todos los meses lo tienen, incluso febrero).
    var diaInicio: Int

    /// Día en que el usuario hizo el cambio (a las 00:00).
    var fechaCambio: Date

    /// Fecha en que empieza el primer ciclo con el nuevo día (a las 00:00).
    var vigenteDesde: Date

    /// Crea el registro de un cambio de ciclo.
    init(diaInicio: Int, fechaCambio: Date, vigenteDesde: Date) {
        self.id = UUID()
        self.diaInicio = diaInicio
        self.fechaCambio = fechaCambio
        self.vigenteDesde = vigenteDesde
    }
}
