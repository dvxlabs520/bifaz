# Bifaz — Plan de trabajo

App iOS para guardar facturas profesionales y gastos personales en un mismo sitio.
Simple de usar, con acabado premium y preparada para publicarse en el App Store.

Estado: **plan en revisión, desarrollo no iniciado.**

## 1. Decisiones cerradas

| Tema | Decisión |
|---|---|
| Nombre | **Bifaz** (elegido el 17-11-2026; marca en el INPI y dominios por confirmar) |
| Empresa / identificador | dvxlabs · `com.dvxlabs.bifaz` |
| Plataforma | iOS nativo, SwiftUI, Swift 6.4 (Xcode 27.1, SDK iOS 27.1) |
| iOS mínimo | iOS 26 |
| País fiscal | Francia: TVA 20 % / 10 % / 5,5 % / 2,1 %, moneda base EUR |
| Idiomas | Español, francés e inglés desde el primer día |
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
- Una moneda partida en dos mitades ligeramente desplazadas: mitad Pro (cobalto)
  y mitad Personal (terracota) sobre fondo tinta. Juntas forman el círculo completo.
- Dibujado como vector en código (misma geometría para icono, splash y marca dentro de la app).
- Icono de app en las variantes del sistema: claro, oscuro, tintado y transparente.
- Logotipo: "Bifaz" en serif (New York), con la moneda de dos mitades junto a la B inicial.

### Colores
Valores de partida; el contraste AA de cada par texto/fondo se valida en la fase 0.

| Token | Claro | Oscuro | Uso |
|---|---|---|---|
| Tinta | `#10151D` | `#F2EFE8` | Texto principal, botones primarios |
| Papel | `#F6F3EC` | `#0B1018` | Fondo |
| Superficie | `#FFFFFF` | `#151C27` | Tarjetas, hojas |
| Pro · Cobalto | `#2747D8` | `#8AA2FF` | Todo lo que pertenece al espacio Pro |
| Personal · Terracota | `#B8451A` | `#FF9466` | Todo lo que pertenece al espacio Personal |
| Éxito | `#1E8E5A` | `#5BD69A` | Confirmaciones, presupuesto en orden |
| Aviso | `#B7791F` | `#F2C261` | Presupuesto cerca del límite, justificante pendiente |
| Error | `#C4314B` | `#FF8097` | Errores, presupuesto superado |

- Cobalto y terracota son un par azul/naranja, distinguible con daltonismo;
  aun así el espacio siempre se indica también con texto o icono, nunca solo con color.
- La paleta de categorías para gráficos se define y valida en la fase 3.

### Sistema de diseño
- **Tipografía**: New York (serif del sistema) para títulos e importes grandes;
  SF Pro para la interfaz; cifras tabulares en todas las listas. Todo con Dynamic Type.
- **Espaciado**: rejilla de 4 pt. Radios 12 / 20 / 28.
- **Materiales**: Liquid Glass solo en barras y controles flotantes; el contenido va sobre superficies sólidas.
- **Iconos**: SF Symbols.
- **Movimiento**: animaciones de muelle cortas, respuesta háptica en guardar, escanear y cerrar sesión;
  todo respeta "Reducir movimiento".
- **Componentes**: importe, selector de espacio, fila de gasto, miniatura de justificante,
  chip de categoría, tarjeta de cifra, barra de presupuesto, botón primario, estado vacío,
  campo de confirmación (con indicador de confianza de la lectura).
- Tokens y componentes viven en `BifazKit` con vistas previas en claro, oscuro y texto grande.

### Splash animado
- Pantalla de lanzamiento estática: fondo tinta con la moneda quieta (idéntica al primer fotograma).
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
- **Justificantes**: archivo con almacenamiento externo y miniatura aparte.
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
- **Copia cifrada**: si se olvida la contraseña, la copia no se puede recuperar; la app lo avisa al crearla.
- **Valor legal de la copia digital**: la versión 1 es archivo y control; conviene conservar los originales en papel.
- **Cuenta de desarrollador**: la cuenta de pago de Apple hace falta para iCloud y TestFlight (desde la fase 6).

## 8. Antes de empezar

1. Comprobar la disponibilidad del nombre **Bifaz** (App Store Connect, INPI, dominio).
2. Reunir 15–20 facturas y tickets franceses reales para las pruebas de lectura.
3. Tener a mano un iPhone real con una tarjeta en Wallet para la fase 7.
4. Las herramientas de línea de comandos ya apuntan a Xcode 27.1 (hecho).
