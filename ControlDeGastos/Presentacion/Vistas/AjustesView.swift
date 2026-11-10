//
//  AjustesView.swift
//  ControlDeGastos
//
//  CAPA: Presentación — pestaña «Ajustes»: perfil, ingreso mensual de referencia,
//  ciclo de gastos, seguridad, notificaciones (consejo semanal, Sprint 5) y privacidad.
//
//  Este archivo tiene DOS vistas:
//  1. `AjustesView`: busca el perfil en la base de datos.
//  2. `FormularioAjustes`: muestra y edita ese perfil.
//  Se separan porque `@Bindable` necesita recibir un perfil que ya exista (no opcional).
//  El estado y las acciones de la pantalla viven en AjustesViewModel (patrón MVVM).
//

import SwiftUI
import SwiftData

struct AjustesView: View {
    @Query private var perfiles: [PerfilUsuario]

    var body: some View {
        NavigationStack {
            Group {
                if let perfil = perfiles.first {
                    FormularioAjustes(perfil: perfil)
                } else {
                    // Caso que no debería ocurrir (sin perfil no se llega a esta pantalla),
                    // pero lo manejamos para que la app nunca quede en blanco.
                    ContentUnavailableView("Sin perfil", systemImage: "person.crop.circle.badge.questionmark")
                }
            }
            .navigationTitle("Ajustes")
        }
    }
}

/// Formulario de edición. `private` = solo se usa dentro de este archivo.
private struct FormularioAjustes: View {

    /// `@Bindable` permite crear bindings ($) hacia las propiedades de un objeto @Model.
    /// Así `$perfil.nombre` conecta el campo de texto DIRECTAMENTE con la base de datos:
    /// al escribir, el perfil se modifica.
    @Bindable var perfil: PerfilUsuario
    @Environment(\.modelContext) private var contexto

    /// ViewModel de la pantalla (patrón MVVM): guarda el estado y ejecuta las acciones.
    @State private var modelo = AjustesViewModel()

    /// Mostrar un consejo al azar al abrir la app (misma clave que usa PrincipalView).
    @AppStorage("consejoAlAbrir") private var consejoAlAbrir = true

    var body: some View {
        // `Form` es el formulario con secciones agrupadas típico de la app Configuración de iOS.
        Form {
            Section("Perfil") {
                HStack {
                    Text("Nombre")
                    TextField("Nombre", text: $perfil.nombre)
                        .multilineTextAlignment(.trailing)
                }
                HStack {
                    Text("Ingreso mensual")
                    Spacer()
                    Text("$").foregroundStyle(.secondary)
                    TextField("0", text: $modelo.ingresoTexto)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 140)
                        // Cada cambio se delega al ViewModel, que formatea y actualiza el perfil.
                        .onChange(of: modelo.ingresoTexto) { _, nuevo in
                            modelo.ingresoCambio(nuevo, en: perfil)
                        }
                }
                // `LabeledContent` = fila de solo lectura con etiqueta a la izquierda y valor a la derecha.
                LabeledContent("Moneda", value: perfil.moneda)
            }

            // Esta sección usa la forma larga: contenido + `header` (encabezado) + `footer` (pie).
            Section {
                // Binding PERSONALIZADO: no cambiamos el valor directamente al tocar el interruptor.
                // - get: el interruptor muestra el valor guardado en el perfil.
                // - set: en vez de guardarlo, el ViewModel primero pide Face ID.
                //   Si la autenticación falla, el valor no cambia y el interruptor vuelve a su lugar.
                Toggle("Bloqueo con \(ServicioAutenticacion.nombreMetodo)", isOn: Binding(
                    get: { perfil.bloqueoBiometricoActivo },
                    set: { nuevoValor in
                        Task { await modelo.cambiarBloqueo(nuevoValor, en: perfil, contexto: contexto) }
                    }
                ))
                .disabled(!ServicioAutenticacion.disponible)
            } header: {
                Text("Seguridad")
            } footer: {
                if ServicioAutenticacion.disponible {
                    Text("Se solicitará al abrir la aplicación y al volver a ella.")
                } else {
                    Text("Configura un código o Face ID en el dispositivo para activar el bloqueo.")
                }
            }

            // Ciclo de gastos: el usuario elige el día en que empieza (por ejemplo, el día de pago).
            Section {
                Picker("Inicio del ciclo", selection: $modelo.diaCiclo) {
                    // `ForEach` sobre un rango: una opción por cada día permitido (1 a 28).
                    ForEach(Array(CalendarioCiclos.diasPermitidos), id: \.self) { dia in
                        Text("Día \(dia)").tag(dia)
                    }
                }
                .onChange(of: modelo.diaCiclo) { _, nuevo in
                    modelo.diaCicloCambio(nuevo, contexto: contexto)
                }
            } header: {
                Text("Ciclo de gastos")
            } footer: {
                // Se lee el calendario compartido (observable): el texto se actualiza solo.
                Text(AjustesViewModel.descripcionCiclo(CalendarioCiclos.compartido))
            }

            Section {
                LabeledContent("Permiso", value: perfil.notificacionesActivas ? "Autorizadas" : "No autorizadas")
                // Sprint 5 (CU-07, flujo alternativo): activar o desactivar el consejo semanal.
                Toggle("Consejo semanal", isOn: $perfil.consejoSemanalActivo)
                    .onChange(of: perfil.consejoSemanalActivo) { _, activo in
                        modelo.cambiarConsejoSemanal(activo, contexto: contexto)
                    }
                LabeledContent("Día y hora", value: "Lunes, 9:00")
                // Consejo emergente al abrir la app (se guarda en las preferencias de la app).
                Toggle("Consejo al abrir la app", isOn: $consejoAlAbrir)
            } header: {
                Text("Notificaciones")
            } footer: {
                Text("Si desactivas los consejos, siguen disponibles en la pestaña Educación.")
            }

            Section {
                Label("Datos almacenados solo en este iPhone", systemImage: "lock.shield")
                if let fecha = perfil.fechaConsentimiento {
                    LabeledContent("Política aceptada", value: Formato.fechaHora(fecha))
                }
                Button("Ver política de privacidad") { modelo.mostrarPolitica = true }
            } header: {
                Text("Privacidad")
            } footer: {
                Text("Tus datos se guardan en una base de datos local cifrada por el sistema y no se envían a servidores externos.")
            }

            if let mensaje = modelo.mensaje {
                Section { Text(mensaje).foregroundStyle(.secondary) }
            }
        }
        // `.onAppear`: al mostrarse la pantalla, el ViewModel carga el ingreso guardado.
        .onAppear {
            modelo.cargar(desde: perfil)
            modelo.cargarCiclo()
        }
        // Confirmación antes de cambiar el ciclo (explica el ciclo de transición).
        .alert("¿Cambiar el inicio del ciclo?", isPresented: Binding(
            get: { modelo.diaPorConfirmar != nil },
            set: { _ in }   // Se cierra solo: ambos botones dejan `diaPorConfirmar` en nil.
        )) {
            Button("Cambiar") { modelo.confirmarCiclo(contexto: contexto) }
            Button("Cancelar", role: .cancel) { modelo.cancelarCiclo() }
        } message: {
            Text(modelo.mensajeCiclo)
        }
        // `.onDisappear`: al salir de la pestaña, guardamos los cambios en SQLite.
        // (SwiftData también guarda automáticamente cada cierto tiempo; esto lo asegura).
        .onDisappear { modelo.guardar(en: contexto) }
        .sheet(isPresented: $modelo.mostrarPolitica) {
            PoliticaPrivacidadView()
        }
    }
}

#Preview {
    AjustesView()
        .modelContainer(DatosDePrueba.contenedor)
}
