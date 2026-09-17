# Sistema de Selección de Personajes

Implementación de selección de héroe (4 arquetipos) para el flujo single-player y para la sala de espera multijugador (Steam lobby), con limpieza del código legacy de stats hardcodeadas.

## Contexto previo

Antes de este cambio el juego tenía un único perfil de jugador fijo:

- `PlayerStats.gd` hardcodeaba `base_str/base_mag/base_dex = 1`.
- `SaveManager.gd` duplicaba esos mismos literales en dos ramas (`save_game()` sin autoload, y `load_game()` en partida nueva).
- `scenes/Main2d.tscn` tiene un único nodo `Player` estático (hijo de `MapManager`), sin instanciación dinámica ni identidad de héroe.

## Alcance confirmado

La selección multijugador es **solo de lobby**: se sincroniza el `character_id` elegido por cada peer vía Steam lobby member data en `WaitingRoom`, con bloqueo de duplicados. **No** se implementó spawn por peer en `Main2d`/`MapManager` — esa escena sigue teniendo un único `Player` node estático, igual que en single-player. El host aplica su propio héroe elegido a ese nodo único. El spawn simultáneo real de múltiples jugadores queda fuera de alcance (no existía antes de este cambio: `Main2d.gd` no tenía ninguna lógica multijugador).

## Arquitectura nueva

### Capa de datos

- **`scripts/core/stats/CharacterData.gd`** (`Resource`): `character_id`, `display_name`, `description`, `icon` (nullable), `base_hp/base_str/base_mag/base_dex`.
- **`scripts/core/stats/CharacterDatabase.gd`** (`RefCounted` estático, mismo patrón que `StatBalance.gd`): lista fija de 4 rutas `.tres`, `get_all()` (cacheado), `get_by_id()` (con fallback + `push_warning` si el id no existe), `get_default()`/`get_default_id()`.
- **`resources/characters/{warrior,mage,rogue,tank}.tres`**: los 4 arquetipos.

| Héroe | HP | STR | MAG | DEX |
|---|---|---|---|---|
| Guerrero (`warrior`) | 22 | 3 | 1 | 1 |
| Mago (`mage`) | 20 | 1 | 3 | 1 |
| Pícaro (`rogue`) | 20 | 1 | 1 | 3 |
| Tanque (`tank`) | 32 | 1 | 1 | 1 |

`warrior` es el id por defecto (índice 0). Todos los `base_hp` se mantienen dentro del clamp existente `StatBalance.clamp_player_hp()` → `[PLAYER_BASE_HP=20, PLAYER_MAX_HP=40]`.

### Persistencia — `scripts/managers/SaveManager.gd`

- Nuevo campo `selected_character_id: String`.
- `get_selected_character_id()` / `set_selected_character_id(id)` — mismo patrón que `get_run_cycle`/`set_run_cycle`.
- `apply_character_selection(character_id)`: busca el `CharacterData`, actualiza `selected_character_id`, empuja `base_hp/base_str/base_mag/base_dex` al autoload `PlayerStats`, llama `refresh_stats()` y guarda (`save_game()`). Es el único punto de entrada que usan tanto la UI single-player como el picker de `WaitingRoom`.
- `save_game()`/`load_game()`: persisten/leen `selected_character_id`. Los saves existentes no se rompen — los `base_*` numéricos ya guardados se siguen leyendo tal cual para compatibilidad hacia atrás.

### `scripts/core/stats/PlayerStats.gd`

Los valores iniciales hardcodeados (`base_hp = StatBalance.PLAYER_BASE_HP`, `base_str/mag/dex = 1`) pasan a inicializarse desde `CharacterDatabase.get_default()`. Solo afecta al valor de arranque del autoload (caso de correr `Main2d.tscn` directo en el editor); `refresh_stats()`/`_apply_base_stats()` no cambian.

### UI single-player

- **`scenes/CharacterCardOption.tscn` + `scripts/ui/character_select/CharacterCardOption.gd`**: tile de héroe seleccionable, copiado del patrón de `RewardCardOption` (estados normal/hover/seleccionado vía `ThemeManager.build_reward_card_style()` + `QuestPalette`). Incluye `set_taken()` para reutilización en el lobby.
- **`scenes/CharacterSelection.tscn` + `scripts/ui/menus/CharacterSelection.gd`**: pantalla de selección (grid de 4 cards + Confirmar/Volver), copiada del patrón open/close-tween de `NetworkModeSelect`.
- **`scripts/ui/menus/MainMenuFlow.gd`**: nuevo estado `CHARACTER_SELECT`. `_on_slot_selected()` detecta si el slot es nuevo (`has_save()` antes de `load_game()`); si es nuevo, abre `CharacterSelection` antes de continuar; si ya existe save, sigue el flujo de siempre. Se agregaron `_proceed_after_character_ready()`, `_on_character_confirmed()` y `_on_character_back_pressed()`. El botón Volver resetea `is_transitioning = false` (antes esa bandera nunca se reseteaba porque todos los caminos terminaban en cambio de escena; `CHARACTER_SELECT` es el primer estado navegable hacia atrás).
- **`scripts/ui/menus/MainMenu.gd`**: registra `flow.build_character_selection()`.

### Multijugador — `scenes/WaitingRoom.tscn` / `scripts/ui/menus/WaitingRoom.gd`

- Nuevo panel `CharacterPanel` con grid de `CharacterCardOption` por cada héroe.
- `_on_character_card_selected(id)` llama `SaveManager.apply_character_selection(id)` (no solo guarda el id — también empuja las stats reales al autoload) y publica el pick vía `Steam.setLobbyMemberData(lobby_id, "character_id", id)`.
- `_refresh_character_roster()` lee `Steam.getLobbyMemberData()` de cada peer conectado y marca como "tomado" (`set_taken()`) los héroes ya elegidos por otros. Se enganchó al timer de refresco de 1s que ya existía (`_refresh_timer`) — no se agregó un segundo timer, porque no hay señal de cambio de lobby-data disponible en este setup de GodotSteam.
- `_on_start_pressed()` ahora llama `ManagerLocator.flush_saves()` antes de cambiar de escena (antes no persistía nada al salir de la sala).

**Limitación conocida (documentada, no resuelta):** el bloqueo de duplicados es best-effort y depende del polling de 1s — dos jugadores pueden elegir el mismo héroe en la ventana de carrera antes del próximo refresh. Una prevención dura necesitaría arbitraje RPC autoritativo del host, fuera de alcance de este cambio.

### `MapManager` / `PlayerMovement`

Sin cambios. La cadena existente `PlayerMovement._ready()` → `ManagerLocator.get_player_stats()` → `register()` → `refresh_stats()` → `_apply_base_stats()` ya aplica lo que tenga el autoload `PlayerStats`, y ese autoload se puebla antes del cambio de escena en ambos flujos (single-player y multijugador). El swap de sprite/apariencia visual por héroe queda explícitamente fuera de alcance: no existe arte por héroe en el proyecto, los 4 comparten el mismo `AnimatedSprite2D`.

## Limpieza de legacy

| Archivo | Antes | Ahora |
|---|---|---|
| `PlayerStats.gd` (inicializadores) | `StatBalance.PLAYER_BASE_HP`, `1`, `1`, `1` | `CharacterDatabase.get_default().base_*` |
| `SaveManager.save_game()` (rama sin autoload) | mismos literales | `CharacterDatabase.get_by_id(get_selected_character_id()).base_*` |
| `SaveManager.load_game()` (rama de save nuevo) | mismos literales | `CharacterDatabase.get_default()` + set de `selected_character_id` |

## Bug detectado y corregido durante la revisión

El picker de `WaitingRoom` originalmente solo llamaba `SaveManager.set_selected_character_id(id)` (guardaba el string, nada más). Al presionar Iniciar, `flush_saves()` habría persistido las stats **viejas** del autoload `PlayerStats`, desincronizadas del héroe recién elegido. Se corrigió para que llame `apply_character_selection(id)`, el mismo camino que usa single-player, que además de guardar el id empuja `base_hp/str/mag/dex` reales al autoload.

## Archivos tocados

**Nuevos:**
- `scripts/core/stats/CharacterData.gd`
- `scripts/core/stats/CharacterDatabase.gd`
- `resources/characters/warrior.tres`, `mage.tres`, `rogue.tres`, `tank.tres`
- `scripts/ui/character_select/CharacterCardOption.gd` + `scenes/CharacterCardOption.tscn`
- `scripts/ui/menus/CharacterSelection.gd` + `scenes/CharacterSelection.tscn`

**Modificados:**
- `scripts/managers/SaveManager.gd`
- `scripts/core/stats/PlayerStats.gd`
- `scripts/ui/menus/MainMenuFlow.gd`
- `scripts/ui/menus/MainMenu.gd`
- `scripts/ui/menus/WaitingRoom.gd` + `scenes/WaitingRoom.tscn`

## Verificación pendiente

El repo no tiene test suite ni CI (ver `CLAUDE.md`). Falta verificar manualmente en el editor:

**Single-player:**
1. Offline → slot vacío → debe aparecer `CharacterSelection` con las 4 cards y stats correctas.
2. Volver desde `CharacterSelection` a selección de slot y volver a entrar (valida el fix de `is_transitioning`).
3. Confirmar un héroe → `Main2d` debe reflejar sus stats.
4. Reabrir el mismo slot (ya guardado) → `CharacterSelection` debe saltearse.
5. Revisar `user://slot_<N>.cfg` → debe tener `selected_character_id` bajo `[save_data]`.

**Multijugador (2 clientes Steam):**
1. Host elige slot + héroe → en `WaitingRoom` debe verse preseleccionado.
2. Cliente se une → debe ver ese héroe bloqueado/atenuado dentro de ~1s.
3. Cliente elige otro héroe → el host debe ver el cambio reflejado en ~1s.
4. Click en héroe bloqueado no debe hacer nada.
5. Host presiona Iniciar → su partida debe reflejar el héroe elegido (el cliente se queda en `WaitingRoom`, gap preexistente y fuera de alcance).
6. Revisar consola en ambos clientes por errores de `setLobbyMemberData`/`getLobbyMemberData`.

Plan completo con detalle línea por línea: `C:\Users\FEDE\.claude\plans\hola-claude-necesito-implementar-lucky-teacup.md`.
