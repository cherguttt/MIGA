//
//  AjustesViewModel.swift
//  ControlDeGastos
//
//  CAPA: Presentación — estado y lógica de la pestaña «Ajustes» (RF-02, RF-03).
//  Sigue el mismo patrón MVVM que RegistroGastoViewModel: la vista solo dibuja y
//  este ViewModel decide qué hacer con lo que el usuario cambia.
//

import Foundation
import Observation
import SwiftData

@Observable
final class AjustesViewModel {

    /// Texto del campo «Ingreso mensual», con separadores de miles (por ejemplo, "800.000").
    var ingresoTexto = ""

    /// Mensaje informativo (por ejemplo, cuando falla la autenticación).
    var mensaje: String?

    /// Controla si se muestra la hoja con la política de privacidad.
    var mostrarPolitica = false

    /// Carga en el campo de texto el ingreso guardado en el perfil.
    /// `String(describing:)` convierte el Decimal en texto ("800000") y `miles` le pone puntos.
    func cargar(desde perfil: PerfilUsuario) {
        ingresoTexto = Formato.miles(String(describing: perfil.ingresoMensualReferencia))
    }

    /// Se llama cada vez que el usuario escribe en el campo del ingreso.
    /// 1. Pone los puntos de miles.
    /// 2. Solo si el monto es válido (> 0) lo copia al perfil; así un campo vacío
    ///    nunca deja el ingreso de referencia en cero.
    func ingresoCambio(_ texto: String, en perfil: PerfilUsuario) {
        let normalizado = Formato.miles(texto)
        if normalizado != texto { ingresoTexto = normalizado }
        if let monto = Formato.monto(desde: normalizado), monto > 0 {
            perfil.ingresoMensualReferencia = monto
        }
    }

    /// Activa o desactiva el bloqueo; en ambos casos exige autenticación.
    /// Así, alguien que tome el iPhone desbloqueado no puede quitar la protección (RF-03).
    func cambiarBloqueo(_ activar: Bool, en perfil: PerfilUsuario, contexto: ModelContext) async {
        let motivo = activar
            ? "Confirma tu identidad para activar el bloqueo."
            : "Confirma tu identidad para desactivar el bloqueo."
        // Una función async puede usarse directamente en la condición de un `if` con `await`.
        if await ServicioAutenticacion.autenticar(motivo: motivo) {
            perfil.bloqueoBiometricoActivo = activar
            guardar(en: contexto)
            mensaje = nil
        } else {
            mensaje = "No se pudo verificar tu identidad; el bloqueo no cambió."
        }
    }

    /// Sprint 5 (CU-07, flujo alternativo): al activar el consejo semanal se programan los
    /// próximos lunes; al desactivarlo se cancelan las notificaciones pendientes.
    func cambiarConsejoSemanal(_ activo: Bool, contexto: ModelContext) {
        guardar(en: contexto)
        let servicio = ServicioConsejos(contexto: contexto)
        if activo {
            try? servicio.programarSemanal()
        } else {
            try? servicio.cancelarSemanal()
        }
    }

    // MARK: - Ciclo de gastos

    /// Día elegido en el selector «Inicio del ciclo».
    var diaCiclo = 1
    /// Día que espera confirmación (mientras no es nil, se muestra el mensaje de confirmación).
    var diaPorConfirmar: Int?
    /// Texto del mensaje de confirmación.
    var mensajeCiclo = ""

    /// Muestra en el selector el día de inicio que rige (o que regirá, si hay un cambio programado).
    func cargarCiclo() {
        diaCiclo = CalendarioCiclos.compartido.diaInicioFinal
    }

    /// El usuario eligió otro día en el selector: antes de aplicar, se le explica qué pasará.
    func diaCicloCambio(_ nuevo: Int, contexto: ModelContext, ahora: Date = .now) {
        let ciclos = CalendarioCiclos.compartido
        guard nuevo != ciclos.diaInicioFinal,
              let vista = try? ServicioCiclos(contexto: contexto).vistaPrevia(diaInicio: nuevo, ahora: ahora)
        else { return }
        mensajeCiclo = Self.mensajeConfirmacion(dia: nuevo, actual: vista.actual, siguiente: vista.siguiente,
                                                mantieneActual: nuevo == ciclos.diaInicio(en: ahora))
        diaPorConfirmar = nuevo
    }

    /// Aplica el cambio confirmado.
    func confirmarCiclo(contexto: ModelContext) {
        guard let dia = diaPorConfirmar else { return }
        do {
            try ServicioCiclos(contexto: contexto).cambiarDiaInicio(dia)
            mensaje = nil
        } catch {
            mensaje = error.localizedDescription
        }
        diaPorConfirmar = nil
        cargarCiclo()
    }

    /// El usuario canceló: el selector vuelve al día que rige.
    func cancelarCiclo() {
        diaPorConfirmar = nil
        cargarCiclo()
    }

    /// Regla en palabras: «del 1 al último día de cada mes» o «del 25 de cada mes al 24 del mes siguiente».
    static func regla(_ dia: Int) -> String {
        dia == 1 ? "del 1 al último día de cada mes" : "del \(dia) de cada mes al \(dia - 1) del mes siguiente"
    }

    /// Último día de un ciclo (su fin es exclusivo).
    private static func ultimoDia(_ ciclo: Ciclo, _ calendario: Calendar = .current) -> Date {
        calendario.date(byAdding: .day, value: -1, to: ciclo.fin) ?? ciclo.fin
    }

    /// Mensaje que se muestra antes de confirmar el cambio.
    static func mensajeConfirmacion(dia: Int, actual: Ciclo, siguiente: Ciclo, mantieneActual: Bool) -> String {
        if mantieneActual {
            return "Se cancela el cambio programado: tus ciclos seguirán yendo \(regla(dia))."
        }
        return "Tu ciclo actual irá del \(Formato.diaMesLargo(actual.inicio)) al \(Formato.diaMesLargo(ultimoDia(actual))). "
            + "Desde el \(Formato.diaMesLargo(siguiente.inicio)), tus ciclos irán \(regla(dia)). "
            + "Tus gastos no se modifican: solo cambia cómo se agrupan."
    }

    /// Texto bajo el selector: cómo son los ciclos y, si hay transición, cuándo termina.
    static func descripcionCiclo(_ ciclos: CalendarioCiclos, ahora: Date = .now) -> String {
        let actual = ciclos.ciclo(contiene: ahora)
        let diaFinal = ciclos.diaInicioFinal
        let esNormal = ciclos.calendario.date(byAdding: .month, value: 1, to: actual.inicio) == actual.fin
        if diaFinal != ciclos.diaInicio(en: ahora) || !esNormal {
            return "Ciclo actual (de transición): del \(Formato.diaMesLargo(actual.inicio)) al \(Formato.diaMesLargo(ultimoDia(actual))). "
                + "Desde el \(Formato.diaMesLargo(actual.fin)), tus ciclos irán \(regla(diaFinal))."
        }
        return "Tus ciclos van \(regla(diaFinal)). Ciclo actual: del \(Formato.diaMesLargo(actual.inicio)) al \(Formato.diaMesLargo(ultimoDia(actual)))."
    }

    /// Escribe en la base de datos SQLite los cambios pendientes del perfil.
    /// `try?` ignora el error: si fallara, SwiftData reintentará en su guardado automático.
    func guardar(en contexto: ModelContext) {
        try? contexto.save()
    }
}
