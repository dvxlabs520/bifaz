# Bifaz — Plan de trabajo

App iOS para guardar facturas profesionales y gastos personales en un mismo sitio.
Simple de usar, con acabado premium y preparada para publicarse en el App Store.

Estado (19-11-2026):
- **Fases 0 y 1**: aceptadas e integradas en `main` (`b60c8b6`).
- **Fase 2**: entregada en `fase-2`, **sin aceptar**: falta probarla con facturas reales
  (`TestData/Real/`, fuera de git) y en un iPhone real (escáner, modelo de Apple, cifrado).
- **Fase 3**: aceptada, en `fase-3`.
- **Fase 4**: entregada en `fase-4`; 3 correcciones en curso.
- **Siguiente**: la nueva fase 5 (rediseño editorial y entrada en una frase), en `fase-5` desde `fase-4`
  cuando las correcciones estén hechas. Las fases 5 a 13 se rehicieron el 19-11-2026 tras evaluar outlayr
  y revisar las funciones (sección 9).
- Nada fusionado en `main` desde la fase 1: las ramas 2, 3 y 4 están apiladas.

## 1. Decisiones cerradas

| Tema | Decisión |
|---|---|
| Nombre | **Bifaz** (elegido el 17-11-2026; marca en el INPI y dominios por confirmar) |
| Empresa / identificador | dvxlabs · `com.dvxlabs.bifaz` |
| Plataforma | iOS nativo, SwiftUI, Swift 6.4 (Xcode 27.1, SDK iOS 27.1) |
| iOS mínimo | iOS 26 |
| Dispositivos | iPhone, y Apple Watch como app complementaria (fase 11). Sin iPad en la versión 1 |
| Dirección visual | Hasta la fase 4: sobria, de neobanco (fondo blanco, referencia Qonto). Desde la fase 5: **editorial cálida**, tomando ideas de la app de código abierto outlayr que el usuario prefiere (papel cálido, cifra protagonista, etiquetas en monoespaciada, listas por día, entrada en una frase), sin copiar su código, iconos ni textos. Detalle en la sección 3 y la evaluación en la sección 9 |
| País fiscal | Francia: TVA 20 % / 10 % / 5,5 % / 2,1 %, moneda base EUR |
| Idiomas | Español (de "tú"), francés (de "vous") e inglés desde el primer día |
| Backend | Sin backend. Datos en el dispositivo, cifrados; iCloud opcional |
| Lectura de facturas | En el dispositivo, con los frameworks de Apple. Sin modelo propio dentro de la app |
| Asistente de preguntas | Modelo de Apple en el dispositivo, solo en iPhones compatibles |
| Suscripciones de pago | Fuera por ahora |

## 2. Equipo y forma de trabajo

| Rol | Modelo | Responsabilidad |
|---|---|---|
| Manager | Fable | Mantiene este plan, parte cada fase en tareas, revisa cada entrega contra su criterio de "hecho" y decide. No escribe código de producción. |
| Desarrollador principal | Opus | Arquitectura, modelo de datos y código crítico (persistencia, lectura de facturas, Apple Pay, seguridad). Integra, compila y prueba. |
| Subagentes | Sonnet | Tareas acotadas con encargo claro: componentes del sistema de diseño, pruebas, traducciones, datos de prueba, plantillas de informes. |

Reglas:
- Cada tarea lleva un encargo escrito: archivos que toca y qué significa "hecho".
- Dos agentes nunca escriben en los mismos archivos a la vez.
- Una fase se cierra con compilación limpia sin avisos, la batería completa en verde y la revisión del manager
  sobre el código y las pruebas.
- **Pruebas (regla del usuario, 19-11-2026)**: nadie prueba a mano en el simulador hasta que el usuario lo pida.
  El trabajo se confirma con pruebas unitarias en `BifazKit` siempre que se pueda y, solo cuando no hay otra
  forma, con pruebas de interfaz automáticas (`xcodebuild test`). Sin capturas. Cuando el usuario lo pida,
  se prueba con él en el simulador lo trabajado, y lo que salga se corrige en la rama más alta.
- Repositorio git desde la fase 0; los cambios de alcance se anotan primero en este plan.

## 3. Marca

### Nombre
**Bifaz**: "dos caras" (bi + faz, la cara de una moneda). Una moneda, dos caras: Pro y Personal.
Cinco letras y se lee bien en español, francés e inglés.

- Lema: *Dos caras, una cuenta clara.* · *Deux faces, des comptes clairs.* · *Two sides, one clear ledger.*
- Comprobado el 17-11-2026: sin apps con ese nombre en el App Store de Francia, España y EE. UU.;
  `bifaz.app` y `bifaz.fr` sin DNS activo; `bifaz.com` ocupado.
- Por confirmar antes de publicar: marca en el INPI (clases 9 y 36), registro de los dominios
  y reserva del nombre en App Store Connect.
- Descartados: Dobla (`dobla.app` es una app francesa de cromos y existe "doble : finances personnelles"
  en el App Store francés), Neto (app de finanzas existente), Tikeo (dominios ocupados).
- Reservas si Bifaz falla en el INPI: Bilado, Justio.

### Logo
- Una moneda partida en dos mitades ligeramente desplazadas: mitad Pro (blanca)
  y mitad Personal (melocotón `#FFB08A`) sobre fondo cobalto `#2747D8`. Juntas forman el círculo completo.
- Dibujado como vector en código (misma geometría para icono, splash y marca dentro de la app).
- Icono de app en las variantes del sistema: claro, oscuro, tintado y transparente.
- Logotipo: icono de la app junto a "Bifaz" en SF Pro seminegrita.
- En modo oscuro el icono usa un cobalto profundo `#172573`.

### Colores
Valores implementados en la fase 0; todos los pares texto/fondo pasan AA (prueba automática `ContrastTests`).

| Token | Claro | Oscuro | Uso |
|---|---|---|---|
| Tinta | `#1B1C1E` | `#F1F1F2` | Texto principal, botones primarios |
| Tinta secundaria | `#6A6C72` | `#9C9EA4` | Texto de apoyo |
| Papel | `#FFFFFF` | `#0F1012` | Fondo |
| Superficie | `#FFFFFF` con borde | `#17181B` | Tarjetas, hojas |
| Superficie tenue | `#F4F4F6` | `#1F2023` | Rellenos suaves |
| Línea fina | `#E7E8EB` | `#26282C` | Separadores y bordes (nunca texto) |
| Pro · Cobalto | `#2747D8` | `#8AA2FF` | Todo lo que pertenece al espacio Pro |
| Personal · Terracota | `#B8451A` | `#FF9466` | Todo lo que pertenece al espacio Personal |
| Éxito | `#1B7F50` | `#5BD69A` | Confirmaciones, presupuesto en orden |
| Aviso | `#98641A` | `#F2C261` | Presupuesto cerca del límite, justificante pendiente |
| Error | `#C4314B` | `#FF8097` | Errores, presupuesto superado |

- Tintes pastel de fondo para cada color (Pro `#ECEFFC`, Personal `#F9EEE8`, éxito `#EEF7F2`,
  aviso `#FFF3DC`, error `#FBE9EC`) con sus equivalentes oscuros.

- Cobalto y terracota son un par azul/naranja, distinguible con daltonismo;
  aun así el espacio siempre se indica también con texto o icono, nunca solo con color.
- Los gráficos no usan una paleta por categoría: las barras van en el color del espacio (cobalto en Pro,
  terracota en Personal, tinta en Todo) y cada categoría se distingue por su nombre e icono.

### Sistema de diseño
- **Tipografía**: SF Pro en toda la app, pesos regular y medio; importes con cifras tabulares.
  Todo con Dynamic Type. (New York se retiró en la fase 0: daba aspecto de plantilla.)
- **Espaciado**: rejilla de 4 pt. Radios 12 / 20 / 28.
- **Materiales**: Liquid Glass solo en barras y controles flotantes; el contenido va sobre superficies sólidas.
- **Iconos**: juego propio de 54 iconos de trazo fino (24 pt, trazo 1,6) en `BifazDesign` (`BifazIcon`),
  usado en pestañas, componentes, categorías y acciones. Sustituye a SF Symbols a petición del usuario (fase 1).
- **Movimiento**: animaciones de muelle cortas, respuesta háptica en guardar, escanear y cerrar sesión;
  todo respeta "Reducir movimiento".
- **Componentes**: importe, selector de espacio, fila de gasto, miniatura de justificante,
  chip de categoría, tarjeta de cifra, barra de presupuesto, botón primario y secundario,
  campo de confirmación (con indicador de confianza de la lectura), cápsula de filtro,
  icono de categoría con insignia de espacio, barra de reparto Pro/Personal, cabecera de sección.
  El estado vacío es texto alineado a la izquierda con botones, sin ilustración.
- Tokens y componentes viven en `BifazKit` con vistas previas en claro, oscuro y texto grande.

### Dirección visual v2: editorial cálida (desde la fase 5)
Sustituye a lo anterior donde choque. Ideas tomadas de outlayr (sección 9) y adaptadas a Bifaz;
se conserva lo propio: la moneda, Pro en cobalto y Personal en terracota, iconos propios, español, francés e inglés.

- **Papel cálido en lugar de blanco.** Valores de partida, a validar con `ContrastTests` (AA) y ajustables:

  | Token | Claro | Oscuro |
  |---|---|---|
  | Papel | `#F4F1EA` | `#14130F` |
  | Superficie | `#FBFAF6` | `#1D1B17` |
  | Línea fina | `#E4DFD4` | `#2E2A23` |
  | Tinta | `#1A1814` | `#F3EFE6` |
  | Tinta secundaria | `#6B655A` | `#A39C8F` |

  Cobalto, terracota, éxito, aviso y error se mantienen; se revisa su contraste sobre el papel nuevo.
- **Un solo color de acción.** El botón principal sigue en tinta; el color se reserva para el espacio
  (Pro/Personal) y para los estados. Nada de degradados ni sombras grandes.
- **Tres voces tipográficas, todas del sistema:**
  - SF Pro para la interfaz;
  - SF Mono en mayúsculas pequeñas para etiquetas de dato ("LÍMITE", "GASTADO", "QUEDAN 12 D"), cabeceras
    de tabla, meses y widgets;
  - New York solo en las frases de contexto del Resumen y los presupuestos ("A este ritmo te faltarán 52 €").
    La serif se retiró de los títulos en la fase 0; aquí es solo para esas frases. Si en la revisión visual
    no convence, se usa SF Pro.
- **La cifra es la protagonista.** Importe grande con la parte entera en tinta y los decimales en tinta
  secundaria, cambio de cifras animado (`contentTransition(.numericText())`) y una línea de tendencia fina
  al lado.
- **Cabeceras compactas.** Título pequeño centrado con botones redondos (buscar, filtrar) y la cifra
  principal debajo, en lugar del título grande.
- **Listas por día.** Cabecera de día con su total ("Ayer · 93,00 €"), filas con hora, separadores finos
  y avatar del comercio: monograma con su inicial sobre el tinte del espacio (no logos de marcas: implican
  permisos de marca y conexión).
- **Entrada en una frase.** Nuevo gasto como una frase con piezas que se tocan:
  "Gasté **42,00 €** en **Carrefour** para **Supermercado** · **Personal** · **hoy**". Cada pieza abre su
  selector abajo (teclado, comercios recientes, categorías, espacio, fecha). Debajo, chips para lo opcional:
  TVA y cliente o proyecto (solo Pro), nota, repetir, justificante. La confirmación de una lectura usa la
  misma frase, con el subrayado indicando la confianza (seguro, a revisar). En francés y en inglés se
  construye con frases propias, no traduciendo palabra a palabra.
- **Gráficos de ritmo.** En presupuestos, curva de consumo del mes con la proyección punteada hasta fin
  de mes y el límite como referencia.
- Se mantienen Liquid Glass en barras y controles flotantes, la barra de pestañas flotante y el botón "+".

### Splash animado
- Pantalla de lanzamiento estática: fondo cobalto con la moneda blanca y melocotón quieta
  (idéntica al primer fotograma de la animación).
- Animación (máximo 1,4 s): las dos mitades entran desde lados opuestos, se unen con un toque háptico
  y un destello; aparece "Bifaz"; la moneda se expande como máscara y revela el Resumen.
- Solo en arranque en frío; nunca retrasa la carga de datos; con "Reducir movimiento" es un fundido.
- Hecha en SwiftUI con las mismas formas vectoriales del logo, afinada a 60 y 120 Hz.

## 4. Alcance de la versión 1

### Captura
- Escanear factura con la cámara (recorte y enderezado automático).
- Importar desde la galería o un PDF desde Archivos.
- Compartir a Bifaz desde Mail, Archivos o Fotos.
- Gasto rápido sin foto: importe, categoría, guardar.

### Lectura automática
- Extrae comercio, fecha, total, TVA (tipo e importe) y moneda.
- Siempre pasa por una pantalla de confirmación.
- Dos niveles: modelo de Apple cuando el iPhone lo permite, y un lector por reglas como respaldo.

### Pagos con Apple Pay
Cómo funciona: iOS no deja a una app leer las notificaciones de Wallet. La vía oficial es una
automatización de la app Atajos con el disparador "Wallet", que entrega comercio e importe
a una acción de Bifaz. Una app no puede crear esa automatización por sí sola.

- **Botón "Conectar Apple Pay"** en Ajustes y en la bienvenida: abre Atajos y acompaña con una guía
  de 4 pasos (elegir tarjetas, añadir la acción "Registrar pago en Bifaz", activar "Ejecutar inmediatamente").
  Se hace una vez y lleva alrededor de un minuto.
- **Indicador de conexión**: "Conectado · último pago recibido hace 2 h", para saber que sigue funcionando.
- **Validación de cada pago**:
  - importe vacío o cero → va a una bandeja "Por revisar", no se pierde ni se guarda mal;
  - mismo comercio e importe en menos de 2 minutos → se trata como duplicado;
  - comercio ya conocido → hereda espacio y categoría de la última vez.
- **Sesión de gastos**: se inicia con un toque eligiendo espacio y, si quieres, cliente o proyecto
  ("Viaje Lyon", "Almuerzo cliente X"). Mientras está activa, todo pago entra con esos datos.
  Muestra el total en la pantalla de bloqueo y la Isla Dinámica; al cerrarla, resumen y justificantes pendientes.
- **Justificantes automáticos**: Apple Pay no entrega la factura, así que cada pago Pro nace como
  "justificante pendiente" con una notificación "Escanear ahora". Cuando escaneas, importas o compartes
  una factura, Bifaz la empareja sola con el pago (mismo importe, fecha cercana, comercio parecido)
  y pregunta solo si hay duda.
- **Límites**: solo pagos con Apple Pay desde tarjetas en Wallet; los pagos desde Apple Watch
  pueden no dispararse (se comprueba en dispositivo real); no se puede probar en el simulador.

### Organización
- Dos espacios: Pro y Personal, con selector global (Pro / Personal / Todo).
- Categorías predefinidas por espacio, editables.
- Etiquetas de cliente o proyecto en Pro.
- Historial por meses con búsqueda y filtros (espacio, categoría, etiqueta, fechas, justificante pendiente).

### Control
- Resumen: total del mes, reparto por categoría, comparación con el mes anterior, TVA soportada en Pro.
- Presupuestos mensuales por categoría, con aviso al acercarse al límite.
- Gastos recurrentes: se generan solos en su fecha.
- Multi-moneda: importe original y equivalente en EUR; tipo de cambio del BCE, editable.
- Recordatorio de cierre de periodo de TVA (mensual o trimestral).

### Informes y exportación
Informes en PDF A4 con cabecera de marca, texto seleccionable, páginas numeradas y
el idioma del informe elegible aparte del de la app (app en español, informe en francés para el comptable).

| Informe | Contenido |
|---|---|
| Informe de periodo (Pro o Personal) | Portada con periodo y totales, cifras clave, gráfico por categoría, comparación con el periodo anterior, tabla detallada |
| Informe de TVA (Pro) | Tabla por tipo de TVA con HT / TVA / TTC, desglose mensual, lista numerada de facturas, anexo de justificantes |
| Note de frais | Por cliente, proyecto o sesión: gastos numerados y anexo con cada justificante con su número |
| Resumen anual | Evolución mes a mes, categorías principales, totales por espacio |

- CSV para el expert-comptable (opción de formato francés: punto y coma, coma decimal).
- ZIP con los justificantes nombrados por fecha y comercio.
- Por periodo (mes, trimestre, año, personalizado) y por espacio.

### Seguridad y copia
- **Cifrado en reposo**: base de datos y justificantes protegidos con el cifrado por hardware de iOS
  (Data Protection). La base queda accesible tras el primer desbloqueo para que Apple Pay pueda registrar
  pagos en segundo plano; los justificantes, solo con el iPhone desbloqueado.
- **Bloqueo con Face ID** y pantalla oculta en el selector de apps.
- **Copia de seguridad cifrada**: un único archivo `.bifaz` con todos los datos y justificantes,
  cifrado con AES-256 y una contraseña tuya; se restaura en cualquier iPhone.
- **iCloud opcional**, desactivado de inicio: al activarlo, datos y justificantes se cifran antes de subir.
- Sin analítica ni SDK de terceros.
- Sin criptografía propia sobre la base de datos en uso: evita riesgo de pérdida de datos y mantiene la búsqueda rápida.

### Asistente
- Preguntas en lenguaje natural sobre tus gastos.
- El modelo no calcula: pide los datos a la base y redacta la respuesta.
- Visible solo en iPhones con Apple Intelligence.

### Sistema
- Widgets de inicio y de pantalla de bloqueo: gasto del mes, presupuesto, gastos de hoy y captura rápida.
- Control del Centro de control y del botón de acción: "Nuevo gasto" y "Escanear justificante".
- Siri y Spotlight (App Intents): "Añadir gasto", "Escanear justificante", "Gasto del mes".
- Ajuste "Sujeto a TVA: sí / no" (con "no" se ocultan los campos de TVA).

### Mejoras de lo que ya existe (fase 6)
Salen de la revisión de funciones del 19-11-2026 (sección 9).
- **Gasto mixto**: un gasto con una parte Pro y otra Personal (teléfono, internet, coche), con el
  porcentaje Pro; los totales, la TVA y los presupuestos usan la parte que toca.
- **Presupuesto global por espacio**, además de por categoría, con arrastre opcional del sobrante
  o del exceso al mes siguiente.
- **Ritmo**: proyección de fin de mes ("a este ritmo terminarás en 1 240 €" o "te faltarán 52 €").
- **Frases de contexto en el Resumen**: "Gastas menos de lo normal: a estas alturas sueles llevar 890 €",
  comparando con la media de los meses anteriores al mismo día.
- **Próximos cargos**: lista de los recurrentes por mes con su total mensual, y aviso unos días antes
  de cada cargo (además del aviso del mismo día).
- **Factur-X**: al importar una factura electrónica francesa (PDF con XML Factur-X dentro) se leen los datos
  exactos del XML, sin OCR: proveedor, número, fecha, total y TVA por tipo.

### Apple Watch (fase 11)
App complementaria en el reloj, para lo que se hace con prisa:
- **Añadir un gasto en segundos**: importe con la corona o el teclado, espacio, categoría entre las
  recientes y comercio por dictado opcional.
- **Vistazo del mes**: total, reparto Pro/Personal, presupuestos cerca del límite y justificantes pendientes.
- **Sesión de gastos** (de la fase 9): iniciarla, verla en curso y cerrarla desde la muñeca.
- **Complicaciones**: gasto del mes, presupuesto en anillo y botón de añadir.
- Sin justificantes ni informes en el reloj. Necesita el iPhone: sin cuenta, sin iCloud y sin servidor.

### Fuera de la versión 1
Conexión bancaria, emisión de facturas, contabilidad completa, equipos o multiusuario,
ingresos, Android y web, suscripciones de pago, valor legal de "copie fiable".
De outlayr se dejan fuera a propósito, para no convertir Bifaz en una app de finanzas personales:
cuentas y saldos, deudas, transferencias, metas de ahorro, compras a plazos, nóminas e ingresos, y cuenta
con inicio de sesión. Ideas para después de la v1: importación CSV, indemnités kilométriques (solo para quien
declara gastos reales; un micro-entrepreneur no las deduce) y porcentaje de TVA deducible por categoría
(a validar con un expert-comptable).

## 5. Arquitectura

- **Interfaz**: SwiftUI con Observation, `NavigationStack`.
- **Datos**: SwiftData en el contenedor de un App Group desde el primer día
  (lo comparten app, extensión de compartir y widgets). Modelo compatible con CloudKit desde el inicio
  (valores por defecto u opcionales, relaciones opcionales, sin unicidad).
- **Justificantes**: desde la fase 1 el modelo guarda solo el nombre del archivo; los archivos van a una
  carpeta propia con protección `.complete` (legibles solo con el iPhone desbloqueado). Consecuencia:
  ya no viajan a iCloud con la base de datos, así que la fase 8 debe sincronizarlos por su cuenta.
- **Importes**: siempre `Decimal`.
- **Concurrencia**: modo de lenguaje Swift 6 con comprobación estricta; lectura, informes y copia fuera del hilo principal.
- **Apple Pay**: App Intents ("Registrar pago", "Iniciar sesión", "Cerrar sesión") que se ejecutan
  en segundo plano sin abrir la app; ActivityKit para la sesión en curso.
- **Estructura**: paquete local `BifazKit` (modelos, persistencia, lectura, informes, seguridad, sistema de diseño).
- **Apple Watch**: target watchOS en SwiftUI que reutiliza `BifazKit` donde puede. Sincronización con el iPhone
  por WatchConnectivity, sin iCloud ni servidor: el iPhone envía un resumen (contexto de aplicación) cuando
  cambian los datos, y el reloj envía los gastos nuevos por la cola garantizada (`transferUserInfo`). El iPhone
  los guarda con `ExpenseService` de forma idempotente por identificador. El reloj solo guarda el resumen y su
  cola de envío. Complicaciones con WidgetKit, compartiendo código con los widgets del iPhone.
- **App Intents**: las acciones de Siri, Spotlight, controles, widgets, Apple Pay y el reloj comparten
  las mismas intenciones de `BifazKit`.
- **Textos**: String Catalog es / fr / en; formateadores del sistema para fechas, importes y monedas.
- **Pruebas**: Swift Testing para el lector por reglas, TVA, recurrencias, moneda, validación y duplicados
  de pagos, emparejado de justificantes, ida y vuelta de la copia cifrada e informes.
- **Dependencias externas**: ninguna prevista.

### Modelo de datos

| Entidad | Campos principales |
|---|---|
| Gasto | importe, moneda, importe en EUR, fecha, comercio, espacio, categoría, tipo e importe de TVA, nota, etiquetas, justificante, origen (manual, escáner, Apple Pay, recurrente), estado (confirmado, por revisar, justificante pendiente), sesión |
| Justificante | archivo, miniatura, texto leído |
| Categoría | nombre, icono, color, espacio |
| Etiqueta | nombre, tipo (cliente o proyecto) |
| Presupuesto | categoría, importe mensual |
| Regla recurrente | plantilla de gasto, frecuencia, próxima fecha |
| Sesión | nombre, espacio, etiqueta, inicio, fin |
| Regla de comercio | comercio, espacio y categoría aprendidos |

### Navegación
Pestañas: **Resumen · Gastos · Asistente · Ajustes**, con botón de captura siempre visible
y acceso a "Iniciar sesión de gastos" desde ese mismo botón.

## 6. Fases

Cada fase termina con la app compilando sin avisos y la batería completa en verde. Desde el 19-11-2026
el "hecho cuando" se demuestra con pruebas automáticas; la prueba en el simulador o en el dispositivo se hace
con el usuario cuando él lo pide (sección 2).

**Fases 0 a 4 (hechas o en curso):**

| Fase | Contenido | Hecho cuando |
|---|---|---|
| 0. Cimientos y marca | Proyecto, `BifazKit`, App Group, modelo de datos, tokens y componentes del sistema de diseño, logo vectorial e icono, pantalla de lanzamiento estática, textos en 3 idiomas | La app arranca con las pestañas vacías, con la marca aplicada, en 3 idiomas, claro y oscuro |
| 1. Núcleo | Gasto rápido, espacios, categorías, historial, búsqueda, filtros, detalle y edición | Se lleva el control de gastos a mano de principio a fin |
| 2. Captura y lectura | Escáner, importar foto y PDF, lectura, extracción (modelo + reglas), confirmación | Una factura francesa típica se guarda con comercio, fecha, total y TVA correctos sin teclear |
| 3. Resumen y presupuestos | Gráficos, comparación mensual, TVA acumulada, presupuestos | El resumen cuadra con el historial al céntimo |
| 4. Funciones Pro | Etiquetas, recurrentes, multi-moneda, recordatorio de TVA | Un gasto en USD y un abono mensual salen bien en resumen e informes |

**Fases 5 a 13 (rehechas el 19-11-2026):**

| Fase | Contenido | Hecho cuando |
|---|---|---|
| 5. Rediseño editorial y entrada en una frase | Sistema de diseño v2 (sección 3) en todas las pantallas; entrada y confirmación en una frase; listas por día con monogramas; cabeceras compactas con la cifra protagonista. En dos tramos: **5a** sistema de diseño, Resumen, Gastos y entrada en una frase; **5b** el resto de pantallas. Entre ambos, el usuario puede mirar la dirección visual antes de extenderla | Todas las pantallas usan los tokens v2 (prueba que lo comprueba), contraste AA en claro y oscuro, la frase se construye bien en los 3 idiomas (pruebas), las pruebas de interfaz existentes siguen pasando |
| 6. Mejoras de lo que ya existe | Gasto mixto Pro/Personal, presupuesto global por espacio con arrastre, ritmo y proyección, frases de contexto, próximos cargos con aviso previo, lectura de Factur-X | Los totales siguen cuadrando al céntimo con gastos mixtos, la proyección es correcta en datos generados, una factura Factur-X de prueba se lee sin OCR (pruebas) |
| 7. Informes y exportación | Los 4 informes PDF, CSV, ZIP; con el diseño v2 | El informe de TVA de un trimestre se puede enviar tal cual al expert-comptable, en francés |
| 8. Seguridad y copia | Data Protection, Face ID, copia cifrada `.bifaz`, iCloud opcional | Una copia restaurada recupera todos los gastos y justificantes; con contraseña errónea no abre (pruebas de ida y vuelta) |
| 9. Apple Pay y sesiones | App Intents, guía de conexión, validación, sesiones con actividad en vivo, emparejado de justificantes | En un iPhone real, un pago con Apple Pay aparece solo en Bifaz y su ticket escaneado después se le adjunta sin intervención |
| 10. Extensiones, widgets y Siri | Extensión de compartir, widgets de inicio y bloqueo, controles, acciones de Siri y Spotlight | Un PDF de Mail llega a la confirmación en dos toques; los widgets muestran las mismas cifras que el Resumen |
| 11. Apple Watch | App del reloj (añadir, vistazo del mes, sesiones), complicaciones, sincronización por WatchConnectivity | Un gasto añadido en el reloj llega al iPhone una sola vez aunque se reenvíe, y el resumen del reloj coincide con el del iPhone (pruebas del protocolo) |
| 12. Asistente y dictado | Preguntas en lenguaje natural con herramientas de consulta; dictar un gasto ("comida con cliente, 42 euros") que se convierte en la frase de entrada | Responde bien un banco de 30 preguntas en los 3 idiomas; un banco de dictados se convierte en gastos correctos |
| 13. Splash, bienvenida, pulido y lanzamiento | Splash animado, bienvenida con el régimen de TVA, estados vacíos, accesibilidad, rendimiento con miles de gastos, TestFlight, ficha y etiquetas de privacidad | Versión candidata en TestFlight |

**Fase 0, revisada por el manager (17-11-2026):** compila sin errores, 48 pruebas en verde,
pestañas y selector de espacio probados con toques en el simulador, tres idiomas completos.
Ajustes que pasan a la fase 1:
- El título grande de cada pestaña queda 4 pt más a la izquierda que el contenido; alinearlos.
- En el estado vacío hay tres accesos a "añadir" (dos botones y el "+" flotante); dejar uno claro.
- Tratamiento en francés: ahora tutea ("Scanne…"); decidido "vous" (ver correcciones de la fase 1).

**Fase 1, revisada por el manager (17-11-2026):** compila sin errores, 110 pruebas en verde.
Probado con toques en el simulador: alta de un gasto, aparición en Resumen e Historial, detalle,
borrado con confirmación; los totales cuadran al céntimo antes y después. No probados por el manager
(sí cubiertos por pruebas del modelo y verificados a mano por el desarrollador): edición, búsqueda,
filtros, gestión de categorías y ajuste "Sujeto a TVA". Además del alcance previsto, la fase incluye
el Resumen con datos reales, el ajuste "Sujeto a TVA", manifiesto de privacidad, cifrado en iCloud
marcado en los campos sensibles y portada de marca en el selector de apps.

**Correcciones de la fase 1, revisadas por el manager (17-11-2026):** las 6 están hechas en la rama
`fase1-correcciones`. Verificado: 115 pruebas en verde (103 + 10 de paquete y 2 de interfaz), categorías
en francés, títulos alineados, textos franceses en "vous" sin ningún tuteo, texto de borrado sin comercio
correcto y última fila visible sobre el botón "+". Falta integrarlas en `main` y adaptar a ellas lo ya
empezado de la fase 2.

**Aviso para la fase 2:** las 20 facturas de `TestData/Receipts` son sintéticas, generadas por el propio
desarrollador. La fase no se acepta hasta probar la lectura con facturas y tickets reales del usuario.

Lista de correcciones (todas hechas en la rama):
1. **Categorías en idioma mezclado**: los nombres por defecto se guardan en el idioma del primer arranque
   y no cambian con el idioma del iPhone (se ve "Supermercado" o "Software" con la app en francés).
   Las categorías por defecto no renombradas deben traducirse al mostrarse.
2. **Texto de borrado sin comercio**: si el gasto no tiene comercio, la confirmación empieza por
   " et son justificatif seront supprimés…"; falta una variante del texto para ese caso.
3. **Título de pestaña desalineado**: sigue 4 pt a la izquierda del contenido (venía de la fase 0).
4. **Botón "+" flotante**: tapa los importes de las últimas filas visibles; añadir margen inferior a las listas.
5. **Tratamiento en francés**: decidido por el usuario el 17-11-2026: **"vous"**. Pasar todos los textos franceses de "tu" a "vous".
6. **Pruebas de interfaz**: no hay ninguna automatizada; añadir al menos alta, edición y borrado de un gasto.

**Fase 2, revisada por el manager en simulador (17-11-2026), rama `fase-2` (`84cd95e`):** pasan 173 pruebas
(112 + 10 + 49 de paquete y 2 de interfaz; la de facturas reales se omite por carpeta vacía).
Probado con toques: menú del "+", importación de una foto con el selector privado del sistema, pantalla de
lectura y confirmación de un ticket sintético con importe, comercio y fecha correctos en unos 4 s; al cancelar
no se guarda nada. No probados por el manager (sí por el desarrollador): importación de PDF, visor del
justificante y guardado tras la lectura. Cambio de alcance aprobado: el origen "Escaneado" se llama
"Desde un justificante".

Medidas del desarrollador sobre las 20 facturas sintéticas (regresión, no aceptación): reglas solas 20/20 en
todos los campos; modelo de Apple solo, más débil (tipos de TVA 10/20); combinados 20/20. En el simulador el
modelo responde con Apple Intelligence del Mac, así que no representa un iPhone.

Para aceptar la fase: facturas y tickets reales del usuario leídos correctamente, y prueba en iPhone real
del escáner, del modelo y de la protección de los justificantes.

**Mejoras de la fase 2, revisadas por el manager (17-11-2026), rama `fase-2` (`506fe98`):** las 5 están
hechas, cada una en su commit. Verificado: 191 pruebas en verde (122 + 10 + 57 de paquete y 2 de interfaz) y,
con toques en el simulador en francés sobre el ticket de TotalEnergies: categoría "Transports" marcada como
propuesta, comercio "TotalEnergies", pantalla de lectura opaca, confirmación al descartar y menú del "+" sin
parpadeo oscuro. El botón "+" es ahora un disco plano de 56 pt, algo menor que antes. Cubierto solo por
pruebas automáticas: guardar con la categoría propuesta y la propuesta a partir de la memoria del comercio.

Lista de mejoras (todas hechas en la rama):
1. La lectura no propone categoría: los gastos leídos quedan "Sin categoría" (p. ej. Monoprix, SNCF).
2. El comercio sale con mayúsculas irregulares ("Totalenergies Relais A6 - AIRE DE Beaune") y aun así marcado "Seguro".
3. El texto de "Leyendo su justificante…" se superpone al contenido de fondo; falta un velo más opaco.
4. Cerrar la confirmación con la "X" descarta la lectura sin preguntar.
5. El menú del "+" parpadea en oscuro al cerrarse.

**Fase 3, decisiones del manager al encargarla (17-11-2026):**
- Parte de `fase-2` en una rama `fase-3`. No se fusiona nada en `main` hasta aceptar la fase 2.
- Reparto por categoría como barras horizontales ordenadas, sin gráfico circular ni paleta por categoría.
- TVA por tipo: el modelo pasa a guardar una línea por tipo de TVA (base, TVA e importe), porque el informe
  de TVA de la fase 5 lo necesita y hoy un ticket con varios tipos solo guarda la TVA total. Es el esquema v2,
  con migración probada desde el v1.
- Avisos de presupuesto dentro de la app (cerca del límite al 80 %, superado al 100 %). Las notificaciones
  del sistema se dejan para la fase 4, junto con el recordatorio de TVA.

**Fase 3, revisada por el manager (17-11-2026), rama `fase-3` (`fd587e0`):** pasan 231 pruebas
(161 + 10 + 57 de paquete y 3 de interfaz). Comprobado en un simulador aparte, en español y con los datos de
ejemplo: el Resumen de noviembre cuadra con el historial al céntimo en "Todo" (792,03 €), la comparación
mensual es correcta, la TVA por tipo suma el total del mes y los presupuestos muestran sus tres estados con
importes coherentes con el reparto. No comprobado por el manager (sí por el desarrollador o por pruebas):
el cuadre en Pro y Personal por separado, crear un presupuesto a mano, la migración v1 → v2 y el rendimiento
(659 ms la primera apertura con 5.000 gastos; después entre 7 y 216 ms). VoiceOver no lo ha probado nadie.
"Trimestre acumulado" se entiende como del primer día del trimestre al final del mes mostrado.

Mejoras de la fase 3, a hacer al terminar la fase 4:
1. Orden del Resumen: tras el total, "Por revisar" y "Presupuestos"; después categorías, evolución, TVA y últimos gastos.
2. El botón "+" tapa importes a media lista: ocultarlo al desplazar hacia abajo y mostrarlo al subir o al parar.
3. El teclado tapa el campo del segundo importe de TVA en el formulario.
4. Accesibilidad: auditoría automática en las pruebas de interfaz de las pantallas principales.

**Fase 4 y mejoras de la fase 3, revisadas por el manager (18-11-2026), rama `fase-4` (`8118e0f`):**
pasan las 265 pruebas de paquete (195 + 10 + 60) y 5 de las 6 de interfaz. Comprobado en un simulador aparte
(iPhone 17, español): al instalar la fase 4 sobre los datos de la fase 3 los totales no cambian (792,03 €,
Pro 474,52 €, Personal 317,51 €); el Resumen sale reordenado; un importe de 48 USD se convierte con el tipo
real del BCE descargado en ese momento (1 € = 1,0989 USD, 17 nov., ≈ 43,68 €) y ofrece cambiar el tipo o
indicar los euros cargados. No comprobado por el manager (sí por el desarrollador o por pruebas): guardar el
gasto en USD a mano, reglas recurrentes, etiquetas, notificaciones, ocultación del botón "+" y el arreglo
del teclado. Decisión del manager: las reglas recurrentes quedan solo en euros en la versión 1.

Correcciones pendientes de la fase 4:
1. La prueba de accesibilidad falla siempre en el iPhone 17 (3 de 3) y pasa en el iPhone 18 Pro: no llega a
   abrir la pantalla de presupuestos y audita el Resumen. Hay que hacerla fiable en cualquier simulador.
2. `AccessibilityAuditUITests.swift` compila con 7 avisos de aislamiento al actor principal; el informe
   decía "sin avisos". El target de pruebas de interfaz debe compilar limpio como el resto.
3. En español, la opción del menú "+" se parte a media palabra ("Gasto sin justifican-te").

**Fase 4, decisiones del manager al encargarla (17-11-2026), a petición del usuario de seguir sin esperar
a la revisión de la fase 3:**
- Parte de `fase-3` en una rama `fase-4`. Las correcciones que salgan de la revisión de la fase 3 se hacen
  como commits en la rama más alta.
- **Etiquetas**: solo en Pro. Un gasto puede llevar un cliente y un proyecto.
- **Tipo de cambio**: tablas diarias públicas del BCE, descargadas como mucho una vez al día y solo cuando
  el usuario usa una moneda extranjera; la petición no lleva ningún dato del usuario. El tipo queda fijado
  en el gasto al guardarlo, con su fecha y su origen (BCE o manual), y siempre es editable. Sin conexión se
  usa el último tipo guardado, indicando su fecha; si no hay ninguno, se pide a mano. Ajuste para desactivar
  la descarga. Es el primer uso de red de la app y debe decirse así en la ficha de privacidad.
- **Notificaciones**: todas locales y desactivadas hasta que el usuario las activa; el permiso se pide en
  ese momento, nunca al arrancar. Tres avisos: cierre del periodo de TVA (mensual o trimestral, con día
  configurable), gasto recurrente previsto para hoy, y presupuesto cruzado por un gasto creado sin que el
  usuario esté en la app. Si el usuario está añadiendo el gasto, basta el aviso dentro de la app.
- **Recurrentes**: sin backend, se generan al abrir la app, recuperando las fechas pasadas pendientes;
  los de Pro nacen con el justificante pendiente.

Orden de las fases 5 a 13 (19-11-2026): el rediseño va primero porque cambia todas las pantallas y cada
pantalla nueva ya nace con el diseño v2; las mejoras de la fase 6 van antes de los informes porque el gasto
mixto cambia lo que estos suman; Apple Pay sigue después de seguridad porque depende de cómo queda protegida
la base; el reloj va después de las sesiones y de los widgets porque reutiliza ambos; el asistente va casi al
final porque nada depende de él.

## 7. Riesgos y cosas a tener en cuenta

- **Automatización de Apple Pay**: depende de Atajos, no de Bifaz. Hay informes de desarrolladores
  de pagos que llegan con comercio vacío o importe cero; por eso existen la bandeja "Por revisar"
  y el indicador de conexión. Su configuración es manual y no hay forma pública de crearla desde una app.
- **Precisión de la lectura**: tickets térmicos arrugados y facturas con varios tipos de TVA son los casos difíciles;
  la confirmación es obligatoria y se prueba con facturas reales.
- **Modelo de Apple**: solo en iPhones con Apple Intelligence. La app debe ser completa sin él.
- **APIs recientes**: se revisa la documentación del SDK 27.1 al empezar las fases 2, 9, 10, 11 y 12.
- **Modelo de datos e iCloud**: las restricciones de CloudKit condicionan el modelo; se cierra con cuidado en la fase 0.
- **Sincronización de justificantes**: al guardarse como archivos fuera de la base, no se sincronizan solos
  con iCloud; la fase 8 necesita un mecanismo propio y la copia `.bifaz` debe incluirlos.
- **Protección de datos**: el simulador no la aplica; hay que comprobarla en un iPhone real.
- **Copia cifrada**: si se olvida la contraseña, la copia no se puede recuperar; la app lo avisa al crearla.
- **Valor legal de la copia digital**: la versión 1 es archivo y control; conviene conservar los originales en papel.
- **Cuenta de desarrollador**: la cuenta de pago de Apple hace falta para iCloud y TestFlight (desde la fase 8).
- **Rediseño (fase 5)**: cambia todas las pantallas y el usuario ya rechazó una primera dirección visual en la
  fase 0. Por eso va en dos tramos, con la opción de mirarlo tras el 5a antes de extenderlo.
- **Licencia de outlayr**: es GPL-3.0. No se copia su código, iconos (Hugeicons Pro, de pago), textos ni
  ilustraciones: solo ideas de diseño y de interacción, reimplementadas en SwiftUI.
- **Ramas apiladas**: `fase-2` a `fase-5` siguen sin fusionar en `main` porque la fase 2 espera facturas reales
  y un iPhone. Cuanto más crezca la pila, más cuesta integrarla; conviene cerrar la fase 2 pronto.
- **Apple Watch**: WatchConnectivity solo funciona con el iPhone cerca y emparejado; el reloj debe guardar
  en cola lo que no pueda enviar y mostrarlo como pendiente. La prueba real necesita un Apple Watch.

## 8. Antes de empezar

1. Comprobar la disponibilidad del nombre **Bifaz** (App Store Connect, INPI, dominio).
2. Reunir 15–20 facturas y tickets franceses reales para las pruebas de lectura.
3. Tener a mano un iPhone real con una tarjeta en Wallet para la fase 9, y un Apple Watch para la fase 11.
4. Las herramientas de línea de comandos ya apuntan a Xcode 27.1 (hecho).

## 9. Evaluación de outlayr y revisión de funciones (19-11-2026)

### Qué es outlayr
App de código abierto de gastos, presupuestos y suscripciones para iPhone y Android
(github.com/danestves/outlayr): Expo y React Native, local primero, licencia GPL-3.0, en el App Store.
Se evaluó por sus 10 capturas de la ficha en español y su README. No se usa nada de su código.

### Qué tomamos (fase 5 salvo indicación)
| Idea de outlayr | Cómo queda en Bifaz |
|---|---|
| Papel cálido, mucho aire, separadores finos | Paleta v2 (sección 3) |
| Cifra grande con decimales atenuados y línea de tendencia | Cabecera del Resumen y de Gastos |
| Etiquetas de dato en monoespaciada mayúscula | Presupuestos, informes, widgets, reloj |
| Frase en serif que interpreta los datos | Frases de contexto y ritmo (fase 6) |
| Registro agrupado por día con total diario y hora | Lista de Gastos |
| Entrada "en una frase" con piezas tocables y chips opcionales | Nuevo gasto, edición y confirmación de lecturas |
| Comercios recientes como chips al escribir el comercio | Selector de comercio |
| Curva de consumo con proyección y "te van a faltar X" | Presupuestos (fase 6) |
| Próximos cargos con total al mes y aviso antes del cargo | Recurrentes (fase 6) |
| Menú del "+" con descripción bajo cada opción | Menú de captura |
| Widgets sobrios con etiquetas mono | Widgets (fase 10) y complicaciones (fase 11) |
| Dictar un registro | Asistente y dictado (fase 12) |

### Qué no tomamos
Cuentas y saldos, deudas, transferencias, metas de ahorro, compras a plazos, nóminas, 165 monedas,
inicio de sesión y servidor (Convex), logos de marcas en las filas y un único acento rojo: Bifaz es de gastos
y justificantes, con dos espacios que ya tienen su color.

### Lo que Bifaz ya hace mejor
- Lectura de justificantes con confianza por campo, emparejado y TVA por tipo: outlayr escanea tickets,
  pero no trata la TVA francesa ni los espacios Pro/Personal.
- Etiquetas de cliente y proyecto, recordatorio de TVA y, más adelante, informes para el expert-comptable.

### Revisión de funciones
**Ya existen y se mejoran** (fases 5 y 6): entrada de gastos (frase), historial (por día, monogramas),
Resumen (cifra, tendencia, frases de contexto), presupuestos (global por espacio, arrastre, ritmo),
recurrentes (próximos cargos y aviso previo), memoria de comercios (proponer también el espacio),
menú de captura (descripciones).

**Faltan y ya estaban en el plan**: informes y exportación (7), Face ID, copia cifrada e iCloud (8),
Apple Pay y sesiones (9), extensión de compartir y widgets (10), asistente (12), splash y bienvenida (13).

**Faltan y se añaden**: gasto mixto Pro/Personal y Factur-X (6), controles y Siri/Spotlight (10),
Apple Watch (11), dictado (12), bienvenida que pregunta el régimen de TVA (13).

**Para después de la v1**: importación CSV, indemnités kilométriques, TVA deducible por categoría,
reglas recurrentes en otra moneda.
