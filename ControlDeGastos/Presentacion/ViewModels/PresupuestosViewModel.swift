//
//  PresupuestosViewModel.swift
//  ControlDeGastos
//
//  CAPA: Presentación — estado y lógica de la pestaña «Presupuestos» (CU-03, RF-08).
//
//  La vista entrega al ViewModel las listas que lee de la base de datos (con @Query) y el
//  ViewModel las transforma en lo que se muestra: una fila por categoría con su límite,
//  lo gastado y el color de la barra. Esa transformación es «pura» y se prueba con XCTest.
//

import Foundation
import Observation
import SwiftUI   // Solo para el tipo `Color` del estado de avance.

// MARK: - Estado de avance (color de la barra)

/// Clasifica el avance de una categoría para pintar su barra (mockup P5 del portafolio):
/// verde bajo el 70 %, naranjo entre 70 % y 89 %, rojo desde el 90 %.
/// Los cortes coinciden con los umbrales de alerta del CU-04.
enum EstadoAvance: Equatable {
    case sinLimite
    case enRango
    case atencion
    case critico

    static func para(gastado: Decimal, montoMaximo: Decimal?) -> EstadoAvance {
        guard let montoMaximo, montoMaximo > 0 else { return .sinLimite }
        switch GestorAlertas.umbralAlcanzado(acumulado: gastado, montoMaximo: montoMaximo) {
        case .none: return .enRango
        case .setenta?, .ochenta?: return .atencion   // `?` porque el resultado es opcional.
        case .noventa?: return .critico
        }
    }

    var color: Color {
        switch self {
        case .sinLimite: return .gray
        case .enRango: return .green
        case .atencion: return .orange
        case .critico: return .red
        }
    }
}

// MARK: - Fila de la lista

/// Lo que se muestra de cada categoría. `Identifiable` para usarla en `ForEach`.
struct FilaPresupuesto: Identifiable, Equatable {
    let categoria: CategoriaGasto
    /// Límite del mes; `nil` si la categoría no tiene presupuesto.
    let montoMaximo: Decimal?
    /// Gasto acumulado real de la categoría en el mes.
    let gastado: Decimal

    var id: String { categoria.id }

    /// Porcentaje entero del límite ya gastado (por ejemplo, 82), o `nil` sin límite.
    var porcentaje: Int? {
        guard let montoMaximo else { return nil }
        return MotorAnalitico.porcentaje(gastado, de: montoMaximo)
    }

    /// Fracción entre 0 y 1 para dibujar la barra (se limita a 1 si se pasó del límite).
    var fraccion: Double {
        guard let montoMaximo, montoMaximo > 0 else { return 0 }
        return min(1, (gastado / montoMaximo).comoDouble)
    }

    var estado: EstadoAvance { EstadoAvance.para(gastado: gastado, montoMaximo: montoMaximo) }
}

// MARK: - ViewModel

@Observable
final class PresupuestosViewModel {

    /// Mes que se está viendo (por defecto, el actual). CU-03, paso 1.
    var periodo = PeriodoMensual()

    /// Categoría cuyo límite se está editando. Si no es `nil`, la vista abre el editor.
    var categoriaEditando: CategoriaGasto?

    /// Texto del monto en el editor, con separadores de miles.
    var montoTexto = ""

    /// Mensaje de error para mostrar en el editor o en la pantalla.
    var mensajeError: String?

    // MARK: Datos para la pantalla

    /// CU-03, paso 2: todas las categorías con su límite y el avance del mes.
    func filas(presupuestos: [Presupuesto], transacciones: [Transaccion]) -> [FilaPresupuesto] {
        let delMes = presupuestos.filter { $0.periodo == periodo }
        let gastosDelMes = transacciones.filter { periodo.contiene($0.fecha) }
        // `map` crea una fila por cada categoría, en el orden de `allCases`.
        return CategoriaGasto.allCases.map { categoria in
            FilaPresupuesto(
                categoria: categoria,
                montoMaximo: delMes.first { $0.categoria == categoria }?.montoMaximo,
                gastado: MotorAnalitico.acumulado(de: gastosDelMes, categoria: categoria)
            )
        }
    }

    /// CU-03, paso 5: suma de los límites del mes.
    func totalPresupuestado(_ filas: [FilaPresupuesto]) -> Decimal {
        filas.compactMap(\.montoMaximo).reduce(0, +)   // `compactMap` descarta los `nil`.
    }

    /// ¿Hay límites en el mes anterior que se puedan copiar a este mes vacío?
    func puedeCopiarMesAnterior(presupuestos: [Presupuesto]) -> Bool {
        !presupuestos.contains { $0.periodo == periodo }
            && presupuestos.contains { $0.periodo == periodo.anterior }
    }

    // MARK: Navegación entre meses

    func mesAnterior() { periodo = periodo.anterior }
    func mesSiguiente() { periodo = periodo.siguiente }
    func irAlMesActual() { periodo = PeriodoMensual() }
    var esMesActual: Bool { periodo == PeriodoMensual() }

    // MARK: Edición de un límite

    /// Abre el editor con el límite actual de la fila (si tiene).
    func editar(_ fila: FilaPresupuesto) {
        montoTexto = fila.montoMaximo.map { Formato.miles(String(describing: $0)) } ?? ""
        mensajeError = nil
        categoriaEditando = fila.categoria
    }

    /// Monto escrito convertido a número.
    var montoIngresado: Decimal? { Formato.monto(desde: montoTexto) }

    /// CU-03, paso 4: solo se puede guardar un monto mayor a cero.
    var puedeGuardar: Bool { (montoIngresado ?? 0) > 0 }

    /// Pone los separadores de miles mientras el usuario escribe.
    func normalizarMonto(_ texto: String) {
        let normalizado = Formato.miles(texto)
        if normalizado != texto { montoTexto = normalizado }
    }

    /// Guarda el límite. Devuelve `true` si se guardó (para cerrar el editor).
    @discardableResult
    func guardar(con servicio: ServicioPresupuestos) -> Bool {
        guard let categoria = categoriaEditando, let monto = montoIngresado else { return false }
        do {
            try servicio.guardar(montoMaximo: monto, categoria: categoria, periodo: periodo)
            categoriaEditando = nil
            return true
        } catch {
            mensajeError = error.localizedDescription
            return false
        }
    }

    /// Quita el límite de la categoría que se está editando.
    func quitarLimite(con servicio: ServicioPresupuestos) {
        guard let categoria = categoriaEditando else { return }
        do {
            if let presupuesto = try servicio.presupuesto(categoria: categoria, periodo: periodo) {
                try servicio.eliminar(presupuesto)
            }
            categoriaEditando = nil
        } catch {
            mensajeError = error.localizedDescription
        }
    }

    /// Copia los límites del mes anterior al mes que se está viendo.
    func copiarMesAnterior(con servicio: ServicioPresupuestos) {
        do {
            try servicio.copiarDelMesAnterior(a: periodo)
        } catch {
            mensajeError = error.localizedDescription
        }
    }
}
