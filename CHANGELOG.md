# Registro de cambios

Formato basado en [Keep a Changelog](https://keepachangelog.com/es-ES/1.1.0/). Las versiones siguen el formato `MAYOR.MENOR.PARCHE`.

## [Sin publicar]

- Prueba de usabilidad con el grupo piloto (Sprint 6).

## [0.6.0-beta.1] — 2026-11-09

Primera versión publicada en GitHub. Reúne el incremento construido entre los Sprints 1 y 5 y los cambios aprobados del Sprint 6. Hasta esta versión, el código se guardaba en un repositorio local con un único commit inicial.

### Agregado

- Sprint 1: perfil inicial, consentimiento de privacidad, bloqueo con Face ID o código y registro manual de gastos.
- Sprint 2: presupuestos por categoría y alertas locales al 70 %, 80 % y 90 %, sin duplicados.
- Sprint 3: motor de proyección lineal y panel estadístico con Swift Charts.
- Sprint 4: captura de la boleta con la cámara y lectura del total mediante OCR en el dispositivo.
- Sprint 5: 39 consejos de educación financiera, consejo semanal, consejo al azar al abrir la app, valoración de consejos y detección de gastos hormiga.
- Sprint 6 (solicitud de cambio): ciclo de gastos configurable con ciclo de transición (RF-24).
- Categoría «Pago Créditos» para registrar pagos de deudas, excluida de la detección de gastos hormiga.
- 104 pruebas unitarias y de integración con XCTest.
- Integración continua con GitHub Actions.

### Cambiado

- Nombre visible de la aplicación: de «Control de Gastos» a «MIGA».
- Versión de la app: 0.6.0.
