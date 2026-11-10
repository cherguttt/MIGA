//
//  ServicioPresupuestos.swift
//  ControlDeGastos
//
//  CAPA: Lógica de negocio — Servicio de Presupuestos.
//  Sprint 2: CU-03 «Configurar presupuesto por categoría», RF-08.
//
//  Centraliza la lectura y escritura de presupuestos y aplica sus reglas:
//  - el monto máximo debe ser mayor a cero (CU-03, paso 4);
//  - existe a lo más UN presupuesto por categoría, mes y año (sección 4.6.4);
//  - al cambiar un límite se restablecen las alertas que ya no corresponden
//    (CU-03, flujo alternativo).
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

struct ServicioPresupuestos {
    let contexto: ModelContext

    /// Presupuestos de un mes, en el orden de las categorías (Alimentación, Transporte…).
    func presupuestos(de periodo: PeriodoMensual) throws -> [Presupuesto] {
        // Las constantes locales se «capturan» dentro de #Predicate.
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
    /// Si ya existe un presupuesto para esa categoría y mes, se ACTUALIZA (no se duplica).
    @discardableResult
    func guardar(montoMaximo: Decimal, categoria: CategoriaGasto, periodo: PeriodoMensual) throws -> Presupuesto {
        guard montoMaximo > 0 else { throw ErrorPresupuesto.montoInvalido }

        // Ojo: la variable se llama `resultado` y no `presupuesto`, porque este servicio ya tiene
        // una FUNCIÓN llamada `presupuesto(...)`; usar el mismo nombre confundiría al compilador.
        let resultado: Presupuesto
        if let existente = try presupuesto(categoria: categoria, periodo: periodo) {
            existente.montoMaximo = montoMaximo
            resultado = existente
        } else {
            resultado = Presupuesto(categoria: categoria, mes: periodo.mes, anio: periodo.anio, montoMaximo: montoMaximo)
            contexto.insert(resultado)
        }

        // CU-03, flujo alternativo: con el nuevo límite, ¿el gasto quedó bajo algún umbral ya notificado?
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
    /// Evita que el usuario tenga que escribir todos sus límites cada mes.
    /// - Returns: cuántos presupuestos se copiaron.
    @discardableResult
    func copiarDelMesAnterior(a periodo: PeriodoMensual) throws -> Int {
        var copiados = 0
        for anterior in try presupuestos(de: periodo.anterior) {
            // Si la categoría ya tiene límite en este mes, se respeta y se pasa a la siguiente.
            if try presupuesto(categoria: anterior.categoria, periodo: periodo) != nil { continue }
            contexto.insert(Presupuesto(
                categoria: anterior.categoria,
                mes: periodo.mes,
                anio: periodo.anio,
                montoMaximo: anterior.montoMaximo   // Los indicadores de alerta parten en `false`.
            ))
            copiados += 1
        }
        try contexto.save()
        return copiados
    }
}
