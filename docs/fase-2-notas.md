# Fase 2 · Captura y lectura — notas para la revisión

Rama `fase-2` (sin fusionar en `main`). **La fase no está aceptada**: el criterio del plan
(«una factura francesa típica se guarda con comercio, fecha, total y TVA correctos sin teclear»)
se comprueba con facturas reales del usuario y en un iPhone real.

## Qué hay
- **Captura** desde el botón «+» (menú): escanear (VisionKit, solo en iPhone real), importar una foto
  (fototeca) o un archivo (PDF o imagen, desde Archivos), o gasto sin justificante.
- **Lectura en el dispositivo**: OCR con Vision (filas reconstruidas para tickets), texto embebido de
  los PDF (o OCR de sus páginas), lector por reglas para Francia (comercio, fecha, total TTC, tipos e
  importe de TVA, varios tipos por ticket, «TVA non applicable art. 293 B») y modelo de Apple
  (FoundationModels, respuesta estructurada) **contrastado con el texto y con las reglas**: un valor del
  modelo que no aparece impreso se descarta; si las reglas tienen un valor seguro, el modelo no lo pisa.
  Límite de 10 s para el modelo y, tras dos fallos seguidos, la sesión sigue solo con reglas.
- **Confirmación obligatoria**: el formulario llega relleno, con una etiqueta por campo
  (Seguro / Revisar / Dudoso) y la indicación de cómo se leyó (reglas o Apple Intelligence).
  Con varios tipos de TVA se guarda la TVA total impresa.
- **Justificantes**: archivo original (JPEG ≤ 2400 px o PDF; un escaneo de varias páginas se guarda
  como PDF) y miniatura, en una carpeta propia con protección `.complete`; la base solo guarda los
  nombres. En el detalle: tarjeta con miniatura, «Texto leído», visor a pantalla completa (Quick Look
  sobre una **copia temporal** con nombre legible, que se borra al cerrar: una anotación nunca toca el
  original), añadir, sustituir y quitar (quitar un justificante de un gasto Pro lo deja «Justificante
  pendiente»). Al arrancar se borran los archivos huérfanos.
- **Facturas reales**: `TestData/Real/` (ignorada por git) + `Tools/receipts/read-real.sh` → informe
  campo a campo en `TestData/Real/report.md`, con reglas y modelo por separado y el número de documentos
  en que el modelo respondió de verdad.

## Medidas (siempre sobre el conjunto sintético de 20 facturas de `TestData/Receipts`)
Las facturas sintéticas son pruebas de regresión, **no sirven para aceptar la fase**.

| Lectura | Comercio | Fecha | Total | Tipos de TVA | Importe TVA |
|---|---|---|---|---|---|
| Solo reglas (20 documentos) | 20/20 | 20/20 | 20/20 | 20/20 | 18/18 |
| Modelo de Apple **solo**, antes del contraste (20 documentos en que respondió) | 19/20 | 18/20 | 18/20 | 10/20 | 14/18 |
| Combinado reglas + modelo (esos 20 documentos) | 20/20 | 20/20 | 20/20 | 20/20 | 18/18 |

- En el simulador el modelo **sí respondió**: 20 de 20 en la batería completa final y 19 de 20 en una
  ejecución anterior (1 fallo: «InferenceError::operationNotAllowed::Simulator is not supported», en la
  primera petición; ahí el modelo solo sacó 18/19, 17/19, 17/19, 9/19 y 13/17). El simulador usa
  Apple Intelligence del Mac anfitrión, así que estas cifras **no** representan un iPhone.
- En la app (simulador): una lectura falló y siguió con reglas en ~1 s sin error visible; otra respondió
  con el modelo en 4 s. Con el modelo desactivado (`-BifazDisableModel YES`, solo Debug): 1 s.
- El modelo solo es más débil que las reglas en tipos de TVA (9/19: no expresa varios tipos) y en
  totales/fechas con varios importes o fechas impresos; el contraste con las reglas lo corrige.

## Cambios respecto al plan (aprobados por el manager)
- **Origen del gasto**: «Escaneado» pasa a llamarse «Desde un justificante» (cubre escaneo, foto y PDF);
  el valor guardado sigue siendo `scanner`.
- Nada más cambia de alcance. La extensión de compartir sigue en la fase 8.

## Mejoras de la revisión del manager (rama `fase-2`)
1. **Categoría propuesta** tras la lectura: la última usada con ese comercio y, si no hay, una tabla de
   marcas y palabras francesas (supermercados, carburante, peajes y parking, tren y taxi, restaurantes,
   farmacia, telefonía, software, hotel). Sin pista clara o con pistas contradictorias, nada. Etiqueta
   «Proposée»; otro toque la cambia; al cambiar de espacio se propone la equivalente (TotalEnergies:
   «Transports» en Perso, «Véhicule et carburant» en Pro). Supermercado o farmacia en Pro: nada.
2. **Nombre del comercio**: una línea que empieza por una marca conocida se muestra como la marca
   («TotalEnergies», «SNCF», «G7», «Carrefour City»), también si la da el modelo. Las líneas en mayúsculas
   se recomponen sin romper siglas (SNCF, IKEA, BHV, A6) y con «de/du/et» en minúscula; como esas
   mayúsculas son una suposición, ese nombre queda «À vérifier», nunca «Sûr». Probado nombre a nombre en
   las 20 facturas sintéticas.
3. **Pantalla de lectura** opaca en claro y oscuro, sin fundido de entrada.
4. **Descartar**: la X pide confirmación con un justificante leído o con cambios sin guardar (y se bloquea
   el deslizar para cerrar); un gasto vacío se cierra directo. Sin archivos huérfanos al descartar.
5. **Menú «+»**: el botón deja de ser Liquid Glass tintado (el menú se fundía con su tinte oscuro); ahora
   es un disco plano de 56 pt y el menú se abre y cierra sobre fondo claro. Comprobado fotograma a
   fotograma en un vídeo del simulador.

Capturas en `docs/capturas/fase-2-mejoras/` (francés; 2b y 3b en oscuro).

## Pendiente de iPhone real
- Escáner de documentos (VisionKit no está en el simulador): recorte, enderezado, varias páginas.
- Modelo de Apple en un iPhone con Apple Intelligence: tasa de respuesta, tiempo y acierto del modelo solo.
- Protección `.complete` de los justificantes (el simulador no la aplica): con el iPhone bloqueado
  no deben poder leerse.
- Rendimiento del OCR con fotos de 12–48 MP y tickets térmicos reales.

## Pendiente de facturas reales
- Pasar las facturas y tickets del usuario por `Tools/receipts/read-real.sh` (con `expected.json`)
  y ajustar las reglas con los fallos. Es el criterio de aceptación de la fase.
