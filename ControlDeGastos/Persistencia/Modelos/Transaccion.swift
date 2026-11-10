//
//  Transaccion.swift
//  ControlDeGastos
//
//  CAPA: Persistencia (modelo de datos) — entidad Transaccion, sección 4.6.3 del portafolio.
//
//  Cada objeto Transaccion es UNA FILA en la tabla de gastos de la base de datos SQLite.
//  Representa un gasto ingresado de forma manual o mediante boleta.
//

import Foundation
import SwiftData

@Model  // Macro que convierte la clase en una tabla de la base de datos (ver PerfilUsuario.swift).
final class Transaccion {

    /// Identificador único del gasto (no se repite entre filas).
    @Attribute(.unique) var id: UUID

    /// Monto del gasto en pesos chilenos. `Decimal` evita errores de redondeo con dinero.
    var monto: Decimal

    /// Categoría del gasto. Su tipo es el enum `CategoriaGasto` (ver Enumeraciones.swift),
    /// así que solo puede tomar uno de los ocho valores definidos.
    var categoria: CategoriaGasto

    /// Fecha y hora en que ocurrió el gasto. `Date` guarda ambas cosas juntas.
    var fecha: Date

    /// Descripción opcional (`?`): puede ser un texto o `nil` si el usuario no escribió nada.
    var descripcion: String?

    /// Forma de ingreso: manual o boleta (OCR, Sprint 4).
    var origen: OrigenRegistro

    /// Fecha y hora en que el registro se guardó en el dispositivo
    /// (puede diferir de `fecha` si el usuario registra un gasto de ayer).
    var fechaRegistro: Date

    /// Inicializador: crea un gasto nuevo. `descripcion`, `origen` y `fechaRegistro`
    /// tienen valores por defecto, por lo que son opcionales al llamar.
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
