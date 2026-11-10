//
//  AjustesView.swift
//  ControlDeGastos
//
//  CAPA: Presentación — pestaña «Ajustes»: perfil, ingreso mensual de referencia,
//  ciclo de gastos, seguridad, notificaciones (consejo semanal, Sprint 5) y privacidad.
//

import SwiftUI
import SwiftData

/// Pestaña Ajustes.
struct AjustesView: View {
    @Query private var perfiles: [PerfilUsuario]

    var body: some View {
        NavigationStack {
            Group {
                if let perfil = perfiles.first {
                    FormularioAjustes(perfil: perfil)
                } else {
                    ContentUnavailableView("Sin perfil", systemImage: "person.crop.circle.badge.questionmark")
                }
            }
            .navigationTitle("Ajustes")
        }
    }
}

/// Formulario de edición.
private struct FormularioAjustes: View {
    /// `@Bindable` permite crear bindings ($) hacia las propiedades de un objeto @Model.
    @Bindable var perfil: PerfilUsuario
    @Environment(\.modelContext) private var contexto

    /// ViewModel de la pantalla (patrón MVVM): guarda el estado y ejecuta las acciones.
    @State private var modelo = AjustesViewModel()

    /// Mostrar un consejo al azar al abrir la app (misma clave que usa PrincipalView).
    @AppStorage("consejoAlAbrir") private var consejoAlAbrir = true

    var body: some View {
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
                        .onChange(of: modelo.ingresoTexto) { _, nuevo in
                            modelo.ingresoCambio(nuevo, en: perfil)
                        }
                }
                LabeledContent("Moneda", value: perfil.moneda)
            }

            Section {
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

            Section {
                Picker("Inicio del ciclo", selection: $modelo.diaCiclo) {
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
                Text(AjustesViewModel.descripcionCiclo(CalendarioCiclos.compartido))
            }

            Section {
                LabeledContent("Permiso", value: perfil.notificacionesActivas ? "Autorizadas" : "No autorizadas")
                Toggle("Consejo semanal", isOn: $perfil.consejoSemanalActivo)
                    .onChange(of: perfil.consejoSemanalActivo) { _, activo in
                        modelo.cambiarConsejoSemanal(activo, contexto: contexto)
                    }
                LabeledContent("Día y hora", value: "Lunes, 9:00")
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
        .onAppear {
            modelo.cargar(desde: perfil)
            modelo.cargarCiclo()
        }
        .alert("¿Cambiar el inicio del ciclo?", isPresented: Binding(
            get: { modelo.diaPorConfirmar != nil },
            set: { _ in }
        )) {
            Button("Cambiar") { modelo.confirmarCiclo(contexto: contexto) }
            Button("Cancelar", role: .cancel) { modelo.cancelarCiclo() }
        } message: {
            Text(modelo.mensajeCiclo)
        }
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
