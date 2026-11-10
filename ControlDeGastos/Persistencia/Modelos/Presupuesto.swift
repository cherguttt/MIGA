//
//  Presupuesto.swift
//  ControlDeGastos
//
//  CAPA: Persistencia (modelo de datos) — entidad Presupuesto, sección 4.6.4 del portafolio.
//  Sprint 2 (CU-03 y CU-04).
//

import Foundation
import SwiftData

/// Límite de gasto de una categoría en un ciclo, con los umbrales ya notificados.
@Model
final class Presupuesto {
    /// Identificador único del presupuesto.
    @Attribute(.unique) var id: UUID

    /// Categoría a la que se asigna el límite (una de las ocho de CategoriaGasto).
    var categoria: CategoriaGasto

    /// Mes al que aplica el presupuesto (1 = enero … 12 = diciembre).
    var mes: Int

    /// Año al que aplica el presupuesto (por ejemplo, 2026).
    var anio: Int

    /// Límite de gasto configurado por el usuario, en pesos chilenos.
    var montoMaximo: Decimal

    /// `true` si ya se notificó que el gasto alcanzó el 70 % del límite en este mes.
    var alerta70Enviada: Bool

    /// `true` si ya se notificó el 80 %.
    var alerta80Enviada: Bool

    /// `true` si ya se notificó el 90 %.
    var alerta90Enviada: Bool

    /// Fecha de creación del presupuesto.
    var fechaCreacion: Date

    /// Crea un presupuesto sin umbrales notificados.
    init(
        categoria: CategoriaGasto,
        mes: Int,
        anio: Int,
        montoMaximo: Decimal,
        alerta70Enviada: Bool = false,
        alerta80Enviada: Bool = false,
        alerta90Enviada: Bool = false,
        fechaCreacion: Date = .now
    ) {
        self.id = UUID()
        self.categoria = categoria
        self.mes = mes
        self.anio = anio
        self.montoMaximo = montoMaximo
        self.alerta70Enviada = alerta70Enviada
        self.alerta80Enviada = alerta80Enviada
        self.alerta90Enviada = alerta90Enviada
        self.fechaCreacion = fechaCreacion
    }

    /// Mes y año del presupuesto como un solo valor (ver PeriodoMensual.swift).
    var periodo: PeriodoMensual { PeriodoMensual(mes: mes, anio: anio) }
}
