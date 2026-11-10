//
//  Enumeraciones.swift
//  ControlDeGastos
//
//  CAPA: Persistencia (modelo de datos) — sección 4.6.7 del portafolio.
//

import SwiftUI

/// Categorías de gasto disponibles en la aplicación.
enum CategoriaGasto: String, Codable, CaseIterable, Identifiable {
    case alimentacion
    case transporte
    case servicios
    case entretenimiento
    case salud
    case educacion
    /// «Pago Créditos»: pagos de deudas, como la cuota o el pago de la tarjeta de crédito, una línea de
    /// crédito o un crédito de consumo.
    case pagoCreditos
    /// «Otros»: gastos que no calzan en las demás categorías, por ejemplo una pensión de alimentos, regalos,
    /// mascotas o donaciones.
    case otros

    var id: String { rawValue }

    /// Nombre que se muestra en pantalla (con tildes y mayúscula).
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

    /// Color de la temática, tomado del mockup P6.
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
    case semanal
    case gastoHormiga
}

// MARK: - Colores en hexadecimal

extension Color {
    /// Crea un color a partir de un número hexadecimal, por ejemplo `Color(hex: 0x6D28D9)`.
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}
