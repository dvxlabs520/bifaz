# Datos de prueba de la lectura de facturas

- `Receipts/`: 20 facturas y tickets **sintéticos** (generados con `Tools/receipts/render.py` a partir de
  `BifazKit/Tests/BifazReadingTests/Fixtures/*.json`). Sirven de pruebas de regresión, no para aceptar la fase 2.
- `Real/`: facturas y tickets **reales** del usuario. La carpeta está en `.gitignore` (documentos personales):
  nunca se sube al repositorio.

## Probar con facturas reales
1. Copia fotos (JPEG, PNG, HEIC) o PDF en `TestData/Real/`.
2. Opcional, para medir el acierto: crea `TestData/Real/expected.json` con lo que dice cada documento:
   ```json
   {"ticket-monoprix.jpg": {"merchant": "Monoprix", "date": "2026-11-12", "total": "27.27",
                            "vatRates": ["0.20", "0.055"], "vatAmount": "3.08"}}
   ```
3. Con un simulador de iPhone arrancado: `Tools/receipts/read-real.sh`
4. El informe (campo a campo, reglas y modelo de Apple por separado) queda en `TestData/Real/report.md`.
