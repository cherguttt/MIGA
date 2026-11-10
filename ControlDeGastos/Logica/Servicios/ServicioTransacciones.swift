//
//  ServicioTransacciones.swift
//  ControlDeGastos
//
//  CAPA: Lógica de negocio — registra los gastos validados en la base de datos.
//  Sprint 2: pide al Motor Analítico evaluar los umbrales de alerta (CU-04).
//  Sprint 5: revisa si los gastos pequeños forman un patrón de gasto hormiga (CU-07).
//

import Foundation
import SwiftData

/// Errores que puede producir el servicio.
enum ErrorTransaccion: LocalizedError {
    case montoInvalido
    case fechaFutura

    /// Texto que se muestra cuando ocurre el error (`error.localizedDescription` lo usa).
    var errorDescription: String? {
        switch self {
        case .montoInvalido: return "El monto debe ser mayor a cero."
        case .fechaFutura: return "La fecha del gasto no puede ser futura."
        }
    }
}

/// Registra, elimina y consulta los gastos (CU-02).
struct ServicioTransacciones {
    /// Contexto de SwiftData con el que se leen y escriben los datos.
    let contexto: ModelContext

    /// Notificador de alertas (Sprint 2).
    var notificador: any Notificador = NotificadorLocal()

    /// Sprint 5: programador de los avisos de consejos (gasto hormiga).
    var programadorConsejos: any ProgramadorConsejos = ProgramadorConsejosLocal()

    /// Registra un gasto y lo guarda en la base de datos (CU-02, paso 6).
    @discardableResult
    func registrarGasto(
        monto: Decimal,
        categoria: CategoriaGasto,
        fecha: Date,
        descripcion: String?,
        origen: OrigenRegistro = .manual,
        ahora: Date = .now
    ) throws -> Transaccion {
        guard monto > 0 else { throw ErrorTransaccion.montoInvalido }
        guard fecha <= ahora.addingTimeInterval(60) else { throw ErrorTransaccion.fechaFutura }

        let textoDescripcion = descripcion?.trimmingCharacters(in: .whitespacesAndNewlines)
        let transaccion = Transaccion(
            monto: monto,
            categoria: categoria,
            fecha: fecha,
            descripcion: (textoDescripcion?.isEmpty ?? true) ? nil : textoDescripcion,
            origen: origen,
            fechaRegistro: ahora
        )
        contexto.insert(transaccion)
        try contexto.save()

        let gestor = GestorAlertas(contexto: contexto, notificador: notificador)
        _ = try? MotorAnalitico(contexto: contexto).gastoRegistrado(categoria: categoria, fecha: fecha, gestor: gestor)

        if monto < MotorAnalitico.montoMaximoHormiga {
            let consejos = ServicioConsejos(contexto: contexto, programador: programadorConsejos)
            _ = try? consejos.evaluarGastoHormiga(categoria: categoria, ahora: ahora)
        }
        return transaccion
    }

    /// Elimina un gasto de la base de datos.
    func eliminar(_ transaccion: Transaccion) throws {
        let categoria = transaccion.categoria
        let periodo = PeriodoMensual(transaccion.fecha)
        contexto.delete(transaccion)
        try contexto.save()
        try? MotorAnalitico(contexto: contexto).sincronizarIndicadores(categoria: categoria, periodo: periodo)
    }

    /// Obtiene los gastos del CICLO que contiene la fecha indicada, del más reciente al más antiguo.
    func gastosDelMes(_ fecha: Date = .now, calendario: Calendar = .current) throws -> [Transaccion] {
        let intervalo = PeriodoMensual(fecha, calendario: calendario).intervalo(calendario)
        let inicio = intervalo.start
        let fin = intervalo.end

        let descriptor = FetchDescriptor<Transaccion>(
            predicate: #Predicate { $0.fecha >= inicio && $0.fecha < fin },
            sortBy: [SortDescriptor(\.fecha, order: .reverse)]
        )
        return try contexto.fetch(descriptor)
    }
}
