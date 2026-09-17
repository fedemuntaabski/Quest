# Estado actual del Menú de Opciones — QUEST

Fecha: 2026-09-16
Alcance: `scenes/OptionsMenu.tscn`, `scripts/ui/menus/OptionsMenu.gd`, `scripts/managers/SettingsManager.gd`, `scripts/ui/overlays/FPSOverlay.gd`, `project.godot`.

> Nota: `SETTINGS_MENU_REVIEW.md` (raíz, sin trackear) documenta el estado **anterior** a este trabajo (solo 2 sliders de volumen UI). Ese archivo quedó desactualizado — este documento reemplaza su vigencia como estado actual.

---

## 1. Nodos y elementos de UI en `OptionsMenu.tscn`

`OptionsTabs` (`TabContainer`) con 3 pestañas:

### Tab `Video`
| Nodo | Tipo | Controla |
|---|---|---|
| `WindowModeOption` | `OptionButton` | Modo de ventana (Pantalla Completa / Ventana / Sin Bordes) |
| `ResolutionOption` | `OptionButton` | Resolución (1280x720, 1600x900, 1920x1080, 2560x1440, 3840x2160) |
| `VSyncCheck` | `CheckButton` | V-Sync on/off |
| `FpsLimitOption` | `OptionButton` | Límite de FPS (30/60/120/144/240/Sin límite) |
| `ShowFpsCheck` **(nuevo)** | `CheckButton` | Muestra/oculta overlay de contador de FPS |
| `LanguageLabel` / `LanguageOption` **(nuevo)** | `Label` / `OptionButton` | Idioma (Español / Inglés) |

### Tab `Audio`
`MasterVolumeSlider`, `MusicVolumeSlider`, `SfxVolumeSlider`, `UiVolumeSlider`, `ClickVolumeSlider`, `HoverVolumeSlider` (todos `HSlider`, 0–2, step 0.01) + labels de porcentaje. Ya existían en el working tree antes de esta tarea.

### Tab `Gameplay`
`ScreenShakeSlider` (`HSlider`, 0–1, step 0.01) + label de porcentaje. Ya existía; el multiplicador ya estaba conectado a `RoomCameraController._on_screen_shake`.

Controles comunes: `SaveButton`, `BackButton`, `UnsavedChangesDialog` (`ConfirmationDialog`).

**Resolución de fila 720p no nativa detectada**: no se agregó una opción explícita "resolución nativa" — el listado usa los 5 presets fijos de `SettingsManager.RESOLUTIONS`. Ver pendientes (§4).

---

## 2. Métodos nuevos

### `SettingsManager.gd`
- `const SECTION_DISPLAY := "display"`
- `var show_fps_overlay: bool` — setter emite `settings_changed(SECTION_DISPLAY, "show_fps_overlay", ...)`.
- `var locale: String` — setter llama `TranslationServer.set_locale(locale)` y emite `settings_changed(SECTION_DISPLAY, "locale", ...)`.
- `load_settings()` / `save_settings()` extendidos para leer/escribir ambas claves en `[display]`.

### `OptionsMenu.gd`
- `@onready var show_fps_check: CheckButton`, `@onready var language_option: OptionButton`.
- `const LANGUAGE_LABELS := ["Español", "Inglés"]`, `const LANGUAGE_CODES := ["es", "en"]`.
- `_populate_option_buttons()`: agrega llenado de `language_option`.
- `_sync_from_settings_manager()`: lee `show_fps_overlay`/`locale` y los aplica a los controles.
- `_connect_menu_signals()`: conecta `language_option.item_selected` y `show_fps_check.toggled` a los handlers de video ya existentes (`_on_video_setting_changed` / `_on_video_setting_toggled`).
- `_on_save_button_pressed()`: escribe `settings_mgr.show_fps_overlay` y `settings_mgr.locale` antes de `save_settings()`.

### `FPSOverlay.gd` (nuevo autoload, `scripts/ui/overlays/FPSOverlay.gd`)
- `CanvasLayer` con un `Label` propio, `layer = 100`, `process_mode = PROCESS_MODE_ALWAYS`.
- Lee `SettingsManager.show_fps_overlay` en `_ready()` (autoload registrado después de `SettingsManager`, así que el valor ya está cargado de disco).
- Se suscribe a `SettingsManager.settings_changed` para reaccionar a cambios en vivo desde el menú.
- `_process()`: actualiza el label con `Engine.get_frames_per_second()` solo si `visible`.

### `project.godot`
- Nueva sección `[audio]` con `buses/default_bus_layout="res://default_bus_layout.tres"` — **fix de bug**: sin esta línea, los buses `Music`/`SFX`/`UI` no existían en runtime y los sliders correspondientes no tenían efecto real (`AudioServer.get_bus_index()` devolvía `-1`).
- Nuevo autoload `FPSOverlay`, registrado después de `SettingsManager`.

---

## 3. Persistencia en `user://settings.cfg`

4 secciones, tal como se pidió:

```ini
[options]
click_volume=1.0
hover_volume=1.0

[audio]
master_volume=1.0
music_volume=1.0
sfx_volume=1.0
ui_volume=1.0

[video]
window_mode=0
resolution_index=2
vsync_enabled=true
fps_limit_index=1

[gameplay]
screen_shake_intensity=1.0

[display]
show_fps_overlay=false
locale="es"
```

- Todo se carga en `SettingsManager._ready()` vía `load_settings()`, y se aplica automáticamente:
  - `apply_video_settings()` (ya existente) aplica `window_mode`/`resolution_index`/`vsync_enabled`/`fps_limit_index` a `DisplayServer`/`Engine`.
  - El setter de `locale` aplica `TranslationServer.set_locale()` inmediatamente al cargarse.
  - `FPSOverlay._ready()` lee `show_fps_overlay` ya cargado para su visibilidad inicial.
- Guardado solo ocurre al presionar **Guardar** en `OptionsMenu` (mismo patrón que el resto de los settings, con diálogo de cambios sin guardar).

---

## 4. Pendientes / a tener en cuenta al probar

1. **Sin archivos de traducción reales**: `TranslationServer.set_locale()` cambia el locale activo, pero el proyecto no tiene ningún `.po`/`.csv`/`Translation` cargado (`config/locale/translations` vacío en `project.godot`). Todos los textos de la UI siguen hardcodeados en español — el selector de idioma cambia el locale del motor pero no traduce nada visualmente todavía. Falta: crear los recursos de traducción y reemplazar los `text = "..."` literales por claves de traducción (`tr("...")`) si se quiere localización real.
2. **Resolución nativa**: no se agregó un ítem "Nativa" separado en `ResolutionOption` — la lista sigue siendo los 5 presets fijos de `SettingsManager.RESOLUTIONS`. Si se quiere una opción real de "resolución nativa del monitor", habría que leer `DisplayServer.screen_get_size()` y agregarla como ítem adicional.
3. **`default_bus_layout.tres`**: ya existía sin trackear en el repo con los 4 buses (Master/Music/SFX/UI) correctamente definidos; solo faltaba registrarlo en `project.godot`. Verificar al abrir el editor que Godot no regenere/sobreescriba este archivo de forma inesperada.
4. **Verificación manual recomendada** (no hay test suite/CI en el proyecto):
   - Abrir en editor (`godot --path . --editor`) y correr el juego; abrir Opciones desde Menú Principal y desde Pausa.
   - Activar "Mostrar contador de FPS" y confirmar que aparece el overlay en la esquina superior derecha y se actualiza.
   - Mover sliders de Música/SFX/UI y confirmar cambio audible real (antes del fix del bus layout no tenía efecto).
   - Cambiar idioma, guardar, cerrar y reabrir el juego — confirmar que `TranslationServer.get_locale()` persiste (aunque los textos no cambien visualmente, ver punto 1).
   - Confirmar que `user://settings.cfg` (usualmente en `%APPDATA%/Godot/app_userdata/QUEST/settings.cfg` en Windows) contiene las 4 secciones tras guardar.
5. **Screen shake ya estaba wireado** en este branch (uncommitted) antes de esta tarea: `RoomCameraController._on_screen_shake()` ya multiplica por `SettingsManager.screen_shake_intensity`. No se tocó nada de esa parte, solo se confirmó que funciona.
