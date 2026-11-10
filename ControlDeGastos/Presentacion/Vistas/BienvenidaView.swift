//
//  BienvenidaView.swift
//  ControlDeGastos
//
//  CAPA: Presentación — pantalla de primer inicio (CU-01): presentación de la app,
//  perfil inicial, consentimiento de privacidad (Ley N° 21.719) y bloqueo opcional con Face ID.
//

import SwiftUI
import SwiftData

/// Pantalla de primer inicio: perfil y aceptación de la política de privacidad (CU-01).
struct BienvenidaView: View {
    /// Closure que se ejecuta cuando el perfil quedó guardado correctamente.
    let alCompletar: () -> Void

    /// Contexto de la base de datos, entregado por `.modelContainer` en ControlDeGastosApp.
    @Environment(\.modelContext) private var contexto

    @State private var nombre = ""
    @State private var ingresoTexto = ""
    @State private var aceptaPolitica = false
    @State private var activarBloqueo = false
    @State private var mostrarPolitica = false
    @State private var guardando = false
    @State private var mensajeError: String?

    /// Ingreso convertido a número (nil si el campo está vacío).
    private var ingreso: Decimal? { Formato.monto(desde: ingresoTexto) }

    /// El botón «Comenzar» solo se habilita si TODO esto se cumple (`&&` = «y»): nombre no vacío, ingreso
    /// mayor a cero, política aceptada y no se está guardando.
    private var puedeComenzar: Bool {
        !nombre.trimmingCharacters(in: .whitespaces).isEmpty
            && (ingreso ?? 0) > 0
            && aceptaPolitica
            && !guardando
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                encabezado
                caracteristicas
                formularioPerfil
                consentimiento
                if let mensajeError {
                    Text(mensajeError)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
                Button {
                    Task { await comenzar() }
                } label: {
                    Text("Comenzar")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(!puedeComenzar)

                if !aceptaPolitica {
                    Text("Para continuar debes aceptar la política de privacidad.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(20)
        }
        .background(Color(.systemGroupedBackground))
        .sheet(isPresented: $mostrarPolitica) {
            PoliticaPrivacidadView()
        }
    }

    // MARK: - Secciones

    /// Logo, título y frase de presentación.
    private var encabezado: some View {
        VStack(spacing: 10) {
            Image(systemName: "wallet.bifold.fill")
                .font(.system(size: 40))
                .foregroundStyle(.white)
                .frame(width: 80, height: 80)
                .background(.blue.gradient, in: RoundedRectangle(cornerRadius: 20))
            Text("MIGA")
                .font(.largeTitle.bold())
            Text("Monitor Inteligente de Gastos y Ahorro")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text("Registra tus gastos, controla tus presupuestos y recibe alertas antes de excederte.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 20)
    }

    /// Tarjeta con las tres características principales de la app.
    private var caracteristicas: some View {
        VStack(alignment: .leading, spacing: 14) {
            filaCaracteristica("doc.text.fill", .blue, "Registro en segundos", "Manual o fotografiando tu boleta")
            filaCaracteristica("bell.fill", .orange, "Alertas a tiempo", "Al 70 %, 80 % y 90 % de cada presupuesto")
            filaCaracteristica("lock.shield.fill", .green, "Tus datos solo en tu iPhone", "Sin servidores externos · cifrado del sistema")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(.background, in: RoundedRectangle(cornerRadius: 14))
    }

    /// Función que FABRICA una fila (ícono + título + detalle).
    private func filaCaracteristica(_ icono: String, _ color: Color, _ titulo: String, _ detalle: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icono)
                .foregroundStyle(color)
                .frame(width: 36, height: 36)
                .background(color.opacity(0.15), in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(titulo).font(.subheadline.bold())
                Text(detalle).font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    /// Campos de nombre, ingreso y (si el iPhone lo permite) el interruptor de Face ID.
    private var formularioPerfil: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("TU PERFIL")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.leading, 4)
            VStack(spacing: 0) {
                HStack {
                    Text("Nombre")
                    TextField("Ingresa tu nombre", text: $nombre)
                        .multilineTextAlignment(.trailing)
                        .textContentType(.givenName)
                }
                .padding(.vertical, 12)
                Divider()
                HStack {
                    Text("Ingreso mensual")
                    Spacer()
                    Text("$").foregroundStyle(.secondary)
                    TextField("0", text: $ingresoTexto)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 140)
                        .onChange(of: ingresoTexto) { _, nuevo in
                            let normalizado = Formato.miles(nuevo)
                            if normalizado != nuevo { ingresoTexto = normalizado }
                        }
                }
                .padding(.vertical, 12)
                if ServicioAutenticacion.disponible {
                    Divider()
                    Toggle("Proteger con \(ServicioAutenticacion.nombreMetodo)", isOn: $activarBloqueo)
                        .padding(.vertical, 8)
                }
            }
            .padding(.horizontal, 16)
            .background(.background, in: RoundedRectangle(cornerRadius: 14))
        }
    }

    /// Casilla de aceptación de la política de privacidad (consentimiento explícito).
    private var consentimiento: some View {
        HStack(alignment: .top, spacing: 12) {
            Button {
                aceptaPolitica.toggle()
            } label: {
                Image(systemName: aceptaPolitica ? "checkmark.square.fill" : "square")
                    .font(.title2)
                    .foregroundStyle(aceptaPolitica ? .blue : .secondary)
            }
            .accessibilityLabel("Acepto la política de privacidad")
            VStack(alignment: .leading, spacing: 6) {
                Text("Acepto la política de privacidad y autorizo el tratamiento de mis datos financieros únicamente en este dispositivo (Ley N° 21.719).")
                    .font(.footnote)
                Button("Leer la política de privacidad") { mostrarPolitica = true }
                    .font(.footnote.weight(.semibold))
            }
        }
        .padding(16)
        .background(.background, in: RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Acción principal

    /// Se ejecuta al tocar «Comenzar» (CU-01, pasos 4 a 6).
    private func comenzar() async {
        guard puedeComenzar, let ingreso else { return }
        guardando = true
        defer { guardando = false }

        let notificaciones = await ServicioNotificaciones.solicitarPermiso()

        var bloqueo = false
        if activarBloqueo {
            bloqueo = await ServicioAutenticacion.autenticar(motivo: "Confirma tu identidad para activar el bloqueo.")
        }

        let perfil = PerfilUsuario(
            nombre: nombre.trimmingCharacters(in: .whitespaces),
            ingresoMensualReferencia: ingreso,
            consentimientoAceptado: true,
            fechaConsentimiento: .now,
            notificacionesActivas: notificaciones,
            bloqueoBiometricoActivo: bloqueo
        )
        contexto.insert(perfil)
        do {
            try contexto.save()
            alCompletar()
        } catch {
            mensajeError = "No se pudo guardar el perfil: \(error.localizedDescription)"
        }
    }
}

#Preview {
    BienvenidaView(alCompletar: {})
        .modelContainer(ContenedorDatos.crear(enMemoria: true))
}
