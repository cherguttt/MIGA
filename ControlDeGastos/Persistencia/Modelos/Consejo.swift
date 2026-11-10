//
//  Consejo.swift
//  ControlDeGastos
//
//  CAPA: Persistencia (modelo de datos) — entidad Consejo, sección 4.6.5 del portafolio.
//  Sprint 5 (CU-07).
//

import Foundation
import SwiftData

/// Consejo de educación financiera de la biblioteca de la app.
@Model
final class Consejo {
    /// Identificador único del consejo.
    @Attribute(.unique) var id: UUID

    /// Título breve; también es el encabezado de la notificación.
    var titulo: String

    /// Texto completo.
    var contenido: String

    /// Ejemplo práctico en pesos chilenos (opcional).
    var ejemplo: String?

    /// Temática del consejo (Ahorro, Presupuesto, Deuda…).
    var categoria: CategoriaConsejo

    /// Posición en la secuencia del envío semanal (1, 2, 3…).
    var orden: Int

    /// Permite desactivar un consejo sin eliminarlo.
    var activo: Bool

    /// Ícono propio de SF Symbols (opcional).
    var icono: String?

    /// RELACIÓN 1:N con los envíos de este consejo.
    @Relationship(deleteRule: .cascade, inverse: \EnvioConsejo.consejo)
    var envios: [EnvioConsejo] = []

    /// Crea un consejo con su contenido y su posición en la secuencia semanal.
    init(
        titulo: String,
        contenido: String,
        ejemplo: String? = nil,
        categoria: CategoriaConsejo,
        orden: Int,
        activo: Bool = true,
        icono: String? = nil
    ) {
        self.id = UUID()
        self.titulo = titulo
        self.contenido = contenido
        self.ejemplo = ejemplo
        self.categoria = categoria
        self.orden = orden
        self.activo = activo
        self.icono = icono
    }
}

// MARK: - Texto derivado (no se guarda: se calcula al leerlo)

extension Consejo {
    /// Ícono a mostrar: el propio del consejo o, si no tiene, el de su temática.
    var iconoVisible: String { icono ?? categoria.icono }

    /// Párrafos del contenido, separados por líneas en blanco.
    var parrafos: [String] {
        contenido.components(separatedBy: "\n\n").filter { !$0.isEmpty }
    }

    /// Párrafos sin la fuente (se muestran como texto principal).
    var parrafosPrincipales: [String] { parrafos.filter { !$0.hasPrefix("Fuente:") } }

    /// Fuente del consejo, si la tiene (se muestra en letra pequeña).
    var fuente: String? { parrafos.first { $0.hasPrefix("Fuente:") } }

    /// Primer párrafo: se usa como resumen en la tarjeta «Consejo de esta semana».
    var resumen: String { parrafosPrincipales.first ?? "" }

    /// Primera oración: es el cuerpo de la notificación (mockup P9).
    var primeraOracion: String {
        let texto = resumen
        if let rango = texto.range(of: "\\. (?=[A-ZÁÉÍÓÚÑ¿¡«])", options: .regularExpression) {
            return String(texto[..<rango.lowerBound]) + "."
        }
        return texto
    }

    /// Filas del ejemplo práctico, listas para dibujar.
    var filasEjemplo: [FilaEjemplo] {
        (ejemplo ?? "").split(separator: "\n").map { FilaEjemplo(linea: String($0)) }
    }
}

/// Una fila de la tarjeta «Ejemplo práctico» (mockup P7).
struct FilaEjemplo: Identifiable, Equatable {
    let id = UUID()
    let texto: String
    let valor: String?
    let destacado: Bool

    /// Interpreta una línea «texto | **valor».
    init(linea: String) {
        let partes = linea.components(separatedBy: " | ")
        texto = partes[0]
        if partes.count > 1 {
            let bruto = partes[1]
            destacado = bruto.hasPrefix("**")
            valor = destacado ? String(bruto.dropFirst(2)) : bruto
        } else {
            valor = nil
            destacado = false
        }
    }

    /// Dos filas son iguales si coinciden su texto, su valor y su formato.
    static func == (a: FilaEjemplo, b: FilaEjemplo) -> Bool {
        a.texto == b.texto && a.valor == b.valor && a.destacado == b.destacado
    }
}
