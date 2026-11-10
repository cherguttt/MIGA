//
//  ServicioCiclos.swift
//  ControlDeGastos
//
//  CAPA: Lógica de negocio — configuración del ciclo de gastos (después del Sprint 5).
//

import Foundation
import SwiftData

/// Errores al configurar el día de inicio del ciclo de gastos.
enum ErrorCiclo: LocalizedError {
    case diaInvalido
    var errorDescription: String? { "El día de inicio debe estar entre 1 y 28." }
}

/// Guarda los cambios del día de inicio del ciclo de gastos (RF-24).
struct ServicioCiclos {
    let contexto: ModelContext
    var calendario: Calendar = .current
    /// Si es `true`, al cambiar se actualiza el calendario que usa toda la app.
    var actualizarApp = true

    /// Historial de cambios guardado, del más antiguo al más reciente.
    func cambios() throws -> [CambioCiclo] {
        try contexto.fetch(FetchDescriptor<CambioCiclo>(sortBy: [SortDescriptor(\.vigenteDesde)]))
    }

    /// Calendario de ciclos según la base de datos.
    func calendarioCiclos() throws -> CalendarioCiclos {
        CalendarioCiclos(
            calendario: calendario,
            cambios: try cambios().map {
                DatosCambioCiclo(diaInicio: $0.diaInicio, fechaCambio: $0.fechaCambio, vigenteDesde: $0.vigenteDesde)
            }
        )
    }

    /// Carga el calendario en la app (al abrirla y después de cada cambio).
    func cargar() {
        guard actualizarApp, let ciclos = try? calendarioCiclos() else { return }
        CiclosActuales.compartidos.calendario = ciclos
    }

    /// Cómo quedarían los ciclos si se cambia el día `ahora` (para el mensaje de confirmación): el ciclo
    /// actual (que puede ser de transición) y el siguiente.
    func vistaPrevia(diaInicio: Int, ahora: Date = .now) throws -> (actual: Ciclo, siguiente: Ciclo) {
        let nuevo = try calendarioCiclos().cambiando(diaInicio: diaInicio, ahora: ahora)
        let actual = nuevo.ciclo(contiene: ahora)
        return (actual, nuevo.ciclo(clave: actual.clave.siguiente))
    }

    /// Cambia el día de inicio del ciclo de gastos. 1.
    func cambiarDiaInicio(_ dia: Int, ahora: Date = .now) throws {
        guard CalendarioCiclos.diasPermitidos.contains(dia) else { throw ErrorCiclo.diaInvalido }
        let nuevo = try calendarioCiclos().cambiando(diaInicio: dia, ahora: ahora)

        let guardados = try cambios()
        for cambio in guardados {
            let datos = DatosCambioCiclo(diaInicio: cambio.diaInicio, fechaCambio: cambio.fechaCambio, vigenteDesde: cambio.vigenteDesde)
            if !nuevo.cambios.contains(datos) { contexto.delete(cambio) }
        }
        let existentes = guardados.map {
            DatosCambioCiclo(diaInicio: $0.diaInicio, fechaCambio: $0.fechaCambio, vigenteDesde: $0.vigenteDesde)
        }
        for datos in nuevo.cambios where !existentes.contains(datos) {
            contexto.insert(CambioCiclo(diaInicio: datos.diaInicio, fechaCambio: datos.fechaCambio, vigenteDesde: datos.vigenteDesde))
        }
        try contexto.save()

        if actualizarApp { CiclosActuales.compartidos.calendario = nuevo }

        let actual = nuevo.ciclo(contiene: ahora).clave
        let motor = MotorAnalitico(contexto: contexto, calendario: calendario, ciclos: nuevo)
        for periodo in [actual, actual.siguiente] {
            for categoria in CategoriaGasto.allCases {
                try motor.sincronizarIndicadores(categoria: categoria, periodo: periodo)
            }
        }
    }
}
