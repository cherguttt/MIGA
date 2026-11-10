//
//  Enumeraciones.swift
//  ControlDeGastos
//
//  CAPA: Persistencia (modelo de datos) — sección 4.6.7 del portafolio.
//
//  ¿QUÉ ES UN ENUM?
//  Un `enum` (enumeración) define un tipo con un conjunto CERRADO de valores posibles.
//  Por ejemplo, una categoría de gasto solo puede ser una de estas ocho; no existe
//  una «categoría inventada». Así el compilador evita errores como escribir "alimentasion".
//
//  En la base de datos SQLite, SwiftData guarda cada valor como texto (su `rawValue`).
//

// `import` trae un framework (biblioteca) de Apple para poder usar sus tipos.
// SwiftUI nos da el tipo `Color`, que usamos más abajo.
import SwiftUI

/// Categorías de gasto disponibles en la aplicación.
///
/// Protocolos que adopta (lo que va después de los dos puntos):
/// - `String`: cada caso tiene un valor de texto asociado (rawValue), por ejemplo "alimentacion".
/// - `Codable`: se puede convertir a texto/JSON y de vuelta; SwiftData lo necesita para guardarlo.
/// - `CaseIterable`: permite recorrer todos los casos con `CategoriaGasto.allCases` (lo usamos en la grilla).
/// - `Identifiable`: cada valor tiene un `id` único; SwiftUI lo necesita en los `ForEach`.
enum CategoriaGasto: String, Codable, CaseIterable, Identifiable {
    // Cada `case` es un valor posible. Como el enum es de tipo String,
    // el rawValue de cada caso es su propio nombre: .alimentacion → "alimentacion".
    case alimentacion
    case transporte
    case servicios
    case entretenimiento
    case salud
    case educacion
    /// «Pago Créditos»: pagos de deudas, como la cuota o el pago de la tarjeta de crédito,
    /// una línea de crédito o un crédito de consumo. Se agregó después del Sprint 5; como las
    /// categorías se guardan como texto, los gastos ya registrados no se ven afectados.
    case pagoCreditos
    /// «Otros»: gastos que no calzan en las demás categorías, por ejemplo una pensión de
    /// alimentos, regalos, mascotas o donaciones. Se agregó después del Sprint 3; como las
    /// categorías se guardan como texto, los gastos ya registrados no se ven afectados.
    case otros

    // Propiedad que exige `Identifiable`. Usamos el rawValue como identificador.
    // Es una «propiedad calculada»: no guarda nada, devuelve un valor cada vez que se lee.
    var id: String { rawValue }

    /// Nombre que se muestra en pantalla (con tildes y mayúscula).
    /// `switch self` revisa en qué caso estamos y devuelve el texto correspondiente.
    /// Swift obliga a cubrir TODOS los casos; si agregas uno nuevo, el compilador avisará aquí.
    var nombre: String {
        switch self {
        case .alimentacion: return "Alimentación"
        case .transporte: return "Transporte"
        case .servicios: return "Servicios"
        case .entretenimiento: return "Entretención"
        case .salud: return "Salud"
        case .educacion: return "Educación"
        case .pagoCreditos: return "Pago Créditos"
        case .otros: return "Otros"
        }
    }

    /// Nombre de un ícono de SF Symbols (la biblioteca de íconos de Apple).
    /// Puedes explorar todos los íconos con la app gratuita «SF Symbols» de Apple.
    var icono: String {
        switch self {
        case .alimentacion: return "fork.knife"
        case .transporte: return "bus.fill"
        case .servicios: return "bolt.fill"
        case .entretenimiento: return "gamecontroller.fill"
        case .salud: return "heart.fill"
        case .educacion: return "graduationcap.fill"
        case .pagoCreditos: return "creditcard.fill"
        case .otros: return "ellipsis.circle.fill"
        }
    }

    /// Color asociado a la categoría (se usa en íconos y botones).
    var color: Color {
        switch self {
        case .alimentacion: return .orange
        case .transporte: return .blue
        case .servicios: return .purple
        case .entretenimiento: return .pink
        case .salud: return .green
        case .educacion: return .indigo
        case .pagoCreditos: return .brown
        case .otros: return .gray
        }
    }
}

/// Forma en que se ingresó un gasto: escrito a mano o leído desde una boleta (OCR, Sprint 4).
enum OrigenRegistro: String, Codable {
    case manual
    case boleta
}

// MARK: - Sprint 5: educación financiera

/// Temáticas de los consejos de educación financiera (mockup P6 del portafolio).
enum CategoriaConsejo: String, Codable, CaseIterable, Identifiable {
    case ahorro
    case presupuesto
    case deuda
    case inversion
    case gastoHormiga
    case habitos

    var id: String { rawValue }

    /// Nombre que se muestra en pantalla.
    var nombre: String {
        switch self {
        case .ahorro: return "Ahorro"
        case .presupuesto: return "Presupuesto"
        case .deuda: return "Deuda"
        case .inversion: return "Inversión"
        case .gastoHormiga: return "Gasto hormiga"
        case .habitos: return "Hábitos"
        }
    }

    /// Ícono de SF Symbols de la temática.
    var icono: String {
        switch self {
        case .ahorro: return "banknote.fill"
        case .presupuesto: return "chart.bar.fill"
        case .deuda: return "creditcard.fill"
        case .inversion: return "chart.line.uptrend.xyaxis"
        case .gastoHormiga: return "cup.and.saucer.fill"
        case .habitos: return "brain.head.profile"
        }
    }

    /// Color de la temática, tomado del mockup P6. Se escribe en hexadecimal (como en el
    /// diseño web): 0x6D28D9 = rojo 6D, verde 28, azul D9.
    var color: Color {
        switch self {
        case .ahorro: return Color(hex: 0x1C3B6E)
        case .presupuesto: return Color(hex: 0x8A3A12)
        case .deuda: return Color(hex: 0x6D28D9)
        case .inversion: return Color(hex: 0x166534)
        case .gastoHormiga: return Color(hex: 0xB45309)
        case .habitos: return Color(hex: 0x0369A1)
        }
    }

    /// Versión más oscura del color, para el degradado del detalle del consejo (mockup P7).
    var colorOscuro: Color {
        switch self {
        case .ahorro: return Color(hex: 0x0F2547)
        case .presupuesto: return Color(hex: 0x5C260B)
        case .deuda: return Color(hex: 0x4C1D95)
        case .inversion: return Color(hex: 0x14532D)
        case .gastoHormiga: return Color(hex: 0x78350F)
        case .habitos: return Color(hex: 0x0C4A6E)
        }
    }
}

/// Motivo por el que se envió un consejo (entidad EnvioConsejo).
enum MotivoEnvio: String, Codable {
    case semanal        // Consejo programado de cada lunes a las 9:00.
    case gastoHormiga   // Consejo contextual al detectar un patrón de gasto hormiga.
}

// MARK: - Colores en hexadecimal

extension Color {
    /// Crea un color a partir de un número hexadecimal, por ejemplo `Color(hex: 0x6D28D9)`.
    /// `>>` desplaza los bits y `& 0xFF` se queda con los 8 bits de cada componente (0 a 255).
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}
