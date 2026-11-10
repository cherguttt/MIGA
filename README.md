# MIGA — Monitor Inteligente de Gastos y Ahorro

![Pruebas](../../actions/workflows/pruebas.yml/badge.svg)

Aplicación móvil para iOS que ayuda a controlar los gastos personales. Permite registrar gastos de forma manual o fotografiando la boleta, definir presupuestos por categoría, recibir alertas al 70 %, 80 % y 90 % de cada presupuesto, ver la proyección del gasto al cierre del mes, detectar gastos hormiga y recibir consejos de educación financiera.

Proyecto de título de Ingeniería en Computación e Informática, Universidad Andrés Bello (2026). Autor: Christian Hergutt Silva.

## Funcionalidades

- Perfil inicial con aceptación de la política de privacidad (Ley N° 21.719) e ingreso mensual de referencia.
- Bloqueo opcional con Face ID o el código del iPhone.
- Registro de gastos manual o con la cámara (lectura del total de la boleta en el propio dispositivo).
- Presupuestos por categoría y alertas locales al 70 %, 80 % y 90 %, sin duplicados.
- Panel con el gasto acumulado, el gasto diario y la proyección al cierre.
- Ciclo de gastos configurable (por ejemplo, del 25 de un mes al 24 del siguiente).
- Consejo semanal (lunes a las 9:00), consejo al azar al abrir la app y detección de gastos hormiga.

Todos los datos se guardan solo en el iPhone, protegidos por el cifrado del sistema (Data Protection). La app no usa servidores ni conexión a internet.

## Arquitectura

Tres capas con el patrón MVVM:

| Carpeta | Capa | Contenido |
|---|---|---|
| `ControlDeGastos/Presentacion` | Presentación | Vistas SwiftUI, ViewModels y componentes |
| `ControlDeGastos/Logica` | Lógica de negocio | Servicios: transacciones, presupuestos, alertas, motor analítico, OCR, consejos, ciclos, notificaciones y autenticación |
| `ControlDeGastos/Persistencia` | Persistencia | Modelos SwiftData, contenedor de datos y consejos iniciales |
| `ControlDeGastos/Utilidades` | Transversal | Formato de montos y fechas, ciclos de gastos |
| `ControlDeGastosTests` | Pruebas | 104 pruebas unitarias y de integración con XCTest |

## Requisitos

- Mac con Xcode 26 o superior.
- iPhone con iOS 17 o superior (o el simulador de Xcode).
- Cuenta gratuita de desarrollador de Apple para instalar en un iPhone físico.

## Instalación en un iPhone

1. Clonar el repositorio y abrir `ControlDeGastos.xcodeproj` en Xcode.
2. En el target *ControlDeGastos* › *Signing & Capabilities*, elegir tu equipo de desarrollo.
3. Conectar el iPhone, activar *Ajustes › Privacidad y seguridad › Modo de desarrollador* y elegirlo como destino.
4. Ejecutar con ⌘R. La primera vez, confiar en el certificado en *Ajustes › General › VPN y gestión de dispositivos*.

Con una cuenta gratuita, la instalación vence a los 7 días; basta con volver a ejecutar desde Xcode.

## Pruebas

En Xcode: *Product › Test* (⌘U). Desde la Terminal:

```bash
xcodebuild test -project ControlDeGastos.xcodeproj -scheme ControlDeGastos \
  -destination 'platform=iOS Simulator,name=iPhone 16' -enableCodeCoverage YES
```

Las pruebas también se ejecutan automáticamente en GitHub Actions en cada envío (`.github/workflows/pruebas.yml`).

## Control de versiones

- `main` contiene siempre una versión que compila y pasa todas las pruebas.
- Cada historia de usuario se desarrolla en una rama `feature/<descripción>` y se integra a `main` con una *pull request*, después de que pasen las pruebas.
- Los mensajes de commit usan prefijos: `feat` (funcionalidad), `fix` (corrección), `test` (pruebas), `docs` (documentación), `ci` (integración continua) y `chore` (mantenimiento).
- Las versiones siguen el formato `MAYOR.MENOR.PARCHE` y se marcan con etiquetas (`v0.6.0-beta.1`). Los cambios de cada versión se registran en [CHANGELOG.md](CHANGELOG.md).
