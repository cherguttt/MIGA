//
//  CambioCiclo.swift
//  ControlDeGastos
//
//  CAPA: Persistencia (modelo de datos) — entidad CambioCiclo.
//  Ciclo de gastos configurable (después del Sprint 5).
//
//  Cada fila registra UN cambio del día de inicio del ciclo de gastos. Guardar el historial
//  (y no solo el día actual) permite que los ciclos pasados sigan siendo exactamente como
//  eran: cambiar el día NUNCA reagrupa los gastos de ciclos anteriores.
//
//  Si la tabla está vacía, los ciclos coinciden con el mes calendario (del 1 al último día),
//  como en los Sprints 1 a 5.
//

import Foundation
import SwiftData

@Model  // Tabla ZCAMBIOCICLO de la base de datos SQLite.
final class CambioCiclo {

    /// Identificador único del cambio.
    @Attribute(.unique) var id: UUID

    /// Nuevo día de inicio del ciclo (1 a 28; así todos los meses lo tienen, incluso febrero).
    var diaInicio: Int

    /// Día en que el usuario hizo el cambio (a las 00:00). El ciclo que estaba en curso ese
    /// día se convierte en el «ciclo de transición».
    var fechaCambio: Date

    /// Fecha en que empieza el primer ciclo con el nuevo día (a las 00:00). El ciclo de
    /// transición termina justo antes de esta fecha.
    var vigenteDesde: Date

    init(diaInicio: Int, fechaCambio: Date, vigenteDesde: Date) {
        self.id = UUID()
        self.diaInicio = diaInicio
        self.fechaCambio = fechaCambio
        self.vigenteDesde = vigenteDesde
    }
}
