# Fase 3 · Resumen y presupuestos — notas para la revisión

Rama `fase-3`, creada desde `fase-2` (en `e256bc7`, el commit de `PLAN.md`). No se ha fusionado nada en `main`.
La fase 2 sigue sin aceptar: faltan las facturas reales y la prueba en iPhone.

Criterio de la fase: **el resumen cuadra con el historial al céntimo**.

## Qué hay

### Resumen por mes
- **Selector de mes**:
  - flechas a izquierda y derecha;
  - no pasa del mes actual ni del primer mes con gastos;
  - respeta el selector Tout / Pro / Perso.
- **Comparación con el mes anterior**:
  - se muestra junto al total, con la diferencia en importe y en porcentaje;
  - lleva icono y texto en tono neutro: gastar más no se pinta en rojo;
  - si el mes anterior no tiene gastos en ese espacio, no se muestra;
  - en el mes en curso el texto lo dice: «Mois en cours : … de plus que tout octobre».
- **Reparto por categoría**:
  - barras horizontales ordenadas de mayor a menor, en el color del espacio (cobalto, terracota, o tinta en Tout);
  - cada fila lleva icono, nombre, importe y porcentaje; «Sans catégorie» es una fila más;
  - se ven las 6 primeras y «Voir toutes les catégories» abre el resto;
  - tocar una fila abre el historial de esa categoría en ese mes.
- **Evolución de 6 meses** (Swift Charts):
  - el mes elegido va resaltado;
  - en Tout, Pro y Personal aparecen apilados;
  - tocar una barra selecciona ese mes.
- **TVA déductible** (en Pro o Tout, con «Sujeto a TVA» activo):
  - la del mes y la acumulada del trimestre natural hasta ese mes, desglosadas por tipo, con base HT y TVA;
  - con el ajuste desactivado no aparece nada.
- **Presupuestos** (ver abajo).
- **À vérifier** y **Dernières dépenses**, como antes.

### TVA por tipo: esquema v2
- **Nueva entidad `ExpenseVATLine`**: tipo, base HT, TVA y TTC, una línea por tipo de cada gasto.
  - Es compatible con CloudKit: valores por defecto, relación opcional con su inversa, borrado en cascada.
  - El v1 queda congelado en `ModelsV1.swift` y el v2 vive en `ModelsV2.swift`.
- **Campos del gasto**: `vatRate` y `vatAmount` siguen en el gasto con el mismo significado que en v1 (tipo principal y TVA total). Se mantienen sincronizados con las líneas.
- **Regla de redondeo** (escrita en `VATPart`, `BifazModels/Domain/VATLines.swift`):
  1. Todo va en céntimos.
     - La TVA calculada es `TTC − TTC / (1 + tipo)`, redondeada al céntimo hacia arriba en el medio.
     - La base es `TTC − TVA`, así que base + TVA = TTC exactamente en cada línea.
  2. Las líneas suman el importe del gasto al céntimo. Con dos tipos a mano, el tipo principal se queda con el resto.
  3. Las líneas impresas en un justificante conservan su TVA impresa:
     - si suman el total con una diferencia de hasta 1 céntimo por línea, ese redondeo va a la base de la línea mayor;
     - si sobra más, el resto es una parte sin TVA (propina, consigna) y va como línea al 0 %;
     - si las líneas suman más que el total, es una mala lectura: todo el importe se calcula al tipo de la línea mayor.
- **Formulario**:
  - el caso normal no cambia: un tipo y listo;
  - «Ajouter un second taux» añade otro tipo con su parte TTC;
  - las líneas leídas de un justificante se muestran tal cual y, si se cambia el importe o se toca un tipo, se vuelve a los tipos a mano.
  - El detalle del gasto muestra la TVA de cada tipo.

### Migración v1 → v2
- **Cómo funciona**: es una etapa propia (`BifazMigrationPlan.v1ToV2`). El cambio de almacén es aditivo y, después, cada gasto con TVA recibe su línea.
  - Con un solo tipo, la línea lleva ese tipo, la TVA guardada y la base = importe − TVA.
  - Un ticket v1 con varios tipos guardaba el tipo principal y la TVA total impresa. Esa TVA no la explica ningún tipo solo, así que la línea conserva la TVA **sin tipo** («Taux non détaillé») y no se inventa el reparto.
  - No se toca ningún importe, fecha ni campo de los gastos.
- **Pruebas automáticas** (`MigrationTests`):
  - escriben en disco un almacén v1 con datos variados: categorías, presupuesto, etiqueta, regla de comercio, justificante, un tipo, varios tipos, 0 %, sin TVA, 0,01 € y 9.999,99 €;
  - lo abren con el contenedor de la app y comprueban, gasto a gasto, que todos los campos son idénticos, que las relaciones siguen y que las líneas suman importe y TVA;
  - comprueban también que reabrir el almacén ya migrado no cambia nada.
- **En el simulador**:
  - instalé la build de la fase 2, que creó un almacén v1 con 8 gastos, 4 de ellos con TVA;
  - después instalé encima la fase 3, sin desinstalar;
  - las filas `ZEXPENSE` quedaron idénticas antes y después, comparadas con `sqlite3`, y se crearon 4 líneas: Adobe 59,99 + 12,00, Free 16,66 + 3,33, Mercure 129,55 + 12,95, SNCF 79,09 + 7,91;
  - el Resumen Pro marcó 301,49 €, la suma correcta.

### Presupuestos
- **Gestión** desde «Gérer» en el Resumen: crear, editar y borrar, uno por categoría. Cada presupuesto pertenece al espacio de su categoría.
- **Sección «Budgets»**:
  - una barra por presupuesto con lo gastado, el límite y lo que queda;
  - en el mes en curso: «Il vous reste 26,18 € pour 14 jours»;
  - en meses pasados, solo el resultado («Dépassé de …» / «… non dépensés»).
- **Estados**: normal, «Proche de la limite» desde el 80 % (ámbar) y «Budget dépassé» desde el 100 % (rojo), siempre con texto e icono.
  - Se comparan sin dividir, exactos al céntimo; probados con 79,99 %, 80 % y 100 %.
  - `BudgetBar` (BifazDesign) toma ahora el estado del modelo; antes decía «cerca del límite» al 100 % justo.
- **Aviso dentro de la app**: aparece al guardar un gasto que cruza el 80 % o el 100 % de su presupuesto.
  - Es un banner arriba durante unos segundos, con anuncio para VoiceOver.
  - No hay notificaciones del sistema: van en la fase 4.
- **Sin presupuestos**: una línea de invitación y un botón, sin pantalla vacía grande.

### Una sola fuente para los totales
- **Una consulta para todo**: el Resumen, el historial y los presupuestos leen el mismo predicado (`ExpenseFilter`) y suman `amountInEUR` con la misma función (`ExpenseTotals`).
- **Historial de una categoría**: el que se abre desde el Resumen usa la misma vista y consulta que la pestaña Dépenses. Se añadió el filtro «sin categoría».
- **Cálculo fuera de las vistas**: todo se calcula en `BifazKit` (`SummaryCalculator`, `BudgetService`) con `Decimal`. `SummaryLoader` lo calcula en segundo plano, con caché por mes que se vacía en cada guardado.

## Rendimiento (5.000 gastos generados en dos años)
| Dónde | Abrir el Resumen | Cambiar de mes |
|---|---|---|
| Prueba automática (almacén en memoria, simulador) | 92 ms (sin caché tras un guardado: 97 ms) | mediana 19 ms, máximo 22 ms |
| App en el simulador (almacén en disco, `-BifazLargeSample YES`) | 659 ms en el primer arranque en frío | 216 ms el primer cambio, después 45, 7 y 7 ms |

- **Hilo principal**: el cálculo nunca corre en él. Mientras carga, la cabecera muestra un marcador, no un falso «0,00 €».
- **Coste**: casi todo es leer objetos de SwiftData; el cálculo en sí es despreciable.
- **Pendiente**: medir en un iPhone real.

## Verificado por mí en el simulador (iPhone 18 Pro, francés salvo donde se indica)
- **Resumen = historial al céntimo** en noviembre:
  - Tout 792,03 €, Pro 474,52 € y Perso 317,51 €, iguales a la cabecera del mes en Dépenses;
  - octubre en Tout: 672,37 €, y su diferencia con septiembre (43,99 €) coincide con el historial (716,36 €);
  - tocar «Courses» abre su historial del mes con 173,82 €, lo mismo que la fila;
  - abrir un gasto desde ahí funciona: antes salía en blanco y lo corregí.
- **Navegación**: cambio de mes con las flechas; tocar una barra del gráfico selecciona ese mes (había un error que elegía el mes siguiente; corregido).
- **TVA por tipo** en Pro: los totales del mes y del trimestre coinciden con los gastos de ejemplo (20 %: 30,98 €). Incluye un Monoprix con dos tipos impresos.
- **Presupuestos**:
  - creé «Santé» con un límite de 50 €;
  - con 38,90 € gastados estaba normal;
  - +3 € → 41,90 €: «Proche de la limite», con el aviso «Santé : 83 % du budget mensuel»;
  - +10 € → 51,90 €: «Budget dépassé», con su aviso;
  - se ven los tres estados a la vez.
- **Migración v1 → v2** en la app: ver arriba.
- **Segundo tipo de TVA a mano**:
  - editando Brasserie Le Zinc (48,60 € al 10 %), «Ajouter un second taux» → 5,5 % con 12,00 € TTC;
  - se guardaron dos líneas: 36,60 € al 10 % (TVA 3,33 €) y 12,00 € al 5,5 % (TVA 0,63 €), que suman 48,60 €;
  - el detalle muestra «TVA 10 %» y «TVA 5,5 %».
  - Defecto menor pendiente: con el teclado abierto, el campo del segundo importe queda tapado y no se desplaza solo a la vista.
- **Presentación**: modo oscuro, español y texto grande (AccessibilityXL); las filas del reparto se apilan sin cortarse.

## Cubierto solo por pruebas automáticas
- **Resumen = historial** con datos generados: 3 semillas × 700 gastos, en 6 meses, los 3 espacios, cada categoría, cada barra y la TVA del mes y del trimestre. Incluye gastos en el primer y en el último instante de un mes, sin categoría y con uno o dos tipos.
- **Caché**: el cargador con caché da lo mismo que el cálculo directo y relee tras un guardado.
- **Comparación**: −100 %, sin mes anterior y mes en curso.
- **Redondeo de TVA**: todos los importes de 0,01 € a 30,00 € con cada tipo, dos tipos a mano con importes extremos y 200 combinaciones aleatorias de líneas impresas.
- **Umbrales** de presupuesto (79,99 %, 80 %, 100 %, límite 333,33 €), días restantes, un solo presupuesto por categoría y avisos que solo saltan si el estado empeora.
- **Prueba de interfaz** (`BudgetFlowUITests`): crear un presupuesto desde la invitación, añadir gastos y ver el estado pasar a cerca del límite y a superado, con el aviso.
- **Batería completa** del esquema `Bifaz` (última pasada sobre `bad7e13`):
  - 161 pruebas de modelos, 10 de diseño y 57 de lectura, más 3 de interfaz;
  - sin avisos del compilador (el único aviso es el habitual de `appintentsmetadataprocessor`).

## No comprobado
- **VoiceOver** con el lector encendido. Las etiquetas existen (categoría o mes, importe y porcentaje; estados con palabra), pero no las he escuchado.
- **Rendimiento y migración en un iPhone real.**

## Capturas (`docs/capturas/fase-3/`)
- **01–03**: Resumen en Tout, Pro y Perso.
- **04**: lista completa de categorías.
- **05**: evolución.
- **06**: TVA por tipo, en Pro.
- **07**: presupuestos en tres estados, en oscuro.
- **08–09**: avisos de cerca del límite y de superado.
- **10**: Resumen en español.
- **11**: Resumen en oscuro.
- **12**: reparto con texto grande.

Las capturas 01–03 se hicieron antes de añadir a mano los dos gastos de «Santé», por eso el total de Tout cambia de 792,03 € a 805,03 € en las siguientes.

## Cambios o dudas para el plan (decide el manager)
- El plan habla de «paleta de categorías para gráficos» en la fase 3 (sección 3, Colores). Por decisión del manager no hay paleta por categoría, así que el campo `colorKey` de `ExpenseCategory` queda sin uso. Conviene quitar esa línea del plan.
- **Trimestre «acumulado»**: lo he interpretado como desde el primer día del trimestre natural hasta el final del mes mostrado. Si se prefería el trimestre completo, el cambio está en `SummaryCalculator.quarterToDate`.
- **Datos de ejemplo de depuración**: `-BifazSampleData YES` crea siete meses de datos con presupuestos; `-BifazLargeSample YES` crea 5.000 gastos. Las dos opciones solo existen en Debug.
