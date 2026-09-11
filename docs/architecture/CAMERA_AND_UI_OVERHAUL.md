# Cámara dinámica + rediseño animado de UI (Pausa/Tienda/Salir)

**Fecha:** 2026-09-11
**Rama:** `refactor/code-audit-cleanup`
**Alcance:** control de zoom manual en cámara, sistema de animación compartido para menús, rediseño de tienda, popup de confirmación de salida.

## Contexto

El juego tenía zoom de cámara 100% automático (fit-to-room), menús que abrían/cerraban sin transición, tienda con botones planos sin feedback visual, y un popup de salida usando `ConfirmationDialog` nativo de Godot sin estilo del juego. Se pidió: control de zoom para el jugador y pulido animado de los 3 menús principales, reusando infraestructura existente (`BaseMenu`/`BaseSubPanel`, `ThemeManager`/`QuestPalette`) en vez de duplicar lógica de tween por archivo.

## Decisiones confirmadas con el usuario

| Decisión | Elegido |
|---|---|
| Popup de salida | Reemplazo completo por `Control` custom (no reestilizar el `ConfirmationDialog` nativo) — permite bounce-scale real |
| Persistencia del zoom manual | Persiste entre salas (multiplicador relativo al fit de cada sala, no se resetea) |
| Color "peligro" en popup salir | Botón **Confirmar** = rojo/sangre (acción destructiva); **Cancelar** = dorado/seguro |

## 1. Zoom con rueda del mouse + zoom base más cercano

**Archivo:** `scripts/world/rooms/room_camera_controller.gd`

- Nuevo `_unhandled_input(event)` en el controlador (es un `Node` plano, no requiere ser `Control`).
- Modelo de zoom en capas: el cálculo de fit-to-room automático queda intacto; se le aplica un multiplicador manual persistente (`_manual_zoom_scale`) controlado por la rueda del mouse, siempre clamped dentro de `min_zoom`/`max_zoom` ya existentes.
- Zoom base más cercano: el fit-zoom se multiplica por `base_zoom_multiplier` antes del clamp, logrando un acercamiento inicial mayor.
- Scroll up/down ajusta el multiplicador y anima el cambio con `create_tween()` (sin pelear con el tween de transición de sala — se matan mutuamente antes de arrancar uno nuevo).
- Refactor: se extrajo `_get_active_camera()` para eliminar 3 lookups duplicados de `player → Camera2D`.
- Se agregó categoría `CAMERA` a `Logger.gd` (`scripts/core/utils/Logger.gd`).

**Nuevos `@export`:**
```gdscript
@export var enable_manual_zoom: bool = true
@export var manual_zoom_step: float = 0.1
@export var manual_zoom_min_scale: float = 0.7
@export var manual_zoom_max_scale: float = 1.8
@export var manual_zoom_tween_duration: float = 0.15
@export var manual_zoom_trans: Tween.TransitionType = Tween.TRANS_QUAD
@export var manual_zoom_ease: Tween.EaseType = Tween.EASE_OUT
@export var base_zoom_multiplier: float = 1.3
```

| Variable | Qué controla |
|---|---|
| `enable_manual_zoom` | Kill-switch del zoom manual desde el inspector |
| `manual_zoom_step` | Cuánto cambia el multiplicador por tick de rueda |
| `manual_zoom_min_scale` / `manual_zoom_max_scale` | Límites del multiplicador manual (relativo al fit de cada sala; el zoom absoluto sigue clamped por `min_zoom`/`max_zoom`) |
| `manual_zoom_tween_duration` / `_trans` / `_ease` | Velocidad y curva del tween al scrollear |
| `base_zoom_multiplier` | Acercamiento inicial pedido — valor de partida `1.3`, ajustar a ojo en editor |

## 2. Sistema de animación compartido (Pausa/Tienda/Salir)

**Nuevo:** `scripts/ui/menus/MenuTransitionFX.gd` — helper estático (`play_entrance`/`play_exit`) que arma tweens de fade + escala con `Tween.TWEEN_PAUSE_PROCESS` (necesario para que corran con el juego pausado). Reemplaza el cuerpo de `_play_fade_in/out()` en `BaseMenu.gd` y `BaseSubPanel.gd`, evitando duplicar la lógica en cada menú.

**`BaseMenu.gd` y `BaseSubPanel.gd`** ganan:
```gdscript
@export var entrance_scale_from: Vector2 = Vector2(0.92, 0.92)
@export var exit_scale_to: Vector2 = Vector2(0.94, 0.94)
@export var entrance_trans: Tween.TransitionType = Tween.TRANS_BACK
@export var entrance_ease: Tween.EaseType = Tween.EASE_OUT
```
más el método `add_scale_target(node)`, análogo al ya existente `add_fade_target(node, max_alpha)`.

| Variable | Qué controla |
|---|---|
| `entrance_scale_from` | Escala inicial del panel al abrir (0.92 = empieza un 8% más chico) |
| `exit_scale_to` | Escala final al cerrar |
| `entrance_trans` / `entrance_ease` | Curva del rebote de entrada (por defecto `TRANS_BACK`/`EASE_OUT`, da el efecto de "rebote suave") |

### Menú de Pausa (`PauseMenu.gd` / `PauseMenu.tscn`)
Se registró `PausePanel`, `BlurRect` y `DimRect` como fade targets y `PausePanel` como scale target; `animate_transitions = true` con `fade_duration_in = 0.22` / `fade_duration_out = 0.16`. `BlurRect`/`DimRect` se marcaron `unique_name_in_owner` para poder referenciarlos con `%`.

### Tienda (`StorePanel.gd` / `StorePanel.tscn`)
Mismo mecanismo aplicado sobre `%StoreCard`.

## 3. Rediseño de la tienda

**Nuevo:** `scripts/ui/menus/StoreUpgradeCard.gd` + `scenes/StoreUpgradeCard.tscn` — reemplaza los 4 botones planos (`UpgradeHPButton`, etc.) por cards (`PanelContainer`) con:
- Hover animado con tween real (`hover_scale`, a diferencia del patrón anterior de swap instantáneo de stylebox usado en `RewardCardOption.gd`).
- Borde con color de acento por stat, reusando constantes de `QuestPalette` (`CARD_STRENGTH`, `CARD_AGILITY`, `CARD_MAGIC`); se agregó `CARD_VITALITY` (nueva, mapeada a `MOSS`) para HP, que no tenía color propio.
- Sin íconos: se confirmó que no existen assets por-stat en `assets/ui` (`statui.png` es un fondo decorativo, no un ícono) — se optó por distinción por color + texto.

**Nuevos `@export` (`StoreUpgradeCard.gd`):**
```gdscript
@export var hover_scale: Vector2 = Vector2(1.04, 1.04)
@export var hover_tween_duration: float = 0.12
@export var border_width: int = 3
@export var border_width_hover: int = 4
```

`StorePanel.gd` se actualizó para configurar cada card (`configure(stat_key, color)`, `set_data(...)`) en vez de armar texto de botón a mano, y reenvía hover/unhover al tooltip existente del HUD.

## 4. Popup de confirmación de salida

Reemplazo completo del `ConfirmationDialog` nativo embebido en `PauseMenu.tscn` por una escena propia:

**Nuevo:** `scripts/ui/menus/ExitConfirmDialog.gd` + `scenes/ExitConfirmDialog.tscn` — extiende `BaseSubPanel`, reusa el mismo sistema de fade+scale (Task 2), con entrada `TRANS_BACK`/`EASE_OUT` (bounce). Mantiene el mismo contrato de señales que tenía el dialog nativo (`confirmed`/`canceled`), por lo que `PauseMenu.gd` no tuvo que cambiar su lógica de conexión, solo el tipo (`ConfirmationDialog` → `ExitConfirmDialog`) y el método de apertura (`popup_centered()` → `open()`).

**Nuevos `@export` (`ExitConfirmDialog.gd`):**
```gdscript
@export var confirm_text: String = "OK"
@export var cancel_text: String = "Cancelar"
@export var message_text: String = "¿Estás seguro de salir? Se perderán los datos de esta run actual."
```

Estilo: botón **Confirmar** con `_style_button(confirm_button, true)` (paleta `BLOOD`/danger), botón **Cancelar** con estilo seguro/dorado — mismo helper `_style_button` que ya usaba `PauseMenu.gd`.

`PauseMenu._on_before_close()` ahora también cierra el `exit_confirm_dialog` si estaba abierto, para evitar que quede huérfano al cerrar la pausa.

## Archivos tocados

**Nuevos:**
- `scripts/ui/menus/MenuTransitionFX.gd`
- `scripts/ui/menus/StoreUpgradeCard.gd` + `scenes/StoreUpgradeCard.tscn`
- `scripts/ui/menus/ExitConfirmDialog.gd` + `scenes/ExitConfirmDialog.tscn`

**Modificados:**
- `scripts/world/rooms/room_camera_controller.gd`
- `scripts/core/utils/Logger.gd`
- `scripts/ui/menus/BaseMenu.gd`
- `scripts/ui/menus/BaseSubPanel.gd`
- `scripts/ui/menus/PauseMenu.gd` + `scenes/PauseMenu.tscn`
- `scripts/ui/menus/StorePanel.gd` + `scenes/StorePanel.tscn`
- `scripts/core/theme/QuestPalette.gd`

## Verificación pendiente

No hay test suite/CI en el repo — verificación manual en editor (`godot --path .`):

1. Entrar a una sala, scrollear rueda del mouse sobre la cámara: zoom suave, respeta límites, no rompe el fit-to-room al cambiar de sala (multiplicador persiste).
2. Abrir/cerrar menú de pausa: fade + scale-in visibles, corre correctamente con el juego pausado.
3. Abrir tienda: cards con hover-scale + color de acento, animación de apertura/cierre, compra funcional (oro se descuenta, stat sube).
4. Presionar "Salir" en pausa: popup con bounce-scale, Confirmar en rojo, Cancelar en dorado, ambos flujos (confirmar → sale / cancelar → vuelve a pausa) funcionan igual que antes.
5. Confirmar en consola que no hay errores de `%UniqueName` no resuelto (`%BlurRect`, `%DimRect`, nodos nuevos de tienda y popup).

## Notas de diseño abiertas (no bloqueantes)

- `base_zoom_multiplier = 1.3` y los tiempos de tween/escala son puntos de partida — requieren ajuste a ojo en el editor.
- `OptionsMenu.gd`/`.tscn` tiene el mismo hook `animate_transitions` sin usar que `PauseMenu`/`StorePanel` — no se conectó en este pase por no haber sido pedido explícitamente; es un cambio de una línea si se quiere sumar después.
