# Bifaz — Plan de trabajo

App iOS para guardar facturas profesionales y gastos personales en un mismo sitio.
Simple de usar, con acabado premium y preparada para publicarse en el App Store.

Estado: **fases 0 y 1 entregadas y revisadas el 17-11-2026 (commits `213828c` y `344cd4d`).
Las 6 correcciones de la fase 1 están integradas en `main` (`838147d`). La fase 2 está entregada y revisada
en simulador en la rama `fase-2` (`301e7ff`), sin fusionar y **sin aceptar**: falta probarla con facturas
reales (`TestData/Real/`, fuera de git) y en un iPhone real (escáner, modelo de Apple, cifrado).**

## 1. Decisiones cerradas

| Tema | Decisión |
|---|---|
| Nombre | **Bifaz** (elegido el 17-11-2026; marca en el INPI y dominios por confirmar) |
| Empresa / identificador | dvxlabs · `com.dvxlabs.bifaz` |
| Plataforma | iOS nativo, SwiftUI, Swift 6.4 (Xcode 27.1, SDK iOS 27.1) |
| iOS mínimo | iOS 26 |
| Dispositivos | Solo iPhone en la versión 1 |
| Dirección visual | Sobria, de neobanco: fondo blanco, texto alineado a la izquierda, botones tinta y color solo para distinguir Pro de Personal. Elegida por el usuario en la fase 0 tomando Qonto como referencia de sobriedad, sin copiar sus elementos de marca |
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
- Una fase se cierra solo con compilación limpia, pruebas en verde y capturas del simulador revisadas por el manager.
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
- La paleta de categorías para gráficos se define y valida en la fase 3.

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
- Widgets: gasto del mes y captura rápida.
- Ajuste "Sujeto a TVA: sí / no" (con "no" se ocultan los campos de TVA).

### Fuera de la versión 1
Conexión bancaria, emisión de facturas, contabilidad completa, equipos o multiusuario,
ingresos, Android y web, suscripciones de pago, valor legal de "copie fiable".

## 5. Arquitectura

- **Interfaz**: SwiftUI con Observation, `NavigationStack`.
- **Datos**: SwiftData en el contenedor de un App Group desde el primer día
  (lo comparten app, extensión de compartir y widgets). Modelo compatible con CloudKit desde el inicio
  (valores por defecto u opcionales, relaciones opcionales, sin unicidad).
- **Justificantes**: desde la fase 1 el modelo guarda solo el nombre del archivo; los archivos van a una
  carpeta propia con protección `.complete` (legibles solo con el iPhone desbloqueado). Consecuencia:
  ya no viajan a iCloud con la base de datos, así que la fase 6 debe sincronizarlos por su cuenta.
- **Importes**: siempre `Decimal`.
- **Concurrencia**: modo de lenguaje Swift 6 con comprobación estricta; lectura, informes y copia fuera del hilo principal.
- **Apple Pay**: App Intents ("Registrar pago", "Iniciar sesión", "Cerrar sesión") que se ejecutan
  en segundo plano sin abrir la app; ActivityKit para la sesión en curso.
- **Estructura**: paquete local `BifazKit` (modelos, persistencia, lectura, informes, seguridad, sistema de diseño).
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

Cada fase termina con la app funcionando y sus pruebas en verde.

| Fase | Contenido | Hecho cuando |
|---|---|---|
| 0. Cimientos y marca | Proyecto, `BifazKit`, App Group, modelo de datos, tokens y componentes del sistema de diseño, logo vectorial e icono, pantalla de lanzamiento estática, textos en 3 idiomas | La app arranca con las pestañas vacías, con la marca aplicada, en 3 idiomas, claro y oscuro |
| 1. Núcleo | Gasto rápido, espacios, categorías, historial, búsqueda, filtros, detalle y edición | Se lleva el control de gastos a mano de principio a fin |
| 2. Captura y lectura | Escáner, importar foto y PDF, lectura, extracción (modelo + reglas), confirmación | Una factura francesa típica se guarda con comercio, fecha, total y TVA correctos sin teclear |
| 3. Resumen y presupuestos | Gráficos, comparación mensual, TVA acumulada, presupuestos | El resumen cuadra con el historial al céntimo |
| 4. Funciones Pro | Etiquetas, recurrentes, multi-moneda, recordatorio de TVA | Un gasto en USD y un abono mensual salen bien en resumen e informes |
| 5. Informes y exportación | Los 4 informes PDF, CSV, ZIP | El informe de TVA de un trimestre se puede enviar tal cual al expert-comptable, en francés |
| 6. Seguridad y copia | Data Protection, Face ID, copia cifrada `.bifaz`, iCloud opcional | Una copia restaurada en otro simulador recupera todos los gastos y justificantes; con contraseña errónea no abre |
| 7. Apple Pay y sesiones | App Intents, guía de conexión, validación, sesiones con actividad en vivo, emparejado de justificantes | En un iPhone real, un pago con Apple Pay aparece solo en Bifaz y su ticket escaneado después se le adjunta sin intervención |
| 8. Extensiones | Extensión de compartir, widgets | Un PDF de Mail llega a la confirmación en dos toques |
| 9. Asistente | Preguntas en lenguaje natural con herramientas de consulta | Responde bien un banco de 30 preguntas en los 3 idiomas |
| 10. Splash, pulido y lanzamiento | Splash animado, bienvenida, estados vacíos, accesibilidad, rendimiento con miles de gastos, TestFlight, ficha y etiquetas de privacidad | Versión candidata en TestFlight |

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

**Fase 2, revisada por el manager en simulador (17-11-2026), rama `fase-2` (`301e7ff`):** pasan 173 pruebas
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

Mejoras detectadas en la revisión (no bloquean):
1. La lectura no propone categoría: los gastos leídos quedan "Sin categoría" (p. ej. Monoprix, SNCF).
2. El comercio sale con mayúsculas irregulares ("Totalenergies Relais A6 - AIRE DE Beaune") y aun así marcado "Seguro".
3. El texto de "Leyendo su justificante…" se superpone al contenido de fondo; falta un velo más opaco.
4. Cerrar la confirmación con la "X" descarta la lectura sin preguntar.
5. El menú del "+" parpadea en oscuro al cerrarse.

Tras la fase 2 la app ya sirve a diario; Apple Pay va después de seguridad porque depende
de cómo queda protegida la base de datos; el asistente va casi al final porque nada depende de él.

## 7. Riesgos y cosas a tener en cuenta

- **Automatización de Apple Pay**: depende de Atajos, no de Bifaz. Hay informes de desarrolladores
  de pagos que llegan con comercio vacío o importe cero; por eso existen la bandeja "Por revisar"
  y el indicador de conexión. Su configuración es manual y no hay forma pública de crearla desde una app.
- **Precisión de la lectura**: tickets térmicos arrugados y facturas con varios tipos de TVA son los casos difíciles;
  la confirmación es obligatoria y se prueba con facturas reales.
- **Modelo de Apple**: solo en iPhones con Apple Intelligence. La app debe ser completa sin él.
- **APIs recientes**: se revisa la documentación del SDK 27.1 al empezar las fases 2, 7 y 9.
- **Modelo de datos e iCloud**: las restricciones de CloudKit condicionan el modelo; se cierra con cuidado en la fase 0.
- **Sincronización de justificantes**: al guardarse como archivos fuera de la base, no se sincronizan solos
  con iCloud; la fase 6 necesita un mecanismo propio y la copia `.bifaz` debe incluirlos.
- **Protección de datos**: el simulador no la aplica; hay que comprobarla en un iPhone real.
- **Copia cifrada**: si se olvida la contraseña, la copia no se puede recuperar; la app lo avisa al crearla.
- **Valor legal de la copia digital**: la versión 1 es archivo y control; conviene conservar los originales en papel.
- **Cuenta de desarrollador**: la cuenta de pago de Apple hace falta para iCloud y TestFlight (desde la fase 6).

## 8. Antes de empezar

1. Comprobar la disponibilidad del nombre **Bifaz** (App Store Connect, INPI, dominio).
2. Reunir 15–20 facturas y tickets franceses reales para las pruebas de lectura.
3. Tener a mano un iPhone real con una tarjeta en Wallet para la fase 7.
4. Las herramientas de línea de comandos ya apuntan a Xcode 27.1 (hecho).
