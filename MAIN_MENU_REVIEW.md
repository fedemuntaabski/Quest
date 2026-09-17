# Main Menu & Options Menu — Review

Fecha: 2026-09-17. Estado tras eliminación del botón/pantalla de Créditos.

---

## 1. Estructura General del Menú Principal

### Botones y componentes activos (`scenes/MainMenu.tscn`)

Bajo `CenterContainer/VBoxContainer`, en orden:

| # | Nodo | Texto | Acción |
|---|------|-------|--------|
| 1 | `StartButton` | "INICIO" | `on_start_button_pressed` → `flow.start_pressed()` → abre `NetworkModeSelect` (Host/Join/Offline) |
| 2 | `OptionsButton` | "OPCIONES" | `_on_options_button_pressed` → `flow.show_options_menu()` |
| 3 | `ExitMargin/ExitButton` | "SALIR" | `on_exit_button_pressed` → `flow.exit_pressed()` → flush saves + quit |

No existe botón de Host/Join propio en `MainMenu.tscn`: `StartButton` lleva al panel `NetworkModeSelect`, una escena aparte instanciada en runtime por `MainMenuFlow.build_network_mode_select()`.

Otros nodos: `click`/`hover` (`AudioStreamPlayer`), `Background`, `ProfileContainer` (avatar+nombre Steam), `TitleCenterContainer/QuestTitle`, `OptionsMenu` (instancia de `scenes/OptionsMenu.tscn`, oculta por defecto), `AnimationPlayer` (intro `menu_intro`).

### Scripts de navegación

- **`MainMenu.gd`** (script del root `Control`): setup inicial (`_ready`), maneja input directo de audio/Steam, y delega toda la lógica de navegación a un objeto `MainMenuFlow` construido en `_ready()`. Los `_on_*_pressed` son wrappers finos que reproducen click y llaman a `flow`.
- **`MainMenuFlow.gd`** (`class_name MainMenuFlow`, `extends RefCounted`): coordinador real de la máquina de estados. `enum MenuState { MAIN, NETWORK_MODE_SELECT, SLOT_SELECT, OPTIONS }`. Cada método (`show_main_menu`, `show_options_menu`, `start_pressed`, `exit_pressed`) anima el `CenterContainer` (fade+scale vía `_animate_main_menu()`, tween ad-hoc con `TRANS_CUBIC`) y muestra/oculta el sub-panel correspondiente (`OptionsMenu`, `NetworkModeSelect`, `SaveSlotSelector`). Todos los flujos excepto el que tenía Créditos abren paneles superpuestos (overlay) dentro de la misma escena — Créditos era el único que hacía `change_scene_to_file` (reemplazo total de escena).

### Confirmación de eliminación de Créditos

Removido por completo:
- `scenes/MainMenu.tscn`: nodo `CreditsButton` eliminado; sus 2 tracks de animación (`RESET` y `menu_intro`, ambos sobre `CreditsButton:modulate`) eliminados y tracks reindexados; conexión de señal `pressed → _on_credits_button_pressed` eliminada.
- `scripts/ui/menus/MainMenu.gd`: `@onready var credit_button`, su entrada en el array de botones (hover/focus tween wiring), y el método `_on_credits_button_pressed()` eliminados.
- `scripts/ui/menus/MainMenuFlow.gd`: constante `CREDITS_SCENE` y método `credits_pressed()` eliminados.
- Archivos borrados: `scenes/CreditMenu.tscn`, `scripts/ui/menus/CreditScene.gd`, `scripts/ui/menus/CreditScene.gd.uid`.
- Grep de `Credit` (case-insensitive) en todo el proyecto confirma cero referencias restantes salvo `scripts/ui/overlays/VictoryOverlay.gd` y `scenes/VictoryOverlay.tscn` — feature independiente ("créditos" tipo roll-the-credits tras ganar la partida), sin relación con `CreditMenu.tscn`/el botón del menú principal. No se tocó.

---

## 2. Auditoría del Menú de Opciones (`OptionsMenu.tscn`)

`OptionsMenu` es un componente reutilizable (`scripts/ui/menus/OptionsMenu.gd`, `class_name OptionsMenu extends Control`) instanciado tanto en `MainMenu.tscn` como en `PauseMenu.tscn` — no es una escena propia con flujo dedicado.

### Tabs (TabContainer `OptionsTabs`)

**Video** (tab 0):
- `WindowModeOption` (OptionButton) — Fullscreen / Windowed / Borderless (`SettingsManager.WindowMode`).
- `ResolutionOption` (OptionButton) — 5 presets (1280x720 … 3840x2160) + entrada "Nativa" sintética si el monitor no matchea ninguno.
- `VSyncCheck` (CheckButton).
- `FpsLimitOption` (OptionButton) — 30/60/120/144/240/Sin límite.
- `ShowFpsCheck` (CheckButton) — controla `SettingsManager.show_fps_overlay` → `FPSOverlay`.
- `LanguageOption` (OptionButton) — Español/Inglés, aplica `TranslationServer.set_locale` en vivo.

**Audio** (tab 1) — sliders `HSlider` (0–2, linear→dB):
- Master, Music, SFX, UI → cada uno mapea a un bus real de `AudioServer` (`Master`, `Music`, `SFX`, `UI` — confirmado en `default_bus_layout.tres`, solo existen esos 4 buses).
- Click, Hover → **no** son buses; controlan directamente `volume_db` de dos `AudioStreamPlayer` (`click_player`/`hover_player`) referenciados por NodePath export.

**Gameplay** (tab 2):
- `ScreenShakeSlider` (HSlider 0–1) → `SettingsManager.screen_shake_intensity`, consumido como multiplicador en `room_camera_controller.gd` (`_on_screen_shake`).

### Botones de acción y diálogo de cambios sin guardar

- `SaveButton` / `BackButton` al pie de la card.
- `UnsavedChangesDialog` (`ConfirmationDialog`) fuera del `OptionsCard`.
- Tracking de estado sucio: `has_unsaved_changes` + flag `suppress_change_tracking` (evita marcar "sucio" durante sync programático).
- `Back` con cambios pendientes → popup del diálogo; al confirmar descarte, se recarga `SettingsManager.load_settings()` + `apply_video_settings()` y se resincroniza la UI (revierte también efectos ya aplicados en vivo al SO/audio).
- `Save` → vuelca cada control a `SettingsManager`, llama `save_settings()` (persiste a disco) + `apply_video_settings()`, limpia el flag, y da feedback visual (flash amarillo 0.3s en el botón).
- **Detalle importante**: los controles de Video (window mode, resolución, vsync, fps limit) y los sliders de audio se aplican en vivo al SO/bus apenas cambian, *antes* de presionar Save — "cambios sin guardar" significa solo "no persistido a `settings.cfg`", no "sin efecto". Por eso el descarte en `Back` necesita recargar y reaplicar explícitamente.

### Bug encontrado

`ClickVolumeLabel` y `HoverVolumeLabel` tienen texto en español hardcodeado directo en el `.tscn` ("Volumen clic", "Volumen al pasar"), a diferencia de todas las demás labels de la pestaña Audio que usan claves i18n (`KEY_*`) resueltas vía `tr()`. `_update_ui_text_translations()` en `OptionsMenu.gd` no las cubre — al cambiar el idioma a inglés en vivo, estas dos labels quedan en español mientras el resto se traduce.

---

## 3. Flujo de Acceso y Persistencia

**Acceso a Opciones**:
- Desde Menú Principal: `OptionsButton.pressed → MainMenu._on_options_button_pressed() → MainMenuFlow.show_options_menu()` (anima salida del menú principal, luego `options_menu.open()`).
- Desde Menú de Pausa: `PauseMenu.gd` instancia `OptionsMenu.tscn` como hijo (`%OptionsMenu`); botón de opciones en pausa llama `_set_panel(1)`, que oculta el panel de pausa y llama `options_menu.open()`. Cierre vuelve a `_set_panel(0)`.
- En ambos casos, cerrar Options dispara la señal `closed`, que cada contenedor (MainMenu / PauseMenu) escucha para restaurar su propio panel.

**Persistencia — `SettingsManager.gd`** (autoload, singleton vía `ManagerLocator.get_settings_manager()`):
- Archivo: `user://settings.cfg` (`ConfigFile`), 5 secciones: `[options]` (click/hover volume), `[audio]` (master/music/sfx/ui), `[video]` (window_mode/resolution_index/vsync/fps_limit_index), `[gameplay]` (screen_shake_intensity), `[display]` (show_fps_overlay/locale).
- `_ready()` del autoload: `load_settings()` + `apply_video_settings()` — es decir, video/ventana se aplican automáticamente al boot del juego, antes de abrir cualquier menú.
- Señales: `settings_changed(section, key, value)` y `volume_changed(type, linear, db)` — usadas por `MainMenu.gd`/`OptionsMenu.gd` para reaccionar a cambios sin poll.
- Setters de volumen y video aplican en vivo (bus/DisplayServer/Engine.max_fps) inmediatamente al cambiar; `save_settings()` solo escribe a disco — ver distinción en sección 2.

---

## 4. Observaciones de UI/UX y Navegación

- **Theming inconsistente**: `OptionsMenu` usa `StyleBoxFlat` embebidos directamente en el `.tscn` (editor-baked) para su panel y botones, y nunca referencia `ThemeManager`. En cambio `PauseMenu.gd._apply_theme()` sí usa `ThemeManager.build_panel_style()` con paleta `QuestPalette` para skinnear en runtime. Dos enfoques distintos conviviendo en el mismo sistema de menús — candidato a unificar bajo `ThemeManager`.
- **Tweens duplicados**: `OptionsMenu.gd` (open/close con scale 0.92→1.0 + fade), `MainMenu.gd` (`_animate_button_scale`) y `MainMenuFlow.gd` (`_animate_main_menu`) implementan cada uno su propio tween ad-hoc, en vez de usar el helper compartido `MenuTransitionFX.gd` (que sí usan `BaseMenu`/`BaseSubPanel`, de los cuales `PauseMenu` hereda). Es lógica de transición triplicada con comportamiento visual similar pero código independiente — refactor candidato para consolidar bajo `MenuTransitionFX`.
- **Navegación por teclado/gamepad**: no hay `focus_neighbor_*` configurado en ninguna escena de menú; se depende enteramente de la resolución automática de foco de Godot dentro de los `VBoxContainer`/`TabContainer`. `MainMenu.gd` hace `grab_focus()` inicial en `StartButton` y anima hover/focus con el mismo tween, dando feedback visual básico, pero sin wiring explícito de navegación direccional — funciona pero no está garantizado en layouts más complejos (ej. cambio de tab en Options con gamepad).
- **Feedback de audio en Options**: clicks/hovers de todos los controles (botones y sliders) pasan por `_on_any_button_pressed`/`_on_any_button_mouse_entered`; en sliders el sonido de click se dispara al soltar el drag, no durante el arrastre — buen detalle de pulido ya presente.
- **Nota histórica** (ya no aplica, escena borrada): `CreditMenu.tscn` tenía una conexión de señal huérfana (`BackButton.pressed → _on_back_button_pressed`, método inexistente; el script conectaba manualmente a `_on_back_pressed` en `_ready()`), que habría lanzado un error de Godot al presionar el botón. Mencionado solo como contexto de por qué la limpieza también elimina deuda técnica, no requiere acción ya que el archivo fue eliminado.
