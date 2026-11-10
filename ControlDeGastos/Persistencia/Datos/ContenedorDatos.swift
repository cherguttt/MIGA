//
//  ContenedorDatos.swift
//  ControlDeGastos
//
//  CAPA: Persistencia — configuración de la base de datos (sección 4.4.3 y 4.6 del portafolio).
//
//  CONCEPTOS CLAVE:
//  - La base de datos es SQLite (un archivo dentro del iPhone).
//  - SwiftData la crea y la administra a partir de las clases marcadas con `@Model`.
//  - `ModelContainer` = el «contenedor»: representa la base de datos completa (esquema + archivo).
//  - `ModelContext`  = el «contexto»: el espacio de trabajo donde insertamos, borramos y guardamos.
//  - El archivo queda en el contenedor privado de la app, protegido por Data Protection de iOS
//    (cifrado del sistema), en cumplimiento de la Ley N° 21.719.
//

import Foundation
import SwiftData

// Usamos un `enum` SIN casos como «espacio de nombres»: solo agrupa funciones estáticas.
// Como no tiene casos, nadie puede crear una instancia de él por error.
enum ContenedorDatos {

    /// Modelos que forman el esquema de la base de datos (se amplía en cada Sprint).
    /// `static` = pertenece al tipo, no a una instancia: se usa como `ContenedorDatos.esquema`.
    /// `PerfilUsuario.self` se refiere al TIPO en sí (no a un perfil concreto).
    static let esquema = Schema([
        PerfilUsuario.self,
        Transaccion.self,
        Presupuesto.self,     // Sprint 2. Al abrir una base existente, SwiftData agrega
                              // la tabla nueva automáticamente (migración ligera).
        Consejo.self,         // Sprint 5: consejos de educación financiera…
        EnvioConsejo.self,    // …y registro de los consejos enviados.
        CambioCiclo.self      // Ciclo de gastos configurable: historial de cambios del día de inicio.
    ])

    /// Crea el contenedor de datos de la aplicación.
    /// - Parameter enMemoria: `true` para pruebas y vistas previas (los datos no se guardan en disco).
    /// - Returns: el `ModelContainer` listo para usar (`->` indica el tipo que devuelve la función).
    static func crear(enMemoria: Bool = false) -> ModelContainer {
        // `do { ... } catch { ... }`: manejo de errores.
        // Dentro del `do`, las funciones marcadas con `try` pueden fallar («lanzar» un error);
        // si alguna falla, la ejecución salta directamente al bloque `catch`.
        do {
            // Declaramos la constante sin valor; el `if` de abajo le asigna uno en cada rama.
            let configuracion: ModelConfiguration
            if enMemoria {
                // Base de datos temporal en la memoria RAM: desaparece al cerrar la app.
                configuracion = ModelConfiguration(schema: esquema, isStoredInMemoryOnly: true)
            } else {
                // Base de datos real en disco, dentro de una carpeta protegida.
                let carpeta = try carpetaProtegida()
                configuracion = ModelConfiguration(
                    schema: esquema,
                    url: carpeta.appending(path: "ControlDeGastos.store")   // Archivo SQLite.
                )
            }
            // Aquí SwiftData abre (o crea por primera vez) la base de datos SQLite.
            let contenedor = try ModelContainer(for: esquema, configurations: [configuracion])
            // `!` niega un Bool: «si NO está en memoria…».
            if !enMemoria {
                aplicarProteccionArchivos()
            }
            return contenedor
        } catch {
            // Sin base de datos la app no puede funcionar, así que la detenemos con un mensaje.
            // `\(error)` es «interpolación»: inserta el valor de una variable dentro del texto.
            fatalError("No se pudo crear la base de datos local: \(error)")
        }
    }

    // `MARK:` no es código: crea un separador visible en el menú de navegación de Xcode.
    // MARK: - Protección de datos (Ley N° 21.719)

    /// Carpeta donde se guarda la base de datos SQLite:
    /// …/Library/Application Support/BaseDeDatos/ (dentro del espacio privado de la app).
    private static var carpetaBaseDatos: URL {
        URL.applicationSupportDirectory.appending(path: "BaseDeDatos", directoryHint: .isDirectory)
    }

    /// Crea la carpeta de la base de datos con la clase de protección de iOS.
    /// Los archivos creados dentro de ella heredan esa protección (cifrado AES-256 del sistema).
    /// `throws` indica que esta función puede lanzar un error; quien la llame debe usar `try`.
    private static func carpetaProtegida() throws -> URL {
        let carpeta = carpetaBaseDatos
        // `FileManager.default` es el administrador de archivos del sistema.
        try FileManager.default.createDirectory(
            at: carpeta,
            withIntermediateDirectories: true,   // Crea también las carpetas intermedias si faltan.
            // `completeUnlessOpen`: el archivo queda cifrado mientras el iPhone está bloqueado,
            // salvo que la app ya lo tuviera abierto (evita fallos de la base de datos en segundo plano).
            attributes: [.protectionKey: FileProtectionType.completeUnlessOpen]
        )
        return carpeta
    }

    /// Asegura la clase de protección en los archivos existentes de la base de datos
    /// (archivo principal y archivos auxiliares de SQLite: «-wal» y «-shm»).
    private static func aplicarProteccionArchivos() {
        // `try?` intenta la operación y, si falla, devuelve `nil` en vez de lanzar un error.
        // `?? []` es el operador «coalescencia nula»: si lo de la izquierda es nil, usa una lista vacía.
        let archivos = (try? FileManager.default.contentsOfDirectory(
            at: carpetaBaseDatos,
            includingPropertiesForKeys: nil
        )) ?? []
        // Bucle `for … in`: recorre cada archivo de la lista.
        for archivo in archivos {
            try? FileManager.default.setAttributes(
                [.protectionKey: FileProtectionType.completeUnlessOpen],
                ofItemAtPath: archivo.path(percentEncoded: false)
            )
        }
    }
}
