# Fase 0 · Cambios propuestos a `PLAN.md`

Origen: el usuario revisó la primera versión visual de la fase 0 (New York en títulos e importes,
tarjetas, ilustración central, moneda cobalto/terracota sobre tinta) y la rechazó por genérica.
Tras comparar Copilot Money, Revolut, Qonto e Indy, eligió el enfoque de **Qonto** y el **icono 1**
(moneda blanca y melocotón sobre cobalto). La fase 0 está construida con esa dirección.
`PLAN.md` no se ha tocado: estos cambios necesitan que el manager los anote.

## §3 Marca · Logo
- Antes: moneda partida cobalto/terracota sobre fondo tinta; logotipo "Bifaz" en New York.
- Ahora: moneda partida **blanca (Pro) y melocotón `#FFB08A` (Personal) sobre cobalto `#2747D8`**,
  misma geometría (mitades desplazadas, hueco algo mayor: 0,024 del lienzo por lado).
  Logotipo: icono de la app + "Bifaz" en SF Pro seminegrita.
- Icono: Icon Composer con variantes claro, oscuro (cobalto profundo `#172573`), tintado y transparente.

## §3 Marca · Colores
| Token | Claro | Oscuro | Antes (claro / oscuro) |
|---|---|---|---|
| Tinta (texto) | `#1B1C1E` | `#F1F1F2` | `#10151D` / `#F2EFE8` |
| Tinta secundaria (nuevo) | `#6A6C72` | `#9C9EA4` | — |
| Papel (fondo) | `#FFFFFF` | `#0F1012` | `#F6F3EC` / `#0B1018` |
| Superficie (tarjetas) | `#FFFFFF` + borde | `#17181B` | `#FFFFFF` / `#151C27` |
| Superficie tenue (nuevo) | `#F4F4F6` | `#1F2023` | — |
| Línea fina (nuevo, no texto) | `#E7E8EB` | `#26282C` | — |
| Pro · Cobalto | `#2747D8` | `#8AA2FF` | sin cambio |
| Personal · Terracota | `#B8451A` | `#FF9466` | sin cambio |
| Éxito | `#1B7F50` | `#5BD69A` | claro `#1E8E5A` (no pasaba AA) |
| Aviso | `#98641A` | `#F2C261` | claro `#B7791F` (no pasaba AA) |
| Error | `#C4314B` | `#FF8097` | sin cambio |
| Tintes pastel (nuevos) | pro `#ECEFFC`, personal `#F9EEE8`, éxito `#EEF7F2`, aviso `#FFF3DC`, error `#FBE9EC` | equivalentes oscuros | — |

Todos los pares texto/fondo pasan AA (prueba automática `ContrastTests`).

## §3 Sistema de diseño
- **Tipografía**: SF Pro en toda la interfaz, pesos regular y medio; importes con cifras tabulares.
  Se retira New York (era la principal señal de "plantilla").
- **Componentes**: se añaden cápsula de filtro, icono de categoría con insignia de espacio,
  barra de reparto Pro/Personal, cabecera de sección, línea fina y botón secundario.
  El estado vacío pasa a ser texto alineado a la izquierda con botones, sin ilustración.
- Radios 12/20/28 y rejilla de 4 pt sin cambios.

## §3 Splash
- La pantalla de lanzamiento estática es ahora **fondo cobalto con la moneda blanca y melocotón**
  (antes: fondo tinta). El splash animado de la fase 10 debe partir de ese fotograma.

## Decisiones abiertas
- iPhone únicamente (`TARGETED_DEVICE_FAMILY = 1`). Si se quiere iPad, decidirlo antes de la fase 1.
- Cuenta de desarrollador de Apple: necesaria para firmar en dispositivo, App Group real, iCloud y TestFlight.
