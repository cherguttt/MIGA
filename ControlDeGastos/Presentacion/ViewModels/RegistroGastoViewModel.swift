//
//  RegistroGastoViewModel.swift
//  ControlDeGastos
//
//  CAPA: Presentación — estado y lógica de la pantalla «Registrar gasto» (CU-02).
//  Sprint 4: también recibe el monto leído desde una boleta (CU-06, paso 5).
//
//  PATRÓN MVVM (Modelo – Vista – ViewModel):
//  - Modelo: los datos (Transaccion).
//  - Vista: lo que se dibuja (RegistroGastoView).
//  - ViewModel (este archivo): guarda lo que el usuario está escribiendo y decide qué hacer
//    al presionar «Confirmar». Así la vista queda simple y solo se encarga de mostrar.
//

import Foundation
import Observation   // Framework que aporta la macro @Observable.
import SwiftData     // Sprint 2: para consultar el presupuesto de la categoría.

// `@Observable`: cuando cambia cualquier propiedad de esta clase, las vistas que la leen
// se vuelven a dibujar automáticamente. Es la «magia» que conecta datos e interfaz.
@Observable
final class RegistroGastoViewModel {
    // Estado del formulario. Swift deduce el tipo por el valor inicial: "" → String, Date.now → Date.
    var montoTexto = ""                 // Lo que el usuario escribe, con puntos: "12.500".
    var categoria: CategoriaGasto?      // nil hasta que el usuario elige una categoría.
    var fecha = Date.now
    var descripcion = ""
    var mensajeConfirmacion: String?    // Si tiene texto, la vista muestra la alerta de éxito.
    var mensajeError: String?           // Si tiene texto, la vista muestra el error.

    /// Sprint 4: cómo se obtuvo el monto. Parte en `.manual` y cambia a `.boleta`
    /// cuando el monto viene del escáner. Se guarda junto con el gasto (atributo `origen`).
    private(set) var origen: OrigenRegistro = .manual

    /// Errores actuales del formulario (se recalculan cada vez que se leen).
    var errores: [ErrorValidacion] {
        ValidadorFormulario.validar(montoTexto: montoTexto, categoria: categoria, fecha: fecha)
    }

    /// El botón «Confirmar gasto» se habilita solo si no hay errores.
    var puedeConfirmar: Bool { errores.isEmpty }

    /// Mantiene el monto solo con dígitos y separadores de miles.
    /// Se llama cada vez que el usuario escribe. Solo asignamos si cambió, para no
    /// provocar un ciclo infinito de actualizaciones.
    func normalizarMonto(_ texto: String) {
        let normalizado = Formato.miles(texto)
        if normalizado != texto { montoTexto = normalizado }
        // Sprint 4: si el usuario borra el monto leído de la boleta, el siguiente que escriba es manual.
        if normalizado.isEmpty { origen = .manual }
    }

    /// Sprint 4 (CU-06, paso 5, y Figura 6): precarga el monto detectado en la boleta.
    /// El usuario puede revisarlo y corregirlo antes de confirmar; aun así el gasto queda
    /// registrado con origen «boleta», porque el monto partió de la lectura OCR.
    func precargar(monto: Decimal) {
        // `NSDecimalNumber(decimal:).stringValue` convierte 12500 en el texto "12500";
        // `Formato.miles` le agrega los puntos: "12.500".
        montoTexto = Formato.miles(NSDecimalNumber(decimal: monto).stringValue)
        origen = .boleta
        mensajeError = nil
    }

    /// Guarda el gasto mediante el servicio de la capa lógica.
    /// `con servicio` usa una etiqueta externa («con») y un nombre interno («servicio»):
    /// se llama `modelo.confirmar(con: servicio)`, que se lee casi como una frase.
    func confirmar(con servicio: ServicioTransacciones) {
        // Un `guard` puede comprobar varias condiciones separadas por comas:
        // 1. que el formulario sea válido; 2. que el texto se convierta en monto;
        // 3. `let categoria` «desenvuelve» el opcional: dentro de la función ya no es nil.
        guard puedeConfirmar, let monto = Formato.monto(desde: montoTexto), let categoria else { return }
        do {
            try servicio.registrarGasto(
                monto: monto,
                categoria: categoria,
                fecha: fecha,
                descripcion: descripcion,
                origen: origen                // Sprint 4: manual o boleta.
            )
            let desdeBoleta = origen == .boleta ? " desde la boleta" : ""
            mensajeConfirmacion = "Gasto de \(Formato.pesos(monto)) registrado\(desdeBoleta) en \(categoria.nombre)."
                + resumenPresupuesto(categoria: categoria, fecha: fecha, contexto: servicio.contexto)
            mensajeError = nil
            reiniciar()   // Deja el formulario limpio para el siguiente gasto.
        } catch {
            // Dentro de `catch`, Swift crea automáticamente la constante `error`.
            mensajeError = error.localizedDescription
        }
    }

    /// Sprint 2: frase con el avance del presupuesto de la categoría, por ejemplo
    /// « Llevas el 82 % de tu presupuesto de Alimentación del mes.».
    /// Si la categoría no tiene presupuesto ese mes, devuelve un texto vacío.
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
