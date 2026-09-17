# Auditoría: Menú de Opciones / Configuración — QUEST

Fecha: 2026-09-16
Alcance: Godot 4.6, GDScript. Inspección de escenas, scripts y persistencia relacionados con el menú de opciones.

## Resumen ejecutivo

El sistema de opciones actual es **mínimo y exclusivamente de audio**: un único componente reutilizable (`OptionsMenu.tscn`/`.gd`) instanciado tanto en el Menú Principal como en el Menú de Pausa, con exactamente **2 sliders** (volumen de click y volumen de hover de UI) persistidos vía `SettingsManager` a `user://settings.cfg`.

No existe: configuración de video/pantalla, mezcla de audio por buses (Master/Música/SFX), remapeo de inputs, sensibilidad de mouse, soporte de gamepad, idioma/localización, ni opciones de accesibilidad. Todo lo que sigue detalla exactamente qué existe y qué falta, con referencias a archivo:línea.

---

## 1. Estructura General y Archivos Involucrados

| Archivo | Tipo | Rol |
|---|---|---|
| `scenes/OptionsMenu.tscn` | Escena | UI de opciones, única en el proyecto (no hay duplicados). |
| `scripts/ui/menus/OptionsMenu.gd` | Script (`class_name OptionsMenu`, extends `Control`) | Controlador: sincroniza sliders con `SettingsManager`, guarda, confirma cambios sin guardar, SFX de hover/click, animación de apertura/cierre. |
| `scripts/managers/SettingsManager.gd` | Script (autoload) | Persistencia a `user://settings.cfg` vía `ConfigFile`. |
| `scenes/MainMenu.tscn` + `scripts/ui/menus/MainMenu.gd` | Escena/script | Instancia `OptionsMenu` como hijo, botón `OptionsButton`. |
| `scripts/ui/menus/MainMenuFlow.gd` | Script | Coordinador de flujo: `show_options_menu()` (línea 120). |
| `scenes/PauseMenu.tscn` + `scripts/ui/menus/PauseMenu.gd` | Escena/script | Instancia `OptionsMenu` como `%OptionsMenu`, panel conmutado por índice. |
| `scripts/ui/menus/BaseMenu.gd` | Script | Base de `PauseMenu` (fade genérico + pausa vía `ManagerLocator.get_game_state_manager()`). `OptionsMenu` NO extiende esto — implementa su propio tween. |

**Acceso al menú: ambos casos, Menú Principal y Menú de Pausa.**

- **Desde Main Menu**: `MainMenu.gd:169-173` (`_on_options_button_pressed`) → `MainMenuFlow.gd:120-131` (`show_options_menu()`) → anima menú principal afuera y llama `options_menu.open()`. Al cerrar, `OptionsMenu` emite `closed` → `MainMenu.gd:158-161` vuelve a mostrar el menú principal.
- **Desde Pause Menu**: `PauseMenu.gd:118-120` conecta `options_button` a `_set_panel(1)`. `PauseMenu.gd:84-106` (`_set_panel`) abre `options_menu.open()` cuando `i==1`, cierra `StorePanel` si estaba abierto. Al cerrar, `PauseMenu.gd:109-110` vuelve a `_set_panel(0)`.

---

## 2. Opciones de Video / Pantalla Actuales

**No implementado.** Búsqueda de `DisplayServer.*`, `RenderingServer.*`, `window_mode`, `vsync`, `fps_limit` en todo `scripts/` y `scenes/`: **cero coincidencias**.

Lo único relacionado a pantalla es estático, en `project.godot` (sección display):
```
window/size/viewport_width=1920
window/size/viewport_height=1080
window/size/mode=3        ; fullscreen exclusivo
window/stretch/mode="canvas_items"
```
Esto es un default de proyecto, no configurable en runtime. `MainMenu.gd:50-53` (`_setup_content_scaling`) ajusta `content_scale_mode`/`content_scale_aspect` del `Window` raíz al iniciar — es inicialización fija, no un setting de usuario.

No hay: resolución seleccionable, modo ventana/fullscreen/borderless, V-Sync toggle, límite de FPS, ni calidad gráfica.

---

## 3. Opciones de Audio Actuales

**Buses de audio (`AudioServer`): no se usa.** No hay llamadas a `AudioServer.set_bus_volume_db` ni similares en todo el proyecto. No existe `default_bus_layout.tres` ni layout de buses custom. El volumen se aplica directo sobre `AudioStreamPlayer.volume_db`, no sobre buses Master/Música/SFX.

**Controles en la UI** (`scenes/OptionsMenu.tscn`):

| Control | Línea | Rango | Controla |
|---|---|---|---|
| `ClickVolumeSlider` (`HSlider`) | 189-195 | 0–2, step 0.01, default 1.0 | `SettingsManager.click_volume` (SFX de click de botones) |
| `HoverVolumeSlider` (`HSlider`) | 222-228 | 0–2, step 0.01, default 1.0 | `SettingsManager.hover_volume` (SFX de hover de botones) |
| `ClickVolumeValueLabel` / `HoverVolumeValueLabel` | 197-206, 230-239 | — | Label de solo lectura, `"%d%%"` |

Lógica en `OptionsMenu.gd`:
- `_on_click_volume_slider_value_changed` (254-258) / `_on_hover_volume_slider_value_changed` (261-265): preview en vivo, aplica `volume_db` directo al `AudioStreamPlayer` referenciado por `@export var click_player_path` / `hover_player_path` (líneas 10-14).
- El valor solo se persiste al presionar **Save** (`_on_save_button_pressed`, 243-251): recién ahí escribe en `SettingsManager.click_volume`/`hover_volume` y llama `save_settings()`.
- Cambios no guardados se trackean (`has_unsaved_changes`, línea 25) y al presionar Back con cambios pendientes se dispara `UnsavedChangesDialog` (`ConfirmationDialog`, líneas 274-278, texto "¿Deseas descartar los cambios?").

**No existe:** slider de Master, Música, Voces; controles de mute; separación por categoría de sonido (solo SFX de UI).

---

## 4. Opciones de Controles e Inputs Actuales

**No implementado.** Sin remapeo de teclas/botones, sin ajuste de sensibilidad de mouse, sin inversión de ejes, sin configuración de gamepad expuesta al usuario.

Único uso de `InputMap.*` en el proyecto: `scripts/core/movement/PlayerActionController.gd:213-229`, que registra acciones `hotbar_1`/`hotbar_2`/`hotbar_3` en runtime — esto es setup de gameplay (hotbar), no relacionado a `OptionsMenu`/`SettingsManager`, y no es remapeable por el jugador.

---

## 5. Opciones de Gameplay, Accesibilidad e Idioma

**No implementado — nada de esto existe:**
- **Idioma/localización**: cero uso de `TranslationServer` o `locale` en el proyecto.
- **Tamaño de texto / subtítulos**: no existen.
- **Screen Shake**: existe como efecto de combate/cámara, no como setting. `scripts/ui/visual/VisualFeedback.gd:4` define `signal screen_shake(intensity, duration)`, emitido vía `request_screen_shake()` (líneas 140-141) y consumido por `scripts/world/rooms/room_camera_controller.gd:57-58,233`. Intensidad/duración están hardcodeadas en `CombatFeedbackPresenter.gd:20` y `ThemeManager.gd:53-54` — no hay toggle ni slider expuesto al jugador para desactivarlo o ajustarlo.

---

## 6. Sistema de Persistencia y Guardado de Ajustes

`scripts/managers/SettingsManager.gd` (autoload, registrado en `project.godot:27`):

- Ruta: `const SETTINGS_PATH := "user://settings.cfg"` (línea 12), vía `ConfigFile`.
- Única sección: `const SECTION_OPTIONS := "options"` (línea 13).
- Contenido real del archivo (solo estas 2 claves):
```ini
[options]
click_volume=1.0
hover_volume=1.0
```
- **Propiedades** (líneas 15-25): `click_volume`/`hover_volume`, ambas `float`, setter clampea a `[0.001, 2.0]` y emite señales en cada cambio.
- **Señales**: `settings_changed(section, key, value)` (línea 9), `volume_changed(type, linear_value, db_value)` (línea 10) — emitidas desde los setters, antes incluso de guardar a disco.
- **Carga automática**: `_ready()` (línea 28-29) llama `load_settings()` (línea 50-60); si falla la carga (`err != OK`), usa defaults `1.0`/`1.0` (no crashea ni deja estado inválido).
- **Guardado**: `save_settings() -> Error` (línea 63-70), escribe ambas claves y `cfg.save()`; en caso de error hace `push_warning`.
- **Helpers**: `get_click_volume_db()`/`get_hover_volume_db()` (conversión lineal→dB), `apply_volume_to_player(player, type)` (aplica `volume_db` directo a un `AudioStreamPlayer`).

### ⚠️ Discrepancia de documentación detectada

El doc-comment de `SettingsManager.gd:4-7` dice: *"Persist configuration options (audio volumes, **display settings**) to `user://settings.cfg`"*. `CLAUDE.md:27` repite la misma afirmación: *"persists audio/**display** settings"*. Ninguna de las dos es cierta hoy — no hay código de configuración de pantalla en este archivo ni en el proyecto (ver sección 2). Recomendado: corregir ambos comentarios o implementar lo que documentan.

---

## 7. Diagnóstico y Resumen de Controles UI Existentes

Inventario completo de `scenes/OptionsMenu.tscn` (única escena de opciones del proyecto):

| Nodo | Tipo | Línea | Función |
|---|---|---|---|
| `ClickVolumeSlider` | `HSlider` | 189-195 | Volumen SFX click |
| `ClickVolumeValueLabel` | `Label` | 197-206 | Readout % click |
| `HoverVolumeSlider` | `HSlider` | 222-228 | Volumen SFX hover |
| `HoverVolumeValueLabel` | `Label` | 230-239 | Readout % hover |
| `SaveButton` | `Button` | 241-255 | Commit + `save_settings()` |
| `BackButton` | `Button` | 257-272 | Cerrar (con guard de cambios sin guardar) |
| `UnsavedChangesDialog` | `ConfirmationDialog` | 274-278 | Confirmación de descarte |

**Cero** `OptionButton`, `CheckBox`, `CheckButton`, `SpinBox` en toda la escena o en cualquier escena relacionada a settings — confirmado por búsqueda global en el repo.

Total: 2 sliders + 2 botones + 1 diálogo de confirmación. Eso es el 100% de la superficie de UI de opciones del proyecto.

---

## Conclusión

Sistema de opciones cubre solo volumen de SFX de UI (click/hover). Todo lo demás pedido en el checklist estándar de un menú de opciones (video, audio por buses, controles/inputs, idioma, accesibilidad) está ausente y sería trabajo nuevo, no extensión de algo parcialmente hecho. Si se planea expandir, el patrón ya existente en `SettingsManager` (propiedad con setter clampeado + señal + ConfigFile) es reutilizable para nuevas categorías de settings.
