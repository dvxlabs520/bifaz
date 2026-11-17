# Fase 1 · Núcleo — notas para el manager

## Qué hay
- **Gasto rápido** (botón «+» en cualquier pestaña): importe con teclado numérico y foco automático,
  espacio (viene del filtro activo), categorías del espacio, comercio con sugerencias de comercios
  conocidos (rellenan espacio y categoría), fecha, tipo de TVA (solo Pro y si «Sujeto a TVA» está activo,
  con la TVA incluida calculada al céntimo) y nota. Guardar con respuesta háptica.
- **Detalle y edición**: importe, fecha, espacio, categoría, TVA (tipo, importe y base HT), nota, origen,
  estado, fechas de creación y modificación. Edición con el mismo formulario; borrado con confirmación.
- **Historial** (Gastos): por meses con total, búsqueda (comercio, nota, categoría; sin acentos ni
  mayúsculas), filtros (periodo, categorías, solo justificante pendiente), deslizar para borrar.
- **Resumen** con datos reales: total del mes por espacio, reparto Pro/Personal, TVA soportada,
  «Por revisar» y últimos gastos. Gráficos y comparación mensual siguen en la fase 3.
- **Categorías**: 22 por defecto (12 Pro, 10 Personal) en el idioma del dispositivo; crear, renombrar,
  cambiar icono, reordenar y borrar (los gastos quedan sin categoría).
- **Ajuste «Sujeto a TVA»** (PLAN §4 «Sistema»): al desactivarlo se ocultan los campos de TVA.

## Cambios respecto al plan (para anotar en `PLAN.md`)
- **§3 Iconos**: el usuario pidió sustituir los SF Symbols («los por defecto son feos»). Bifaz tiene
  ahora un juego propio de 54 iconos de trazo fino (24 pt, trazo 1,6) en `BifazDesign/Resources/Icons.xcassets`
  (`BifazIcon`), usado en pestañas, componentes, categorías y acciones.
- **Plataforma**: confirmado por el usuario, solo iPhone por ahora.
- **Justificantes** (afecta a fase 2 y 6): el modelo ya no guarda el archivo dentro de SwiftData;
  guarda el nombre de archivo. Los justificantes irán a una carpeta propia con protección
  `.complete` (solo legibles con el iPhone desbloqueado), como pide §4 «Seguridad».

## Revisión de código (seguridad, rendimiento, mejoras) — aplicado
- Manifiesto de privacidad (`PrivacyInfo.xcprivacy`) para UserDefaults.
- Clase de protección explícita en la carpeta de la base (`completeUntilFirstUserAuthentication`).
- Esquema v1 congelado (modelos dentro de `BifazSchemaV1` con alias), índices en `Expense`
  (fecha, espacio+fecha, estado), precarga de la categoría en las consultas.
- `.allowsCloudEncryption` en importes, comercio, nota, TVA y texto leído (CloudKit los cifrará desde el primer despliegue).
- Importes solo modificables a través de `ExpenseService` (`internal(set)`), para que el resumen cuadre siempre.
- La base se abre fuera del hilo principal, con pantalla de marca mientras tanto y error con «Reintentar» y código.
- Portada de marca en el selector de apps (oculta importes desde ya, no en la fase 6).
- Ajustes en los UserDefaults del App Group (los verán widgets y extensión).
- Avisos tratados como errores (app y paquete); el esquema `Bifaz` ejecuta todas las pruebas.
- El script post-XcodeGen falla si sus sustituciones dejan de aplicarse.
- Registro de errores sin datos sensibles en público.
- Prueba nueva: toda clave usada en el código existe en algún catálogo.

## Pendiente o a decidir
- Ayudante común de formato de moneda (mantenimiento, sin efecto visible): pendiente.
- Una copia exportable de la base si no abre (escape de emergencia): con la fase 6.
- Pruebas de interfaz automatizadas (UI tests) de los flujos de la fase 1: no hay; verificado a mano en el simulador.
- La protección de datos no se puede comprobar en el simulador (no la aplica); comprobar en iPhone real.

## Correcciones de la revisión del manager (rama `fase1-correcciones`)
1. **Categorías en el idioma actual**: las categorías por defecto se guardan con `name` vacío y se
   identifican por `seedKey`; se muestran traducidas en cada dispositivo. Renombrar guarda el texto
   del usuario. **Sin cambio de esquema** (v1 congelado intacto, compatible con CloudKit: un
   `name` vacío viaja igual). Migración: reparación idempotente al arrancar
   (`CategorySeeder.adoptTranslatedDefaults`) que vacía el nombre si coincide con una traducción
   por defecto en en/es/fr. Pruebas nuevas.
2. **Borrado sin comercio**: variante «Cette dépense et son justificatif seront supprimés…» en los
   tres idiomas (historial y formulario de edición).
3. **Títulos alineados**: margen de pantalla de 16 pt (`BifazSpacing.screen`) = margen del título grande.
4. **Margen bajo el botón +**: `.bifazScreen()` reserva el alto del botón (escala con Dynamic Type).
5. **Pruebas de interfaz**: target `BifazUITests` en el esquema `Bifaz` (alta, edición, borrado con
   confirmación; total del mes comprobado en cada paso). `-BifazUITesting YES` (solo Debug) usa un
   almacén en memoria.
6. **Francés con «vous»**: 15 cadenas cambiadas; las 205 cadenas francesas revisadas con un script.

Capturas en `docs/capturas/fase-1-correcciones/` (francés).
