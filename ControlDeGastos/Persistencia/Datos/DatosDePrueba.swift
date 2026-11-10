//
//  DatosDePrueba.swift
//  ControlDeGastos
//
//  CAPA: Persistencia — datos de ejemplo SOLO para las vistas previas (#Preview) de Xcode.
//  No se usan en la aplicación real. Permiten ver una pantalla con datos sin ejecutar la app.
//

import Foundation
import SwiftData

/// Datos de ejemplo para las vistas previas de Xcode (no se usan en la app).
@MainActor
enum DatosDePrueba {
    /// Contenedor en memoria con un perfil y algunos gastos de ejemplo.
    static var contenedor: ModelContainer {
        let contenedor = ContenedorDatos.crear(enMemoria: true)
        let contexto = contenedor.mainContext

        contexto.insert(PerfilUsuario(
            nombre: "Camila",
            ingresoMensualReferencia: 800_000,
            consentimientoAceptado: true,
            fechaConsentimiento: .now
        ))

        let ejemplos: [(Decimal, CategoriaGasto, String?)] = [
            (12_500, .alimentacion, "Almuerzo del trabajo"),
            (1_500, .transporte, nil),
            (35_990, .servicios, "Cuenta de luz"),
            (8_000, .entretenimiento, "Cine")
        ]

        for (indice, ejemplo) in ejemplos.enumerated() {
            contexto.insert(Transaccion(
                monto: ejemplo.0,
                categoria: ejemplo.1,
                fecha: Date.now.addingTimeInterval(Double(-indice) * 86_400),
                descripcion: ejemplo.2
            ))
        }

        let periodo = PeriodoMensual()
        let limites: [(CategoriaGasto, Decimal)] = [
            (.alimentacion, 130_000), (.transporte, 80_000), (.servicios, 150_000),
            (.entretenimiento, 60_000), (.salud, 100_000), (.educacion, 80_000)
        ]
        for (categoria, monto) in limites {
            contexto.insert(Presupuesto(categoria: categoria, mes: periodo.mes, anio: periodo.anio, montoMaximo: monto))
        }

        let servicioConsejos = ServicioConsejos(contexto: contexto)
        _ = try? servicioConsejos.precargarSiHaceFalta()
        if let consejos = try? servicioConsejos.consejosActivos() {
            let porTitulo = { (titulo: String) in consejos.first { $0.titulo == titulo } }
            if let bolaDeNieve = porTitulo("La regla de la bola de nieve") {
                contexto.insert(EnvioConsejo(consejo: bolaDeNieve, fechaEnvio: .now.addingTimeInterval(-7 * 86_400), motivo: .semanal))
            }
            if let cafe = porTitulo("El costo oculto del café diario") {
                contexto.insert(EnvioConsejo(consejo: cafe, fechaEnvio: .now, motivo: .semanal))
            }
        }
        return contenedor
    }
}
