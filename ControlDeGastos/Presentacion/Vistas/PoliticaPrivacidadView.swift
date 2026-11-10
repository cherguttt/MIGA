//
//  PoliticaPrivacidadView.swift
//  ControlDeGastos
//
//  CAPA: Presentación — texto de la política de privacidad que el usuario acepta
//  en el primer inicio (Ley N° 21.719). Se muestra como hoja (sheet) desde
//  BienvenidaView y desde AjustesView.
//

import SwiftUI

struct PoliticaPrivacidadView: View {

    /// `dismiss` es una ACCIÓN del entorno: al llamarla con `cerrar()`, SwiftUI cierra
    /// la hoja que presentó esta vista. No necesitamos saber quién la abrió.
    @Environment(\.dismiss) private var cerrar

    var body: some View {
        // `NavigationStack` aporta la barra superior con título y botones.
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Cada sección se construye con la función `seccion` (definida abajo).
                    seccion("Responsable", "Esta aplicación es un prototipo académico desarrollado como proyecto de título en la Universidad Andrés Bello.")
                    seccion("Datos que se tratan", "Tu nombre, tu ingreso mensual de referencia, los gastos que registras (monto, categoría, fecha, hora y descripción), los presupuestos que defines y tus valoraciones de los consejos.")
                    seccion("Finalidad", "Los datos se usan exclusivamente para mostrarte tus gastos, calcular proyecciones, enviarte alertas sobre tus presupuestos y entregarte consejos de educación financiera.")
                    seccion("Dónde se guardan", "Todos los datos se almacenan solo en este iPhone, en una base de datos local protegida por el cifrado del sistema operativo. La aplicación no envía tus datos a servidores ni a terceros.")
                    seccion("Fotografías de boletas", "Cuando escaneas una boleta, la imagen se procesa en el dispositivo para leer el monto total y luego se descarta; no se guarda ni se transmite.")
                    seccion("Tus derechos", "Puedes consultar y modificar tus datos en la aplicación en cualquier momento. Para eliminarlos por completo, basta con eliminar la aplicación del dispositivo.")
                }
                .padding(20)
            }
            .navigationTitle("Política de privacidad")
            .navigationBarTitleDisplayMode(.inline)   // Título pequeño y centrado.
            // `.toolbar` agrega botones a la barra de navegación.
            .toolbar {
                // `.confirmationAction` = posición estándar del botón de confirmar (arriba a la derecha).
                ToolbarItem(placement: .confirmationAction) {
                    Button("Cerrar") { cerrar() }
                }
            }
        }
    }

    /// Construye un bloque con título en negrita y texto en gris.
    private func seccion(_ titulo: String, _ texto: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(titulo).font(.headline)
            Text(texto).font(.body).foregroundStyle(.secondary)
        }
    }
}

#Preview {
    PoliticaPrivacidadView()
}
