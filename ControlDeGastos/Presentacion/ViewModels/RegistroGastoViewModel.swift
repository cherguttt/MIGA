//
//  RegistroGastoViewModel.swift
//  ControlDeGastos
//
//  CAPA: Presentación — estado y lógica de la pantalla «Registrar gasto» (CU-02).
//  Sprint 4: también recibe el monto leído desde una boleta (CU-06, paso 5).
//

import Foundation
import Observation
import SwiftData

/// Estado del formulario de registro de gastos, manual o con boleta.
@Observable
final class RegistroGastoViewModel {
    var montoTexto = ""
    var categoria: CategoriaGasto?
    var fecha = Date.now
    var descripcion = ""
    var mensajeConfirmacion: String?
    var mensajeError: String?

    /// Sprint 4: cómo se obtuvo el monto.
    private(set) var origen: OrigenRegistro = .manual

    /// Errores actuales del formulario (se recalculan cada vez que se leen).
    var errores: [ErrorValidacion] {
        ValidadorFormulario.validar(montoTexto: montoTexto, categoria: categoria, fecha: fecha)
    }

    /// El botón «Confirmar gasto» se habilita solo si no hay errores.
    var puedeConfirmar: Bool { errores.isEmpty }

    /// Mantiene el monto solo con dígitos y separadores de miles.
    func normalizarMonto(_ texto: String) {
        let normalizado = Formato.miles(texto)
        if normalizado != texto { montoTexto = normalizado }
        if normalizado.isEmpty { origen = .manual }
    }

    /// Sprint 4 (CU-06, paso 5, y Figura 6): precarga el monto detectado en la boleta.
    func precargar(monto: Decimal) {
        montoTexto = Formato.miles(NSDecimalNumber(decimal: monto).stringValue)
        origen = .boleta
        mensajeError = nil
    }

    /// Guarda el gasto mediante el servicio de la capa lógica.
    func confirmar(con servicio: ServicioTransacciones) {
        guard puedeConfirmar, let monto = Formato.monto(desde: montoTexto), let categoria else { return }
        do {
            try servicio.registrarGasto(
                monto: monto,
                categoria: categoria,
                fecha: fecha,
                descripcion: descripcion,
                origen: origen
            )
            let desdeBoleta = origen == .boleta ? " desde la boleta" : ""
            mensajeConfirmacion = "Gasto de \(Formato.pesos(monto)) registrado\(desdeBoleta) en \(categoria.nombre)."
                + resumenPresupuesto(categoria: categoria, fecha: fecha, contexto: servicio.contexto)
            mensajeError = nil
            reiniciar()
        } catch {
            mensajeError = error.localizedDescription
        }
    }

    /// Sprint 2: frase con el avance del presupuesto de la categoría, por ejemplo « Llevas el 82 % de tu
    /// presupuesto de Alimentación del mes.».
    private func resumenPresupuesto(categoria: CategoriaGasto, fecha: Date, contexto: ModelContext) -> String {
        let periodo = PeriodoMensual(fecha)
        let motor = MotorAnalitico(contexto: contexto)
        guard
            let presupuesto = try? ServicioPresupuestos(contexto: contexto).presupuesto(categoria: categoria, periodo: periodo),
            let acumulado = try? motor.gastoAcumulado(categoria: categoria, periodo: periodo),
            let porcentaje = MotorAnalitico.porcentaje(acumulado, de: presupuesto.montoMaximo)
        else { return "" }
        return " Llevas el \(porcentaje) % de tu presupuesto de \(categoria.nombre) del \(periodo.unidad)."
    }

    /// Limpia el formulario para un nuevo registro.
    func reiniciar() {
        montoTexto = ""
        categoria = nil
        fecha = .now
        descripcion = ""
        origen = .manual
    }
}
