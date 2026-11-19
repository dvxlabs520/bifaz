# Fase 5 · Tramo 5a: rediseño editorial «cálida» y entrada en una frase. Notas para la revisión

Trabajo en `fase-5`, a partir de la sección 3 de PLAN.md. No se ha copiado ni descargado nada de outlayr: ni código, ni iconos, ni textos, ni ilustraciones. Se conservan los iconos propios, la moneda, el cobalto Pro y el terracota Personal.

Por la regla del usuario, nada se ha probado a mano en el simulador. Todo se confirma con pruebas automáticas: unitarias en BifazKit y, cuando no hay otra forma, de interfaz.

## Tokens v2 (valores finales)

| Token | Claro | Oscuro |
|---|---|---|
| ink | 1A1814 | F3EFE6 |
| inkSecondary | 6B655A | A39C8F |
| paper | F4F1EA | 14130F |
| surface | FBFAF6 | 1D1B17 |
| surfaceMuted | ECE8DF | 26231E |
| hairline | E4DFD4 | 2E2A23 |
| pro | 2747D8 | sin cambios |
| personal | **B24319** (plan: B8451A) | sin cambios |
| success | **19764A** (plan: 1B7F50) | sin cambios |
| warning | **8D5D18** (plan: 98641A) | sin cambios |
| error | **BE3049** (plan: C4314B) | sin cambios |

- Los valores en negrita se oscurecieron lo mínimo para llegar a AA (4,5:1) sobre el papel cálido y sobre sus tintes. Con los valores del plan, success y warning se quedaban en 4,43 y 4,46.
- `surfaceMuted` es un valor cálido nuevo.
- `ContrastTests` (PaletteV2Tests) comprueba todos los pares en claro y en oscuro.
- `Color.bifazShadow` (negro al 14 %) es la sombra del botón «+».
- `LooseColorTests` falla si aparece `Color.white`, `.black` o `Color(red:` fuera de BifazDesign.

## Tipografía

- Etiquetas de datos en SF Mono: `Font.bifazData` y `.bifazDataLabel()` (mayúsculas, tracking 0,6, tinta secundaria).
- Estilo de contexto en New York preparado (`.bifazContextSentence()`); las frases llegan en la fase 6.
- Importes en tamaño grande y medio con los decimales atenuados (`AmountParts`, con pruebas) y `contentTransition(.numericText())`.

## Lógica en BifazKit (con pruebas unitarias)

- `ExpenseSentence`: la frase en 3 idiomas, con piezas accesibles. Las plantillas están en el catálogo y no son calcos:
  - es: «Gasté 42,00 € en Carrefour para Supermercado · Personal · hoy»
  - fr: «J’ai dépensé 42,00 € chez Carrefour, en Courses · Personnel · aujourd’hui»
  - en: «I spent €42.00 at Carrefour on Groceries · Personal · today»
  - Sin comercio ni categoría, se ven «un comercio / un commerçant / a shop» y «una categoría / une catégorie / a category» como marcadores de posición.
  - La fecha: hoy/ayer, y si no «el 3 nov.». La moneda extranjera sale en la cifra («48,00 $US»).
  - Etiquetas de VoiceOver por pieza: «Importe, 42,00 €», «Comercio, Carrefour» y «sin indicar» cuando falta.
- `Monogram.initial`: acentos, números, nombres vacíos o de una letra.
- `ExpenseGrouping.byDay`: límites de día y de zona horaria; la suma de los días es el total del mes.
- `SummaryCalculator.cumulativeTrend`: hasta hoy en el mes actual, el mes entero en meses pasados, vacío en meses futuros.
- `MerchantMemory.recentMerchants`: los comercios recientes como chips.

## Componentes v2 (BifazDesign/Components/V2)

- `MonogramAvatar`:
  - la inicial va en tinta (no en el color del espacio) sobre el tinte del espacio, con el distintivo del espacio en la esquina;
  - el color del espacio lo da el distintivo, y la letra pequeña necesita el margen de contraste.
- `TrendLine`, `HeroFigure`, `DayHeader` (Hoy / Ayer / «lundi 16 nov.» y total del día), `OptionalChip` y `SentenceView` (la frase con su propio layout de ajuste de línea).
- `ExpenseRow` usa el avatar con inicial y tiene el modo `timeOnly` (hora en vez de fecha).

## Pantallas

- **Formulario (nuevo, edición, confirmación de lectura): la frase arriba.** Cada pieza abre su selector debajo:
  - importe con teclado decimal y moneda;
  - comercio, con los recientes como chips;
  - categorías, espacio y fecha (calendario).

  Debajo de la frase van los chips opcionales:
  - TVA (solo Pro y si se declara TVA);
  - cliente · proyecto (solo Pro);
  - nota;
  - repetir (gasto nuevo en euros: al guardar crea la regla desde el periodo siguiente);
  - justificante: escanear, foto o archivo; en un gasto manual rellena importe y comercio solo si están vacíos;
  - moneda.

  No se pierde nada de lo que hacía el formulario: tipo BCE, varios tipos de TVA, etiquetas, propuestas de categoría y de etiquetas, confianza de lectura por campo, confirmación antes de descartar, borrar e identificadores de prueba.
- **Resumen:**
  - cabecera compacta (título pequeño centrado);
  - cifra del mes con línea de tendencia acumulada;
  - comparación y reparto Pro/Personal;
  - títulos de sección en etiquetas mono.
- **Gastos:**
  - cabecera compacta con búsqueda y filtro;
  - lista agrupada por día con el total del día y la hora en cada fila.
- **Menú «+»:** una línea de descripción bajo cada opción (≤ 40 caracteres, con prueba).

## Auditoría de accesibilidad (correcciones pedidas en la revisión de la fase 4)

- Corre en tres simuladores: iPhone 17e, iPhone 17 e iPhone 18 Pro.
- Las exclusiones se basan en el marco real de `app.navigationBars` y `app.tabBars`, y en el del botón «+», no en márgenes fijos. Nuestro texto justo bajo la cabecera compacta sí se comprueba.
- Se quitó la exclusión de contraste de Tout/Pro/Perso; queda solo la de Dynamic Type (`ViewThatFits`). La de Dynamic Type ahora no depende del tipo de elemento: en el 17e los chips salen como `StaticText`.
- **Contraste sin elemento** («Contrast failed for SwiftUI.AccessibilityNode»): sale en Résumé y Dépenses en reposo en los tres simuladores. Descartado con un experimento de eliminación en el iPhone 17, quitando cada vez una de estas cosas:
  - la letra del avatar;
  - su distintivo;
  - el selector de espacio;
  - el estilo mono de las etiquetas.

  En los cuatro casos el aviso seguía. El origen no está expuesto a XCUITest, así que la exclusión general se mantiene, documentada aquí. En el mismo experimento, la letra del avatar con opacidad 0 sí aparecía como elemento con contraste fallido; eso llevó a ponerla en tinta, que es una corrección decidida.
- **«Potentially inaccessible text»** (punto 2): una causa encontrada y corregida; queda un resto sin identificar.
  - Causa corregida: la fila de un gasto Pro sin justificante muestra «Justificatif manquant», pero VoiceOver decía «Justificatif en attente». La auditoría compara el texto dibujado con la etiqueta. Ahora la fila dice lo que muestra, que es también mejor para VoiceOver. Seguramente era el aviso que salía en el 17e en la fase 4: allí «À vérifier» quedaba en pantalla con el Resumen en reposo.
  - Resto: en el iPhone 17 y en el 18 Pro sigue saliendo un aviso sin elemento en el Résumé en reposo. En el 17e pasa dos veces seguidas.
  - Ocultando secciones (prueba temporal, ya quitada), el aviso desaparece al quitar la cifra principal o la sección «À vérifier». Sigue al quitar presupuestos, detalles o últimos gastos.
  - Descartado, porque el aviso seguía:
    - la etiqueta de la cifra en mayúsculas o tal cual;
    - agrupar la cifra con `.combine`, con etiqueta propia o sin agrupar;
    - la fecha de la fila igual a la dibujada;
    - las etiquetas de sección sin mayúsculas ni tracking.
  - No se ha añadido ninguna exclusión para este aviso.
- **La auditoría se detenía en el primer problema no excluido**, y cada ejecución mostraba uno distinto, lo que parecía aleatorio. Ahora recoge todos los problemas y falla al final con la lista completa: igual de estricta, pero cada ejecución lo enseña todo.
- **Etiquetas de datos en `caption`, no `caption2`**: con `caption2` la auditoría marcaba «Dynamic Type partially unsupported» en las etiquetas mono, también sin mono, sin mayúsculas y sin tracking. Con `caption` pasan.
- **Etiqueta de la cifra principal** («Dépensé en novembre»):
  - va en mono, tal como está escrita, sin mayúsculas ni tracking;
  - con mayúsculas y tracking dentro de un elemento con etiqueta propia, la auditoría la marcaba como «text clipped»;
  - sin tracking pero en mayúsculas, como texto no representado.

## Resultados de las pruebas (sobre 4491ec9)

- Paquete: 60 + 203 + 31 pruebas en verde.
- Compilación de app, paquete y pruebas de interfaz: 0 avisos.
- Pruebas de interfaz (11):
  - iPhone 17e: 11 de 11, y la auditoría pasa dos veces seguidas;
  - iPhone 17 e iPhone 18 Pro: 10 de 11; falla solo `testSummary`, por el resto de «Potentially inaccessible text» descrito arriba.
- Las pruebas de flujo (alta, edición y borrado, USD, regla mensual, presupuestos y la nueva del chip «Repetir») pasan en los tres simuladores.

## No comprobado sin el simulador

- El aspecto real de la frase:
  - ajuste de línea con nombres largos;
  - subrayados;
  - tamaños grandes de texto.
- Que la cabecera compacta se vea bien con el cristal de iOS 26.
- El teclado al cambiar de pieza: el foco al abrir el comercio y si el calendario gráfico cabe bajo la frase.
- El chip de justificante con cámara, fotos o archivos (los selectores del sistema no se pueden automatizar).
- La lista por días con muchos gastos (rendimiento al desplazar).
