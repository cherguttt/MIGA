//
//  Presupuesto.swift
//  ControlDeGastos
//
//  CAPA: Persistencia (modelo de datos) — entidad Presupuesto, sección 4.6.4 del portafolio.
//  Sprint 2 (CU-03 y CU-04).
//
//  Cada fila representa el LÍMITE MENSUAL que el usuario define para UNA categoría en
//  UN mes y año concretos (por ejemplo: Alimentación, octubre de 2026, $130.000).
//
//  Los tres indicadores `alertaXXEnviada` recuerdan qué alertas ya se enviaron en ese mes,
//  para que el usuario reciba, a lo más, una alerta por umbral y categoría (RF-13).
//
//  REGLA: existe a lo más un presupuesto por categoría, mes y año. SwiftData no permite
//  declarar una restricción única de varias columnas en iOS 17, por eso la regla se
//  verifica en la Capa de Lógica (ServicioPresupuestos), tal como indica el portafolio.
//

import Foundation
import SwiftData

@Model  // Convierte la clase en la tabla ZPRESUPUESTO de la base de datos SQLite.
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
    /// Es una propiedad CALCULADA: no crea una columna en la base de datos.
    var periodo: PeriodoMensual { PeriodoMensual(mes: mes, anio: anio) }
}
