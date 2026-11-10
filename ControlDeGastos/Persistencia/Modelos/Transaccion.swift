//
//  Transaccion.swift
//  ControlDeGastos
//
//  CAPA: Persistencia (modelo de datos) — entidad Transaccion, sección 4.6.3 del portafolio.
//

import Foundation
import SwiftData

/// Gasto registrado por el usuario.
@Model
final class Transaccion {
    /// Identificador único del gasto (no se repite entre filas).
    @Attribute(.unique) var id: UUID

    /// Monto del gasto en pesos chilenos.
    var monto: Decimal

    /// Categoría del gasto.
    var categoria: CategoriaGasto

    /// Fecha y hora en que ocurrió el gasto.
    var fecha: Date

    /// Descripción opcional (`?`): puede ser un texto o `nil` si el usuario no escribió nada.
    var descripcion: String?

    /// Forma de ingreso: manual o boleta (OCR, Sprint 4).
    var origen: OrigenRegistro

    /// Fecha y hora en que el registro se guardó en el dispositivo (puede diferir de `fecha` si el usuario
    /// registra un gasto de ayer).
    var fechaRegistro: Date

    /// Inicializador: crea un gasto nuevo.
    init(
        monto: Decimal,
        categoria: CategoriaGasto,
        fecha: Date,
        descripcion: String? = nil,
        origen: OrigenRegistro = .manual,
        fechaRegistro: Date = .now
    ) {
        self.id = UUID()
        self.monto = monto
        self.categoria = categoria
        self.fecha = fecha
        self.descripcion = descripcion
        self.origen = origen
        self.fechaRegistro = fechaRegistro
    }
}
