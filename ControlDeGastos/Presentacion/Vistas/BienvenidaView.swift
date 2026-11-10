//
//  BienvenidaView.swift
//  ControlDeGastos
//
//  CAPA: Presentación — pantalla de primer inicio (CU-01): presentación de la app,
//  perfil inicial, consentimiento de privacidad (Ley N° 21.719) y bloqueo opcional con Face ID.
//
//  FLUJO DEL CU-01 (sección 4.2.1 del portafolio):
//  1. Se muestra la bienvenida con la política de privacidad.
//  2. El usuario acepta la política (obligatorio para continuar).
//  3. Ingresa su nombre y su ingreso mensual de referencia.
//  4. Al tocar «Comenzar», se solicita el permiso de notificaciones.
//  5. Si eligió el bloqueo opcional, se verifica Face ID o el código.
//  6. Se crea el PerfilUsuario con la fecha del consentimiento y se muestra «Inicio».
//

import SwiftUI
import SwiftData

struct BienvenidaView: View {

    /// Closure que se ejecuta cuando el perfil quedó guardado correctamente.
    let alCompletar: () -> Void

    /// Contexto de la base de datos, entregado por `.modelContainer` en ControlDeGastosApp.
    @Environment(\.modelContext) private var contexto

    // Estado del formulario: cada campo de la pantalla está enlazado a una de estas variables.
    @State private var nombre = ""
    @State private var ingresoTexto = ""
    @State private var aceptaPolitica = false
    @State private var activarBloqueo = false
    @State private var mostrarPolitica = false   // Controla si se muestra la hoja de la política.
    @State private var guardando = false         // Evita que se toque «Comenzar» dos veces.
    @State private var mensajeError: String?

    /// Ingreso convertido a número (nil si el campo está vacío).
    private var ingreso: Decimal? { Formato.monto(desde: ingresoTexto) }

    /// El botón «Comenzar» solo se habilita si TODO esto se cumple (`&&` = «y»):
    /// nombre no vacío, ingreso mayor a cero, política aceptada y no se está guardando.
    private var puedeComenzar: Bool {
        !nombre.trimmingCharacters(in: .whitespaces).isEmpty
            && (ingreso ?? 0) > 0          // Si `ingreso` es nil, se usa 0 → no cumple.
            && aceptaPolitica
            && !guardando
    }

    var body: some View {
        // `ScrollView` permite desplazar el contenido si no cabe en la pantalla.
        ScrollView {
            VStack(spacing: 20) {
                // Para no tener un `body` gigante, dividimos la pantalla en secciones
                // (propiedades privadas definidas más abajo).
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
                .disabled(!puedeComenzar)   // Deshabilitado (gris) mientras falten datos.

                if !aceptaPolitica {
                    Text("Para continuar debes aceptar la política de privacidad.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(20)
        }
        .background(Color(.systemGroupedBackground))   // Gris claro típico de iOS.
        // `.sheet` muestra una hoja deslizable desde abajo mientras `mostrarPolitica` sea true.
        // Al cerrarla, SwiftUI vuelve a poner la variable en false gracias al binding ($).
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
                // Fondo con degradado azul y esquinas redondeadas.
                .background(.blue.gradient, in: RoundedRectangle(cornerRadius: 20))
            Text("MIGA")
                .font(.largeTitle.bold())
            // Significado de la sigla del nombre de la app.
            Text("Monitor Inteligente de Gastos y Ahorro")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text("Registra tus gastos, controla tus presupuestos y recibe alertas antes de excederte.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 20)   // Margen solo arriba.
    }

    /// Tarjeta con las tres características principales de la app.
    private var caracteristicas: some View {
        VStack(alignment: .leading, spacing: 14) {   // `alignment: .leading` = alineado a la izquierda.
            filaCaracteristica("doc.text.fill", .blue, "Registro en segundos", "Manual o fotografiando tu boleta")
            filaCaracteristica("bell.fill", .orange, "Alertas a tiempo", "Al 70 %, 80 % y 90 % de cada presupuesto")
            filaCaracteristica("lock.shield.fill", .green, "Tus datos solo en tu iPhone", "Sin servidores externos · cifrado del sistema")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(.background, in: RoundedRectangle(cornerRadius: 14))   // Tarjeta blanca.
    }

    /// Función que FABRICA una fila (ícono + título + detalle). Así no repetimos el mismo
    /// código tres veces: es el principio DRY («Don't Repeat Yourself»).
    private func filaCaracteristica(_ icono: String, _ color: Color, _ titulo: String, _ detalle: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icono)
                .foregroundStyle(color)
                .frame(width: 36, height: 36)
                .background(color.opacity(0.15), in: Circle())   // Círculo de color suave (15 %).
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
                    // `text: $nombre` enlaza el campo con la variable: lo que se escribe
                    // se guarda en `nombre`, y si `nombre` cambia, el campo se actualiza.
                    TextField("Ingresa tu nombre", text: $nombre)
                        .multilineTextAlignment(.trailing)   // Texto alineado a la derecha.
                        .textContentType(.givenName)         // Sugerencia de autocompletado de iOS.
                }
                .padding(.vertical, 12)
                Divider()   // Línea separadora.
                HStack {
                    Text("Ingreso mensual")
                    Spacer()
                    Text("$").foregroundStyle(.secondary)
                    TextField("0", text: $ingresoTexto)
                        .keyboardType(.numberPad)            // Teclado solo numérico.
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 140)
                        // Cada vez que el texto cambia, le ponemos los puntos de miles.
                        .onChange(of: ingresoTexto) { _, nuevo in
                            let normalizado = Formato.miles(nuevo)
                            if normalizado != nuevo { ingresoTexto = normalizado }
                        }
                }
                .padding(.vertical, 12)
                // Solo mostramos el interruptor si el iPhone tiene Face ID/Touch ID o código.
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
                aceptaPolitica.toggle()   // `toggle()` invierte un Bool: true ↔ false.
            } label: {
                // El ícono cambia según el estado: casilla marcada o vacía.
                Image(systemName: aceptaPolitica ? "checkmark.square.fill" : "square")
                    .font(.title2)
                    .foregroundStyle(aceptaPolitica ? .blue : .secondary)
            }
            // Texto que lee VoiceOver (accesibilidad para personas con discapacidad visual).
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
        // `defer` ejecuta su bloque justo ANTES de salir de la función, pase lo que pase.
        // Así garantizamos que `guardando` vuelva a false aunque ocurra un error.
        defer { guardando = false }

        // CU-01, paso 4: iOS muestra su cuadro de permiso de notificaciones; esperamos la respuesta.
        let notificaciones = await ServicioNotificaciones.solicitarPermiso()

        // CU-01, paso 5: si eligió el bloqueo, se verifica que la autenticación funcione
        // antes de activarlo (si falla, el perfil se crea igual, pero sin bloqueo).
        var bloqueo = false
        if activarBloqueo {
            bloqueo = await ServicioAutenticacion.autenticar(motivo: "Confirma tu identidad para activar el bloqueo.")
        }

        // Creamos el perfil con los datos del formulario.
        let perfil = PerfilUsuario(
            nombre: nombre.trimmingCharacters(in: .whitespaces),
            ingresoMensualReferencia: ingreso,
            consentimientoAceptado: true,
            fechaConsentimiento: .now,   // Queda registro de CUÁNDO se aceptó (Ley N° 21.719).
            notificacionesActivas: notificaciones,
            bloqueoBiometricoActivo: bloqueo
        )
        contexto.insert(perfil)
        do {
            try contexto.save()   // Escribe el perfil en SQLite.
            alCompletar()
            // No hace falta navegar: el @Query de ContentView detecta el nuevo perfil
            // y la app cambia sola a la pantalla principal.
        } catch {
            mensajeError = "No se pudo guardar el perfil: \(error.localizedDescription)"
        }
    }
}

#Preview {
    BienvenidaView(alCompletar: {})
        .modelContainer(ContenedorDatos.crear(enMemoria: true))
}
