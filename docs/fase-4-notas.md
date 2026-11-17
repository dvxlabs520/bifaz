# Fase 4 · Etiquetas, recurrentes, multi-moneda y recordatorios: notas para la revisión

Rama `fase-4`, creada desde `fase-3` en el commit `ff4aa96`, que incluye tu `PLAN.md`. Worktree en `.worktrees/fase-4`.
No se ha fusionado nada en `main`. Las fases 2 y 3 siguen sin aceptar.

Criterio: un gasto en USD y un abono mensual salen bien en el Resumen y en el historial.

## Modelo: esquema v3
**Por qué hace falta un esquema nuevo.** El gasto tiene que guardar el tipo de cambio aplicado y de qué regla y día viene. Además, las etiquetas se archivan y la memoria de comercios recuerda cliente y proyecto.

| Entidad | Campos nuevos (todos opcionales o con valor por defecto) |
|---|---|
| Gasto | `exchangeRate` (1 € = x unidades), `exchangeRateDate`, `exchangeRateSourceRawValue` (BCE, BCE aproximado o manual), `recurrenceDate` |
| Etiqueta | `isArchived`; relaciones inversas con la memoria de comercios |
| Regla recurrente | `startDate` (ancla), `endDate`, `generatedThrough` (último día ya tratado) |
| Memoria de comercio | `client`, `project` |

- **v2 congelado.** El v2 queda congelado en `ModelsV2.swift` y el v3 vive en `ModelsV3.swift`.
- **Etapa v2 → v3.** Es de añadir campos. Después, a cada regla existente se le da `startDate = nextDate`: antes de v3 la próxima fecha era todo el calendario que tenía una regla. Sin este paso, la migración le habría puesto la hora de la migración.
- **Etapa v1 → v2.** Ahora usa explícitamente las clases de v2, así sigue funcionando dentro de la cadena v1 → v2 → v3.
- **Pruebas de migración, sobre almacenes en disco.**
  - **v1 → v3.** Se comprueba campo a campo que no se pierde nada y que ningún importe cambia, y que las líneas de TVA se crean.
  - **v2 → v3.** El gasto, sus líneas, su etiqueta, la regla y la memoria se conservan. Los campos nuevos quedan con su valor por defecto y la regla conserva su fecha.
  - **Reabrir un almacén ya migrado** no cambia nada.
- **CloudKit.** Las pruebas de compatibilidad siguen en verde: todo opcional o con valor por defecto, relaciones opcionales con su inversa, sin unicidad.

## Qué hay

### 1. Etiquetas de cliente y proyecto (solo Pro)
- **Gestión:** en Ajustes → Clients et projets se crean, renombran, archivan y borran. Borrar una etiqueta no borra gastos, solo se la quita.
- **Formulario Pro:** selector de cliente y de proyecto con creación rápida («Nouveau client… »). En Personal no aparece. Al guardar en Personal se quitan.
- **Memoria de comercio:** si el último gasto Pro de un comercio llevaba cliente o proyecto, se proponen con la etiqueta «Proposée», igual que la categoría. Un gasto personal no borra lo aprendido en Pro.
- **Historial y detalle:** el historial filtra por cliente y por proyecto (como mucho uno de cada; las archivadas también filtran). El detalle los muestra. El Resumen no tiene desglose por etiqueta: eso es la fase 5.

### 2. Gastos recurrentes
- **Crear y gestionar:**
  - se crean desde un gasto en euros (botón «Répéter» del detalle: mismo día del mes siguiente) o desde Ajustes → Dépenses récurrentes;
  - la regla guarda importe, espacio, categoría, comercio, tipo de TVA, cliente y proyecto, frecuencia (semanal, mensual, trimestral o anual), inicio y fin opcional;
  - la lista muestra el próximo cargo y el coste mensual equivalente, y permite pausar, editar y borrar.
- **Calendario anclado al inicio:**
  - un cargo el día 31 cae el 30 en abril y vuelve al 31 en mayo;
  - un cargo el 29 de febrero cae el 28 los años normales y el 29 en los bisiestos;
  - el editor enseña los 3 próximos cargos.
- **Generación:** al abrir la app y al volver a primer plano, también justo después de guardar una regla. Recupera todas las fechas pendientes.
  - **Nunca dos veces.** `generatedThrough` evita repetir. Un gasto generado que el usuario borra no vuelve.
  - **Entre dispositivos.** Cada gasto generado lleva un identificador derivado de regla + día (SHA-256 → UUID). En otro dispositivo, con iCloud en la fase 6, sería el mismo gasto.
  - **Pausa.** Los cargos que caen durante la pausa se saltan.
  - **Editar** solo cambia los cargos futuros. **Borrar la regla** conserva sus gastos.
- **Gastos generados:** recuerdan su regla y su día, y se editan o borran sin tocar la regla. Los de Pro nacen con «justificatif manquant».
- **Limitación (decisión mía):** las reglas son solo en euros, el servicio rechaza otra moneda. Una regla en dólares necesitaría decidir qué tipo aplicar en cada cargo generado sin el usuario delante. Lo dejo para que lo decidas tú.

### 3. Multi-moneda
- **Selector de moneda** junto al importe: euro por defecto, las 29 monedas que publica el BCE (con su nombre) y «Autre devise… » para otro código con tipo manual. El lector de justificantes ahora detecta la moneda; ver la nota abajo.
- **Elección del tipo** (`CurrencyConverter.quote`):
  - el día del gasto, o el último día hábil anterior, hasta 4 días antes: «taux BCE du 17 nov.»;
  - si no, el día más cercano disponible, marcado como «approximatif».
- **Siempre editable:** se puede escribir el tipo, o directamente los euros que cargó el banco. En ese caso se guardan esos euros exactos y el tipo que implican, con 10 decimales, como origen manual.
- **Al guardar** se fijan importe original, moneda, tipo, fecha del tipo, origen e importe en euros. El tipo no se recalcula nunca después: editar otro campo lo conserva.
- **Sin conexión, o con la descarga desactivada:** se usa el último tipo guardado y se indica su fecha («Hors ligne : derniers taux enregistrés le … »). Si no hay ninguno, se piden el tipo o los euros. La red nunca bloquea el guardado.
- **Descarga:**
  - URLs: `eurofxref-daily.xml`, y `eurofxref-hist-90d.xml` cuando hace falta;
  - como mucho una vez al día, solo al usar una moneda extranjera, nunca en segundo plano ni al arrancar;
  - petición efímera, sin cookies ni caché, sin ningún dato del usuario;
  - tras un fallo no reintenta en 15 min;
  - la tabla se guarda en el contenedor de la app (unos 120 días, ~25 KB).
- **Presentación:** en listas y detalle el importe principal va en euros y el original debajo («48,00 $US · 13 nov.»). Totales, presupuestos y gráficos siguen en euros. La TVA de un gasto en moneda extranjera se convierte a euros en el Resumen.
- **TVA en moneda extranjera:** sus campos van ocultos por defecto, con un botón «Ajouter la TVA».
- **Redondeo:** euros = importe / tipo, al céntimo redondeando hacia arriba en el medio, siempre con `Decimal`.

**Nota sobre el lector.** El encargo da por hecho que el lector ya detectaba la moneda, pero no lo hacía: siempre devolvía EUR. Le he añadido la detección por símbolos ($, £, ¥, CA$, A$, US$…) y por códigos ISO como palabras completas. Un ticket en euros que menciona otra moneda una vez sigue en euros. Las 20 facturas sintéticas siguen en EUR.

### 4. Notificaciones locales
- **Ajustes → Rappels:** tres interruptores, todos apagados de inicio.
  - El permiso del sistema se pide al encender el primero, nunca al arrancar ni al abrir la pantalla.
  - Si se deniega, el interruptor vuelve a apagarse y aparece la explicación con «Ouvrir les Réglages».
- **Cierre de TVA:**
  - solo con «Assujetti à la TVA» activo;
  - mensual o trimestral (enero, abril, julio y octubre), con día de vencimiento configurable (1–28, por defecto 19) y aviso N días antes (por defecto 3), a las 9:00;
  - si el periodo ya ha terminado al programarlo, el texto lleva la TVA deducible del periodo; si no, un texto genérico;
  - se programan los 2 próximos.
- **Gasto recurrente previsto para hoy:** a las 9:00 del próximo cargo de cada regla activa, como mucho 40. El texto explica que se añadirá al abrir Bifaz.
- **Presupuesto:** solo cuando lo cruza un gasto generado sin el usuario delante (hoy, los recurrentes generados al abrir). Si el usuario añade el gasto él mismo, basta el aviso dentro de la app de la fase 3.
- **Reprogramación:** se reprograma todo al abrir, al volver a primer plano, al cambiar los ajustes y al guardar una regla. Solo se tocan los avisos de Bifaz (prefijo `bifaz.`).
- **Al tocar un aviso:**
  - el de TVA abre el Resumen en Pro;
  - el de recurrente abre Ajustes → Dépenses récurrentes con el editor de esa regla;
  - el de presupuesto abre Budgets.

## Privacidad y primer uso de red
- **Manifiesto de privacidad** (`PrivacyInfo.xcprivacy`): revisado, sin cambios necesarios.
  - Bifaz no recoge datos: `NSPrivacyCollectedDataTypes` sigue vacío.
  - No hace seguimiento ni usa dominios de seguimiento; el del BCE no lo es.
  - Las API con motivo declarado siguen siendo solo `UserDefaults`. La fecha de la tabla va dentro del propio JSON, no se lee la fecha del archivo.
- **Textos que prometían «nada sale del iPhone»:** la frase de la pantalla de lectura («Sur votre iPhone. Rien n’en sort.») pasa a decir «Lu sur votre iPhone. Le justificatif n’en sort pas.». Sigue siendo cierta para la lectura y no promete que la app nunca use la red. El resto de textos sobre la lectura («Sur votre iPhone») siguen siendo ciertos.
- **Ajuste nuevo:** Ajustes → Taux de change → «Télécharger les taux de change de la BCE» (activado por defecto), con su explicación. Apagado, Bifaz no usa la red.

### Texto propuesto para la ficha del App Store
- **Etiquetas de privacidad («App Privacy»):** «Données non collectées». La descarga de tipos no envía datos del usuario: Apple no la considera recogida.
- **Descripción, sección de privacidad:**
  - **fr:** « Bifaz fonctionne entièrement sur votre iPhone : vos dépenses et vos justificatifs ne quittent jamais l’appareil et sont lus sur place. La seule connexion de l’app est facultative : quand vous saisissez un montant en devise étrangère, Bifaz télécharge au plus une fois par jour les taux de référence publics de la Banque centrale européenne. Cette requête ne contient aucune information sur vous ni sur vos dépenses, et vous pouvez la désactiver dans Réglages. Aucune publicité, aucun suivi, aucun compte. »
  - **es:** «Bifaz funciona por completo en tu iPhone: tus gastos y justificantes nunca salen del dispositivo y se leen en él. La única conexión de la app es opcional: cuando indicas un importe en moneda extranjera, Bifaz descarga como mucho una vez al día los tipos de referencia públicos del Banco Central Europeo. Esa petición no contiene ningún dato sobre ti ni sobre tus gastos, y puedes desactivarla en Ajustes. Sin publicidad, sin seguimiento, sin cuenta.»
  - **en:** “Bifaz runs entirely on your iPhone: your expenses and receipts never leave the device and are read on it. The app’s only connection is optional: when you enter an amount in a foreign currency, Bifaz downloads the European Central Bank’s public reference rates, at most once a day. That request contains nothing about you or your expenses, and you can turn it off in Settings. No ads, no tracking, no account.”
- **URL de la política de privacidad:** pendiente para la fase 10. El texto anterior puede servir de base.

## Verificado por mí en el simulador (iPhone 18 Pro, francés)
- **Gasto en USD y regla mensual en Resumen e historial, al céntimo.** Datos de ejemplo con un GitHub de 48 USD y la regla «Loyer bureau» de 450 € mensuales, que empezó hace dos meses.
  - Al abrir, la regla generó sus 3 gastos (5 sept., 5 oct. y 5 nov.), Pro y con justificante pendiente. Tras varios arranques siguen siendo 3.
  - GitHub sale como 43,43 € con «48,00 $US · 13 nov.».
  - Noviembre cuadra: Pro 967,95 €, Tout 1 285,46 € y Perso 317,51 €, iguales en el Resumen y en Dépenses.
- **Filtro por cliente:** «Studio Nord» deja 3 gastos que suman 278,10 €.
- **Detalle de un gasto en dólares:** muestra el importe original, el tipo (1 € = 1,1052 USD) y su origen (BCE, 13 nov. 2026).
- **Formulario en dólares con descarga real del BCE:** 25 USD ≈ 22,75 € a 1,0989, «taux BCE du 17 nov.». La tabla queda guardada (~25 KB).
- **Recordatorio de TVA:**
  - al encender el interruptor aparece el permiso del sistema, y no antes;
  - acepté y se programaron los dos avisos (16 dic. y 16 ene.), con la fecha y el periodo visibles en la pantalla;
  - con `-BifazReminderDelay 20` (solo Debug), el primero se disparó y se ve en el centro de notificaciones: «Déclaration de TVA bientôt — Préparez la déclaration de novembre 2026, à déposer avant le 19 décembre.».
- **Pantallas de Ajustes:** Clients et projets, Dépenses récurrentes con su editor y los 3 próximos cargos, Rappels y Taux de change.
- **Errores encontrados y corregidos en el simulador:**
  - en «Clients et projets» y «Dépenses récurrentes» salían claves sin traducir;
  - nombres de moneda en minúscula en el menú.
- **Error encontrado por la prueba de interfaz y corregido:** sin tipo guardado, al teclear el primer dígito del tipo el panel se plegaba y se perdía el resto. Ahora los campos siguen visibles mientras se escribe.

## Cubierto solo por pruebas automáticas
- **Migraciones** v1 → v3 y v2 → v3 en disco.
- **BCE:**
  - parser de las tablas guardadas (diaria y de 90 días);
  - elección del día: fin de semana, aproximado, futuro y moneda desconocida;
  - conversión en los límites: 0,01, 9.999.999,99 y tipo 0;
  - tipo implícito con ida y vuelta exacta;
  - servicio: una descarga al día, uso sin conexión, fallo con vuelta a la tabla guardada, sin reintento inmediato y nada guardado ni descargable. Ninguna prueba sale a internet.
- **Recurrentes:**
  - días 31 y 29 de febrero, semanal con cambio de hora, trimestral y fin;
  - recuperación, idempotencia (también simulando otro dispositivo), borrado sin regenerar, pausa, edición solo de lo futuro y Personal sin etiquetas;
  - rechazo de otra moneda y de un fin anterior al inicio.
- **Etiquetas:** duplicados (mayúsculas y acentos), renombrar, archivar, borrar sin borrar gastos, solo Pro, memoria y filtro.
- **Moneda:** tipo fijado, euros cargados, vuelta a euros y TVA extranjera en euros.
- **Avisos:** TVA mensual y trimestral con su periodo, contenido con o sin importe, sin «Assujetti», recurrentes (futuros, sin las pausadas), presupuesto solo si está activado y rutas.
- **Lector:** detección de moneda; las 20 sintéticas en EUR.
- **Pruebas de interfaz nuevas:**
  - gasto de 48 USD con tipo 1,2 tecleado: 40,00 € en el Resumen y «$48.00» en la fila;
  - regla mensual creada desde Ajustes que genera su gasto del día y aparece en el Resumen.
- **Batería completa** del esquema `Bifaz`, sobre las mejoras finales:
  - 195 pruebas de modelos, 10 de diseño y 60 de lectura, más 6 de interfaz (incluida la auditoría de accesibilidad);
  - en verde y sin avisos del compilador (solo el aviso habitual de `appintentsmetadataprocessor`).

## No comprobado, o que no se puede probar en el simulador
- **Tocar una notificación desde la pantalla de bloqueo** no abrió la app con los toques simulados. La lógica de rutas está probada; el gesto real no.
- **Aviso de presupuesto del sistema con un recurrente generado:** solo con pruebas del planificador; no lo he disparado en el simulador.
- **Aviso de recurrente del día:** la programación se ve en el registro, pero no he esperado a que se dispare.
- **Sin conexión de verdad:** el simulador usa la red del Mac. Sin red, o con el ajuste apagado, solo tiene pruebas automáticas, salvo que la tabla guardada existe.
- **Qué no se puede probar en el simulador:**
  - la entrega real de notificaciones a la hora prevista con el iPhone bloqueado durante días;
  - el comportamiento de la red móvil;
  - la generación con dos dispositivos sincronizados, que depende de iCloud (fase 6).

## Nota de proceso
El `PLAN.md` del manager con la revisión de la fase 3 quedó dentro de mi commit `9c8ee4c` («Piezas compartidas…»), no en uno propio. Lo editó mientras yo usaba `git add -A`. El contenido es el suyo, sin tocar. No he reescrito el historial porque pidió no rebasar. Desde entonces añado solo rutas explícitas.

## Defectos menores pendientes
- En la pantalla de Rappels, los interruptores necesitaron una pulsación algo más larga con la herramienta de toques del simulador. Es cosa de la herramienta, no de la app. Conviene confirmarlo con el dedo en el iPhone.

## Mejoras de la revisión de la fase 3 (hechas al final de la fase 4)
1. **Orden del Resumen** (`2cb7ccc`): total → Por revisar (solo si hay algo) → Presupuestos → Por categoría → Seis meses → TVA → Últimos gastos. Capturas 11, 11b (español, oscuro) y 11c.
2. **Botón «+»** (`456081a`):
   - se aparta hacia abajo al desplazar hacia abajo en Resumen, Gastos y Ajustes, y vuelve al subir, al soltar o al quedarse quieto;
   - con «Reducir movimiento» solo se desvanece;
   - con VoiceOver activo nunca se oculta;
   - el desplazamiento no se resiente: comprobado en un vídeo del simulador fotograma a fotograma, solo se anima la capa del botón.
   Por diseño vuelve al detenerse, así que en reposo puede seguir tapando algo a media lista. El margen inferior de las listas garantiza que la última fila queda libre.
3. **Teclado** (`e21a2e4`): el campo enfocado se desplaza al centro de la parte visible. Cubre importe, comercio, nota y el segundo importe de TVA, que antes quedaba tapado (captura 12). Con texto grande (AccessibilityXL) el importe queda visible. El título de la barra se corta («Nouv… »): es el comportamiento del sistema con un título en línea y dos botones.
4. **Accesibilidad** (`77f628e`): prueba de interfaz `AccessibilityAuditUITests` con `performAccessibilityAudit` en Résumé, Dépenses, detalle, formulario, Budgets y Réglages, con los datos de ejemplo y en francés. Ha pasado dos veces seguidas. Encontró y corregí:
   - **un problema real:** el selector Tout/Pro/Perso se exponía a VoiceOver como un Picker cuyos marcos no coincidían con los botones visibles. Ahora VoiceOver ve los botones reales, con el estado «seleccionado», agrupados bajo la etiqueta del selector.
   **Exclusiones explícitas** (en el código de la prueba, `isKnownFalsePositive`):
   - **Contraste de lo que pasa por debajo de la barra de pestañas translúcida y del botón «+»** (110 pt inferiores): la auditoría mide el color a través del material. Ejemplos: «Restaurants», «Statut», «TVA», «Gérer».
     También 5 avisos de contraste en Dépenses que la auditoría no asocia a ningún elemento. Los atribuyo a lo mismo, pero no he podido localizarlos con certeza.
   - **Botones de la barra superior** («Modifier», «Répéter», «Enregistrer») **y el título en línea:** son de sistema (Liquid Glass). Su contraste y su límite de Dynamic Type los pone iOS.
   - **El buscador del historial mientras se pliega** (9 pt de alto): «texto recortado» durante la animación.
   - **Dynamic Type de los botones Tout/Pro/Perso:** sí crecen, y con texto grande la fila pasa a columna (`ViewThatFits`; comprobado a mano en AccessibilityXL). La auditoría lo informa como «parcialmente no soportado».
   - **Otro hallazgo:** con la auditoría justo después de cambiar de pestaña salían avisos de contraste en textos secundarios que cumplen AA (#6A6C72 sobre blanco, 5,3:1), por medir a mitad del fundido. La prueba espera a que la pantalla se asiente.

## Capturas (`docs/capturas/fase-4/`, francés)
- **01:** historial Pro con el gasto en dólares y el gasto generado por la regla.
- **02:** historial filtrado por cliente.
- **03:** Resumen Pro.
- **03b:** formulario en dólares con el tipo BCE.
- **04:** detalle del gasto en dólares.
- **05:** dépenses récurrentes.
- **06 y 06b:** editor de la regla, con frecuencia y próximos cargos.
- **07:** clients et projets.
- **08:** rappels.
- **09:** recordatorio de TVA en el centro de notificaciones.
- **10:** réglages.
- **11, 11b y 11c:** Resumen reordenado (francés; español en oscuro; presupuestos tras «Por revisar»).
- **12:** segundo importe de TVA visible con el teclado abierto.

## Para el plan (decide el manager)
- **Reglas recurrentes solo en euros:** ¿se admite moneda extranjera? Si sí, hay que decidir qué tipo aplicar en cada cargo generado.
- **Fecha límite de la TVA por defecto:** día 19. Conviene confirmar el día habitual del usuario, que depende del régimen.
- **Datos de ejemplo de depuración:** `-BifazSampleData` añade ahora el cliente, el proyecto, el gasto en dólares y la regla. `-BifazReminderDelay <s>` adelanta el primer aviso de TVA. Las dos opciones solo existen en Debug.
