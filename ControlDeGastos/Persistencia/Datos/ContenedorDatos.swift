//
//  ContenedorDatos.swift
//  ControlDeGastos
//
//  CAPA: Persistencia — configuración de la base de datos (sección 4.4.3 y 4.6 del portafolio).
//

import Foundation
import SwiftData

/// Crea la base de datos SwiftData cifrada con la protección de datos de iOS.
enum ContenedorDatos {
    /// Modelos que forman el esquema de la base de datos (se amplía en cada Sprint).
    static let esquema = Schema([
        PerfilUsuario.self,
        Transaccion.self,
        Presupuesto.self,
        Consejo.self,
        EnvioConsejo.self,
        CambioCiclo.self
    ])

    /// Crea el contenedor de datos de la aplicación.
    static func crear(enMemoria: Bool = false) -> ModelContainer {
        do {
            let configuracion: ModelConfiguration
            if enMemoria {
                configuracion = ModelConfiguration(schema: esquema, isStoredInMemoryOnly: true)
            } else {
                let carpeta = try carpetaProtegida()
                configuracion = ModelConfiguration(
                    schema: esquema,
                    url: carpeta.appending(path: "ControlDeGastos.store")
                )
            }
            let contenedor = try ModelContainer(for: esquema, configurations: [configuracion])
            if !enMemoria {
                aplicarProteccionArchivos()
            }
            return contenedor
        } catch {
            fatalError("No se pudo crear la base de datos local: \(error)")
        }
    }

    // MARK: - Protección de datos (Ley N° 21.719)

    /// Carpeta donde se guarda la base de datos SQLite: …/Library/Application Support/BaseDeDatos/ (dentro
    /// del espacio privado de la app).
    private static var carpetaBaseDatos: URL {
        URL.applicationSupportDirectory.appending(path: "BaseDeDatos", directoryHint: .isDirectory)
    }

    /// Crea la carpeta de la base de datos con la clase de protección de iOS.
    private static func carpetaProtegida() throws -> URL {
        let carpeta = carpetaBaseDatos
        try FileManager.default.createDirectory(
            at: carpeta,
            withIntermediateDirectories: true,
            attributes: [.protectionKey: FileProtectionType.completeUnlessOpen]
        )
        return carpeta
    }

    /// Asegura la clase de protección en los archivos existentes de la base de datos (archivo principal y
    /// archivos auxiliares de SQLite: «-wal» y «-shm»).
    private static func aplicarProteccionArchivos() {
        let archivos = (try? FileManager.default.contentsOfDirectory(
            at: carpetaBaseDatos,
            includingPropertiesForKeys: nil
        )) ?? []
        for archivo in archivos {
            try? FileManager.default.setAttributes(
                [.protectionKey: FileProtectionType.completeUnlessOpen],
                ofItemAtPath: archivo.path(percentEncoded: false)
            )
        }
    }
}
