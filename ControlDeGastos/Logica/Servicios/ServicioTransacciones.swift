//
//  ServicioTransacciones.swift
//  ControlDeGastos
//
//  CAPA: Lógica de negocio — registra los gastos validados en la base de datos.
//  Sprint 2: pide al Motor Analítico evaluar los umbrales de alerta (CU-04).
//  Sprint 5: revisa si los gastos pequeños forman un patrón de gasto hormiga (CU-07).
//
//  ¿POR QUÉ UN «SERVICIO»?
//  Las vistas no deberían hablar directamente con la base de datos. Centralizar aquí las
//  operaciones (registrar, eliminar, consultar) hace el código más ordenado y fácil de probar
//  con XCTest, usando un contenedor en memoria.
//

import Foundation
import SwiftData

/// Errores que puede producir el servicio.
/// `LocalizedError` es un protocolo que permite dar un mensaje legible para el usuario.
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

struct ServicioTransacciones {
    /// Contexto de SwiftData con el que se leen y escriben los datos.
    /// Se recibe desde afuera («inyección de dependencias»): la vista entrega el suyo
    /// y las pruebas pueden entregar uno en memoria.
    let contexto: ModelContext

    /// Notificador de alertas (Sprint 2). Tiene un valor por defecto, así que se puede
    /// seguir creando el servicio como `ServicioTransacciones(contexto: contexto)`.
    /// Las pruebas entregan un notificador simulado para no enviar notificaciones reales.
    var notificador: any Notificador = NotificadorLocal()

    /// Sprint 5: programador de los avisos de consejos (gasto hormiga). Las pruebas entregan
    /// uno simulado, igual que con el notificador de alertas.
    var programadorConsejos: any ProgramadorConsejos = ProgramadorConsejosLocal()

    /// Registra un gasto y lo guarda en la base de datos (CU-02, paso 6).
    /// `@discardableResult`: quien llama puede ignorar el valor devuelto sin que Xcode avise.
    /// `throws`: puede lanzar `ErrorTransaccion` si los datos no son válidos.
    /// `ahora` se recibe como parámetro para poder fijar «la hora actual» en las pruebas.
    @discardableResult
    func registrarGasto(
        monto: Decimal,
        categoria: CategoriaGasto,
        fecha: Date,
        descripcion: String?,
        origen: OrigenRegistro = .manual,
        ahora: Date = .now
    ) throws -> Transaccion {
        // Validaciones de negocio (segunda barrera, además del formulario):
        // `throw` lanza el error y termina la función inmediatamente.
        guard monto > 0 else { throw ErrorTransaccion.montoInvalido }
        // Se tolera 1 minuto de diferencia por si el reloj avanza mientras se llena el formulario.
        guard fecha <= ahora.addingTimeInterval(60) else { throw ErrorTransaccion.fechaFutura }

        // `?.` es el «encadenamiento opcional»: si `descripcion` es nil, el resultado también es nil;
        // si tiene texto, le quitamos los espacios y saltos de línea al inicio y al final.
        let textoDescripcion = descripcion?.trimmingCharacters(in: .whitespacesAndNewlines)
        let transaccion = Transaccion(
            monto: monto,
            categoria: categoria,
            fecha: fecha,
            // Si la descripción quedó vacía (o era nil), guardamos nil en vez de un texto vacío.
            descripcion: (textoDescripcion?.isEmpty ?? true) ? nil : textoDescripcion,
            origen: origen,
            fechaRegistro: ahora
        )
        contexto.insert(transaccion)   // 1. Lo agregamos al contexto (en memoria).
        try contexto.save()            // 2. Lo escribimos en el archivo SQLite.

        // 3. CU-02 paso 7 (Sprint 2): el Motor Analítico evalúa los umbrales de alerta (CU-04).
        //    Se usa `try?`: el gasto YA quedó guardado, así que un problema al evaluar la alerta
        //    no debe hacer fallar el registro.
        let gestor = GestorAlertas(contexto: contexto, notificador: notificador)
        _ = try? MotorAnalitico(contexto: contexto).gastoRegistrado(categoria: categoria, fecha: fecha, gestor: gestor)

        // 4. Sprint 5 (CU-07, paso 3): si el gasto es pequeño, se revisa si forma un patrón
        //    de gasto hormiga en su categoría y, si corresponde, se envía un consejo.
        if monto < MotorAnalitico.montoMaximoHormiga {
            let consejos = ServicioConsejos(contexto: contexto, programador: programadorConsejos)
            _ = try? consejos.evaluarGastoHormiga(categoria: categoria, ahora: ahora)
        }
        return transaccion
    }

    /// Elimina un gasto de la base de datos.
    func eliminar(_ transaccion: Transaccion) throws {
        // Guardamos la categoría y el mes ANTES de borrar: después el objeto ya no existe.
        let categoria = transaccion.categoria
        let periodo = PeriodoMensual(transaccion.fecha)
        contexto.delete(transaccion)
        try contexto.save()
        // Sprint 2: si el gasto acumulado baja de un umbral ya notificado, ese umbral se
        // restablece para poder avisar de nuevo (mismo criterio del CU-03).
        try? MotorAnalitico(contexto: contexto).sincronizarIndicadores(categoria: categoria, periodo: periodo)
    }

    /// Obtiene los gastos del CICLO que contiene la fecha indicada, del más reciente al más antiguo.
    /// Por defecto el ciclo es el mes calendario; si el usuario eligió otro día de inicio, se
    /// usan las fechas de su ciclo (ver CalendarioCiclos.swift).
    func gastosDelMes(_ fecha: Date = .now, calendario: Calendar = .current) throws -> [Transaccion] {
        // Inicio y fin del ciclo de la fecha (el fin es exclusivo).
        let intervalo = PeriodoMensual(fecha, calendario: calendario).intervalo(calendario)
        let inicio = intervalo.start
        let fin = intervalo.end

        // `FetchDescriptor` describe una CONSULTA (equivale a un SELECT de SQL):
        // - `predicate` (filtro, como WHERE): `#Predicate` es una macro que traduce esta condición
        //   de Swift a SQL. `$0` representa cada Transaccion de la tabla.
        // - `sortBy` (orden, como ORDER BY): por fecha, de la más nueva a la más antigua.
        let descriptor = FetchDescriptor<Transaccion>(
            predicate: #Predicate { $0.fecha >= inicio && $0.fecha < fin },
            sortBy: [SortDescriptor(\.fecha, order: .reverse)]
        )
        return try contexto.fetch(descriptor)   // Ejecuta la consulta y devuelve los resultados.
    }
}
