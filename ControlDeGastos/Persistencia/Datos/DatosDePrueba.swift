//
//  DatosDePrueba.swift
//  ControlDeGastos
//
//  CAPA: Persistencia — datos de ejemplo SOLO para las vistas previas (#Preview) de Xcode.
//  No se usan en la aplicación real. Permiten ver una pantalla con datos sin ejecutar la app.
//

import Foundation
import SwiftData

// `@MainActor`: todo lo de este tipo se ejecuta en el hilo principal (el de la interfaz).
// Es necesario porque `mainContext` (el contexto principal de SwiftData) vive en ese hilo.
@MainActor
enum DatosDePrueba {

    /// Contenedor en memoria con un perfil y algunos gastos de ejemplo.
    /// Es una propiedad calculada: cada vez que se lee, crea un contenedor nuevo y lo llena.
    static var contenedor: ModelContainer {
        let contenedor = ContenedorDatos.crear(enMemoria: true)   // Base de datos temporal.
        let contexto = contenedor.mainContext

        // `insert` agrega un objeto al contexto (todavía no está guardado en disco,
        // pero aquí no importa porque la base es en memoria).
        contexto.insert(PerfilUsuario(
            nombre: "Camila",
            ingresoMensualReferencia: 800_000,   // El guion bajo es solo para leer mejor: 800000.
            consentimientoAceptado: true,
            fechaConsentimiento: .now
        ))

        // Lista (arreglo) de TUPLAS. Una tupla agrupa varios valores sin crear un tipo nuevo:
        // (monto, categoría, descripción opcional).
        let ejemplos: [(Decimal, CategoriaGasto, String?)] = [
            (12_500, .alimentacion, "Almuerzo del trabajo"),
            (1_500, .transporte, nil),
            (35_990, .servicios, "Cuenta de luz"),
            (8_000, .entretenimiento, "Cine")
        ]

        // `enumerated()` entrega cada elemento junto con su posición (0, 1, 2, 3).
        for (indice, ejemplo) in ejemplos.enumerated() {
            contexto.insert(Transaccion(
                monto: ejemplo.0,        // `.0`, `.1`, `.2` acceden a cada parte de la tupla.
                categoria: ejemplo.1,
                // 86.400 segundos = 1 día. Cada ejemplo queda un día antes que el anterior.
                fecha: Date.now.addingTimeInterval(Double(-indice) * 86_400),
                descripcion: ejemplo.2
            ))
        }

        // Presupuestos del mes actual (los mismos valores del mockup P5 del portafolio).
        let periodo = PeriodoMensual()
        let limites: [(CategoriaGasto, Decimal)] = [
            (.alimentacion, 130_000), (.transporte, 80_000), (.servicios, 150_000),
            (.entretenimiento, 60_000), (.salud, 100_000), (.educacion, 80_000)
        ]
        for (categoria, monto) in limites {
            contexto.insert(Presupuesto(categoria: categoria, mes: periodo.mes, anio: periodo.anio, montoMaximo: monto))
        }

        // Sprint 5: consejos del archivo JSON y dos envíos, como en el mockup P6:
        // «La regla de la bola de nieve» hace 7 días y «El costo oculto del café diario» hoy.
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
