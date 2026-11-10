//
//  ServicioPresupuestos.swift
//  ControlDeGastos
//
//  CAPA: Lógica de negocio — Servicio de Presupuestos.
//  Sprint 2: CU-03 «Configurar presupuesto por categoría», RF-08.
//

import Foundation
import SwiftData

/// Errores del servicio, con su mensaje para el usuario.
enum ErrorPresupuesto: LocalizedError {
    case montoInvalido

    var errorDescription: String? {
        switch self {
        case .montoInvalido: return "El límite debe ser mayor a cero."
        }
    }
}

/// Crea, modifica y copia los presupuestos por categoría (CU-03).
struct ServicioPresupuestos {
    let contexto: ModelContext

    /// Presupuestos de un mes, en el orden de las categorías (Alimentación, Transporte…).
    func presupuestos(de periodo: PeriodoMensual) throws -> [Presupuesto] {
        let mes = periodo.mes
        let anio = periodo.anio
        let descriptor = FetchDescriptor<Presupuesto>(predicate: #Predicate { $0.mes == mes && $0.anio == anio })
        let orden = CategoriaGasto.allCases
        return try contexto.fetch(descriptor).sorted {
            (orden.firstIndex(of: $0.categoria) ?? 0) < (orden.firstIndex(of: $1.categoria) ?? 0)
        }
    }

    /// Presupuesto de una categoría en un mes, o `nil` si no tiene límite definido.
    func presupuesto(categoria: CategoriaGasto, periodo: PeriodoMensual) throws -> Presupuesto? {
        try presupuestos(de: periodo).first { $0.categoria == categoria }
    }

    /// CU-03, pasos 3 y 4: define o modifica el límite de una categoría en un mes.
    @discardableResult
    func guardar(montoMaximo: Decimal, categoria: CategoriaGasto, periodo: PeriodoMensual) throws -> Presupuesto {
        guard montoMaximo > 0 else { throw ErrorPresupuesto.montoInvalido }

        let resultado: Presupuesto
        if let existente = try presupuesto(categoria: categoria, periodo: periodo) {
            existente.montoMaximo = montoMaximo
            resultado = existente
        } else {
            resultado = Presupuesto(categoria: categoria, mes: periodo.mes, anio: periodo.anio, montoMaximo: montoMaximo)
            contexto.insert(resultado)
        }

        let acumulado = try MotorAnalitico(contexto: contexto).gastoAcumulado(categoria: categoria, periodo: periodo)
        GestorAlertas.restablecer(resultado, acumulado: acumulado)

        try contexto.save()
        return resultado
    }

    /// Quita el límite de una categoría en ese mes.
    func eliminar(_ presupuesto: Presupuesto) throws {
        contexto.delete(presupuesto)
        try contexto.save()
    }

    /// Copia al mes indicado los límites del mes anterior, sin reemplazar los que ya existen.
    @discardableResult
    func copiarDelMesAnterior(a periodo: PeriodoMensual) throws -> Int {
        var copiados = 0
        for anterior in try presupuestos(de: periodo.anterior) {
            if try presupuesto(categoria: anterior.categoria, periodo: periodo) != nil { continue }
            contexto.insert(Presupuesto(
                categoria: anterior.categoria,
                mes: periodo.mes,
                anio: periodo.anio,
                montoMaximo: anterior.montoMaximo
            ))
            copiados += 1
        }
        try contexto.save()
        return copiados
    }
}
