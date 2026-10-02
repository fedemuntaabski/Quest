# Propuesta de integración — mejoras de héroe, inventario, IA por objetivo y bestiario

Rama `session/propuesta-4` (desde `session/assets-5`). **Solo propuesta: no se tocó código, escenas ni `.tres`.** Todo lo marcado *(nuevo)* no existe todavía; lo demás se verificó leyendo el código de esta rama.

Fuentes: `docs/PERSONAJES.md`, `docs/ASSETS_AUDITORIA.md`, `docs/DIAGNOSTICO_ARQUITECTURA.md` y el código de `Enemy`, `EnemyType`, `EnemyManager`, `Nexo`, `Module`, `TurretModule`, `Player`, `CharacterStats`, `PlayerStats`, `HeroAbilities`, `AbilityData`, `ItemData`, `ItemCatalog`, `LootSpawner`, `CharacterPopup`, `PauseMenu` (+ `.tscn`), `SaveManager`, `Main`.

Índice: [0 Restricciones](#0-restricciones-de-la-arquitectura-actual) · [1 Mejoras de héroe](#1-mejoras-de-personajes) · [2 Inventario](#2-inventario-estilo-dungeon-of-the-endless) · [3 IA por objetivo](#3-ia-de-enemigos-con-objetivos-distintos) · [4 Bestiario](#4-enciclopedia-de-enemigos-bestiario-en-la-pausa) · [5 Plan](#5-plan-de-implementación) · [6 Decisiones abiertas](#6-decisiones-abiertas)

---

## 0. Restricciones de la arquitectura actual

Hallazgos del código que condicionan el diseño. Cada propuesta de abajo los respeta.

| # | Hecho (evidencia) | Consecuencia |
|---|---|---|
| R1 | **Los `Player` se recrean en cada piso**: `PlayerStats.clear_party()` + un `register()` por héroe nuevo (`PlayerStats.gd:139`, `Main2d._spawn_heroes`). Lo que sobrevive pisos (`run_levels`) vive en el autoload, clave `hero_id`. | Equipo y perks deben vivir en un autoload por `hero_id`; el nodo `Player` solo los **aplica** al registrarse. |
| R2 | `PlayerStats` ya hace 4 trabajos (héroes vivos, niveles, hallazgos, "héroe activo"; diagnóstico §2). | No sumarle inventario. Autoload chico nuevo `PartyInventory`. |
| R3 | El reset de run es **manual** en `Main._begin_new_run()` (`Main.gd:131-145`). | Todo estado de run nuevo se añade ahí (junto a `clear_found_items`). Si se hace antes el `RunState` del diagnóstico (R13), se suscribe a `run_started`. |
| R4 | `PlayerStats._apply_run_attack()` llama `CharacterStats.set_attack()`, que **sobrescribe** `attack_damage`/`attack_interval` (`PlayerStats.gd:251`, `CharacterStats.gd:81`). | El equipo debe entrar como **tercera capa** (base → nivel → equipo) dentro de `_refresh_hero` y `_apply_run_attack`; si no, subir de nivel borra el bonus. |
| R5 | `StatBalance.PLAYER_MAX_HP = 60` recorta `apply_hp_delta` (`StatBalance.gd:9,20`); el Tanque ya llega a 60 en nivel 6. | Armaduras de +20/+25/+30 vida quedarían **anuladas** sin avisar → decisión §6.1. |
| R6 | `ItemData.modifiers` solo admite `hp`, `attack_damage`, `attack_interval` (`ItemData.gd:15`). Los 18 ítems se **muestran** (`Pickup.item`, cofres Botín en `LootSpawner`, `CharacterPopup._rebuild_found_items`) pero **nada los aplica**. | El inventario extiende `ItemData`, no lo reemplaza. |
| R7 | `Enemy.gd` (444 líneas) mezcla elección de objetivo con movimiento y ataque: `_goal_zone`, `_goal_point`, `_is_raiding`, `_aggro_hero`, `_player_zone`, `_find_zone_with_modules`, `_try_attack_nexo`, `on_zone_entered`, `_provoked_until_msec`. Consumidores externos de esos privados: `tests/test_enemy_roles.gd` (`_aggro_hero`, `_goal_zone`, `_goal_point`, `_is_raiding`, `target_nexo`, `role`), `tests/test_raider_timing.gd`, `tools/BalanceSim.gd` (`type.role`), `EnemyPool.roll(role)`, `FloorManager.roll_role()`, `EnemyManager.raider_arrival_sec()`. | La IA por objetivo se migra **sin romper**: wrappers delegantes y `role` derivado del perfil. |
| R8 | `Module` tiene `take_damage`/`die`/`module_destroyed`/`is_active`/`powered`, pero **no** `hp_changed`, barra/flash ni `get_target_position()`. `TurretModule.DetectionZone` radio 180. `Nexo` ya tiene `take_damage`, `hp_changed`, `under_attack_changed`, `destroyed`, `get_target_position()`, `get_target_zone(rm)`. | Los módulos necesitan feedback de daño antes de ser objetivos "reales". |
| R9 | `PauseMenu` (`BaseMenu`, `CanvasLayer` 20, `PROCESS_MODE_ALWAYS`) usa `panels = [pause_panel, options_menu]` + `_set_panel(i)`. `PausePanel` mide 560×330 y `PauseVBox` tiene offsets fijos ±126 (título 72 + 2 botones de 70 + 2 separaciones de 20 = 252). | Un botón nuevo exige subir panel (≈420) y offsets (≈±171). `OptionsMenu` ya es el patrón de sub-panel (`open()`/`close()`/señal `closed`). |
| R10 | `SaveManager` = `ConfigFile` por slot `user://slot_N.cfg`, sección `save_data`; `save_game()` se dispara con `ManagerLocator.flush_saves()` al cambiar de escena. `ConfigFile` admite `Dictionary`. Hoy persiste solo `base_hp`, personaje, `run_cycle` (sin lectores), playtime y flags (diagnóstico §7). | El bestiario sería la **primera** persistencia que cruza runs. Sección propia `[bestiary]`. |
| R11 | En `--script` los nombres de autoload no existen; los tests usan `root.get_node("X")`. | Todo autoload nuevo se expone por `ManagerLocator.get_*()` tipado y su script no usa otros autoloads como identificador. |
| R12 | `ManagerLocator.get_hud()`, `get_nexo()`, `get_heroes()`, `get_room_manager()`, `get_enemy_manager()` ya existen y son tipados (`ManagerLocator.gd`). | Las piezas nuevas se enchufan por ahí, no por `call_group`. |

---

## 1. Mejoras de personajes

### 1.1 Qué hay y qué es viable
Hoy el único progreso es el **nivel genérico** (`UpgradeConfig` + `run_upgrade_config.tres`): 5 niveles, +4 vida / +1 daño / −5 % intervalo, igual para los 4 héroes, pagado con Comida (`PlayerStats.level_up_hero`). Es plano: el Pícaro y el Tanque suben igual.

Stats y datos **ya existentes** que se pueden mejorar sin inventar sistemas:

| Origen | Campos |
|---|---|
| `CharacterStats` | `max_hp`, `attack_damage`, `attack_interval`, `attack_mult`, `damage_taken_mult` |
| `CharacterData` | `attack_range` (hoy fijo, no escala), `base_hp` |
| `AbilityData` (pasiva/activa) | `value`, `duration`, `cooldown`, `radius` |

**No existen** (y por tanto no entran en la primera versión): velocidad de movimiento por héroe, defensa/armadura, crítico, evasión, "provocar" (ver `PERSONAJES.md` §5, puntos 3-4).

### 1.2 Estructura de datos

**`HeroPerk`** *(nuevo)* — `scripts/core/stats/HeroPerk.gd`, `extends Resource`, un `.tres` por perk en `resources/perks/`.

```gdscript
class_name HeroPerk
extends Resource

@export var id: StringName
@export var display_name: String
@export_multiline var description: String
@export var icon: Texture2D
## Nivel de héroe desde el que se ofrece (3 y 5 en la propuesta).
@export var unlock_level: int = 3
## Perks con el mismo grupo son excluyentes (elegir 1 de 2).
@export var exclusive_group: StringName
## Claves cerradas (ver MOD_KEYS); valores = delta.
@export var mods: Dictionary = {}

const MOD_KEYS := ["hp", "attack_damage", "attack_interval", "attack_range",
	"active_cooldown", "active_value", "active_duration",
	"passive_value", "passive_radius"]
```

**`CharacterData`** gana (retrocompatible, defaults vacíos):
```gdscript
@export var perks: Array[HeroPerk] = []
## Curva propia (p. ej. el Pícaro escala intervalo, el Tanque vida). null = la global.
@export var upgrade_override: UpgradeConfig
```
`PlayerStats.run_upgrade_config` pasa a resolverse por héroe: `data.upgrade_override if data.upgrade_override else RUN_UPGRADE_CONFIG`.

### 1.3 Cómo se almacenan y se aplican
- **Estado**: `PlayerStats.run_perks: Dictionary` *(nuevo)* = `hero_id → Array[StringName]`, junto a `run_levels`. `reset_run_upgrades()` lo limpia (ya lo llama `Main._begin_new_run`). Señal nueva `perk_chosen(hero_id: String, perk_id: StringName)`. Si antes se hace el `RunState` del diagnóstico (R13), se mueve allí sin cambiar la API.
- **Elección**: al llegar a nivel 3 y 5 el popup ofrece **1 de 2** (gratis, sin costo extra; el costo ya está en Comida del nivel). API:
  - `PlayerStats.get_pending_perk_choices(hero_id) -> Array[HeroPerk]`
  - `PlayerStats.choose_perk(hero_id, perk_id) -> bool`
- **Stats**: `PlayerStats._refresh_hero(s)` suma los `mods` de stats (`hp`, `attack_damage`, `attack_interval`, `attack_range`) después de los niveles; `attack_range` se aplica con `Player._apply_attack_range()` (ya duplica el `CircleShape2D`), vía una señal `CharacterStats.attack_range_changed` *(nueva)*.
- **Habilidades**: `HeroAbilities` incorpora `get_cooldown()`, `get_value()`, `get_duration()`, `get_radius()` que devuelven `AbilityData.x + Σ perks.active_* / passive_*`. Sustituyen los usos directos de `active.cooldown`/`active.value`/`active.duration` (`HeroAbilities.gd:98,114-115,103-107,164,176`) y de `passive.value`/`passive.radius` (`:60-65,81-83`). Se recalculan en `_on_upgrade` (ya conectado a `run_upgrades_changed`) y con `perk_chosen`.
- **Feedback**: reutiliza el aura `level_up` de `HeroAbilities._on_upgrade` y `FloatingText`.

### 1.4 Perks propuestos (todos con mecánicas existentes)

| Héroe | Nivel 3 (elegir 1) | Nivel 5 (elegir 1) |
|---|---|---|
| **Guerrero** | *Piel Curtida*: `passive_value` +0.05 (−25 % daño) · *Voz de Mando*: `active_duration` +2 s | *Brazo Largo*: `attack_range` +20 · *Furia Sostenida*: `active_cooldown` −5 s |
| **Mago** | *Estudio Profundo*: `passive_value` +1 (3 Ciencia por sala) · *Foco Arcano*: `active_cooldown` −6 s | *Alcance Arcano*: `attack_range` +30 · *Sobrecarga Mayor*: `active_value` +1.5 (torres ×2.5) |
| **Pícaro** | *Bolsillos Hondos*: `passive_value` +1 (3 Polvo por sala) · *Filo Envenenado*: `active_value` +0.5 (×3.5) | *Manos Rápidas*: `attack_interval` −0.05 s · *Ágil*: `active_cooldown` −3 s |
| **Tanque** | *Bastión*: `passive_radius` +160 px · *Coraza*: `hp` +6 | *Interposición Larga*: `active_duration` +2 s · *Retorno de Escudo*: `active_cooldown` −5 s |

Opcionales que **requieren stat nuevo** (fase aparte, marcadas): `move_speed` para el "Explorador Rápido" del Pícaro (hoy `MoveAction.DEFAULT_SPEED_PX` es global) y "Provocar" del Guerrero (necesita `taunt_weight`, depende de la sección 3 §3.4 y cierra la inconsistencia #3 de `PERSONAJES.md`).

### 1.5 UI
`CharacterPopup` suma entre "Subir de nivel" y "Hallazgos" una sección **"Mejoras de clase"**: perks ya elegidos (icono + nombre + tooltip con `description`) y, si hay elección pendiente, dos tarjetas con botón "Elegir". Se refresca con `perk_chosen`/`run_upgrades_changed` (las conexiones ya existen en `CharacterPopup._ready`). `HeroPortrait` muestra un punto dorado cuando hay elección pendiente.

### 1.6 Tests
`tests/test_perks.gd`: aplicar un perk cambia el stat/habilidad esperado; el nivel 6 + perk no supera el tope; reset de run limpia `run_perks`; se mantienen tras `clear_party()` + nuevo `register()` (el caso R1).

---

## 2. Inventario estilo Dungeon of the Endless

### 2.1 Qué se reutiliza
`ItemData` (extender), `ItemCatalog.pick()` (sorteo por rareza), `LootSpawner` (cofres de salas Botín), `Pickup.item`, `CharacterPopup`, `HeroPortrait`, `ResourceManager`. Los **recursos compartidos del grupo ya existen**: Industria/Comida/Ciencia/Polvo son globales (`ResourceManager`); no se duplican en el inventario. El inventario cubre **objetos**.

### 2.2 Estructura de datos

**`ItemData`** (extensión retrocompatible; los 18 `.tres` actuales siguen siendo válidos con los defaults):
```gdscript
# scripts/core/items/ItemData.gd  (campos nuevos)
enum ConsumableEffect { NONE, HEAL_HP, ATTACK_BUFF_TIMED }

@export_multiline var description: String
## Vacío = lo puede llevar cualquier héroe; si no, ids de CharacterData.
@export var allowed_heroes: Array[String] = []
@export var stackable: bool = false
@export var max_stack: int = 1
@export_group("Consumible")
@export var consumable_effect: ConsumableEffect = ConsumableEffect.NONE
@export var effect_value: float = 0.0
@export var effect_duration: float = 0.0
@export var use_cooldown: float = 0.0
```
`MODIFIER_KEYS` se amplía a `["hp", "attack_damage", "attack_interval", "attack_range"]` (+ `"armor"` solo si se decide §6.4); `describe_modifiers()` suma sus líneas. Slots actuales (`Slot { WEAPON, ARMOR, CONSUMABLE, RELIC }`) se mantienen. Las 3 pociones definen los primeros consumibles (`potion_health` → `HEAL_HP`, `potion_fury` → `ATTACK_BUFF_TIMED`, `potion_clarity` → buff de intervalo); los 2 grimorios, las primeras reliquias.

**`ItemStack`** *(nuevo, `RefCounted`)*: `item: ItemData`, `count: int`.

**`PartyInventory`** *(nuevo, autoload)* — `scripts/autoload/PartyInventory.gd`, expuesto como `ManagerLocator.get_party_inventory() -> PartyInventory`. Estado de **run** (se resetea en `Main._begin_new_run()`, sobrevive pisos):
```gdscript
signal stash_changed
signal equipment_changed(hero_id: String, slot: ItemData.Slot, item: ItemData)
signal item_acquired(item: ItemData)
signal item_used(hero_id: String, item: ItemData)

const SLOT_CAPACITY := {ItemData.Slot.WEAPON: 1, ItemData.Slot.ARMOR: 1,
	ItemData.Slot.RELIC: 1, ItemData.Slot.CONSUMABLE: 2}
@export var stash_capacity: int = 20

var stash: Array[ItemStack] = []                 # compartido por el grupo
var loadouts: Dictionary = {}                    # hero_id -> {slot: Array[ItemData]}

func add_item(item: ItemData) -> bool            # false = stash lleno
func equip(hero_id: String, item: ItemData, index: int = 0) -> bool
func unequip(hero_id: String, slot: ItemData.Slot, index: int = 0) -> bool
func use_consumable(hero_id: String, index: int) -> bool
func can_equip(hero_id: String, item: ItemData) -> String   # "" = ok, si no la razón (como BuildingMenu.get_block_reason)
func get_equipment_bonus(hero_id: String) -> Dictionary     # suma de modifiers
func reset() -> void
```
`PlayerStats.found_items` / `add_found_item` / `found_items_changed` pasan a ser un **alias de lectura** de `PartyInventory.stash` (para no romper `CharacterPopup` y `tests/test_items.gd` en la primera fase) y se retiran después. `LootSpawner` llama a `PartyInventory.add_item(chest.item)`.

**`InventoryComponent`** *(nuevo, Node hijo de `Player`)* — `scripts/core/items/InventoryComponent.gd`, mismo patrón que `HeroAbilities` (se crea en `Player._ready()` tras `abilities`):
- En `_ready` (después de `PlayerStats.register`) pide `PartyInventory.get_equipment_bonus(hero_id)` y lo aplica → así el equipo **sobrevive el piso** (R1).
- Escucha `PartyInventory.equipment_changed` (filtra por su `hero_id`) y llama `PlayerStats.set_equipment_bonus(hero_id, bonus)`.
- Maneja consumibles: `use(index)` aplica `HEAL_HP` (`stats.heal`) o un buff temporal con el mismo patrón `_buff` de `HeroAbilities` (token por clave, revierte con `create_timer`), con `use_cooldown`.
- Señal `consumable_cooldown_changed(slot_index, left, total)` para el HUD.

### 2.3 Efecto sobre las stats (R4/R5)
Tercera capa en `PlayerStats`:
```gdscript
var equipment_bonus: Dictionary = {}   # hero_id -> {"hp": n, "attack_damage": n, "attack_interval": f, ...}

func _refresh_hero(s):                 # base -> niveles -> equipo
	...
	_apply_run_attack(s, levels)       # usa también equipment_bonus

func _apply_run_attack(s, levels):
	var eq := equipment_bonus.get(s.hero_id, {})
	s.set_attack(
		cfg.damage_at(s.base_attack_damage, levels) + int(eq.get("attack_damage", 0)),
		maxf(cfg.min_attack_interval, cfg.interval_at(s.base_attack_interval, levels) + float(eq.get("attack_interval", 0.0))))
```
- **Vida**: al equipar → `apply_modifier("hp", +n)`; al desequipar → `apply_modifier("hp", −n)` (el `current_hp` se recorta solo; nunca mata). Si no se resuelve §6.1, el tope 60 anula el bonus.
- `CharacterStats` gana `equipment_bonus: Dictionary` (solo lectura para UI) para mostrar **"base + nivel + equipo"**.
- Los buffs de consumibles usan los multiplicadores temporales ya existentes (`attack_mult`, `damage_taken_mult`), no pisan el equipo.

### 2.4 Flujo de UI (desde el popup del héroe)
```
HeroPortrait (clic derecho / clic en el seleccionado)
  └─ HUDController._on_portrait_clicked → character_popup.open_for(stats, data)
        └─ CharacterPopup
             ├─ ficha + "Subir de nivel" + "Mejoras de clase"   (existentes / sección 1)
             └─ "Equipo" (nuevo, EquipmentSection.gd)
                  ├─ slots del héroe: Arma · Armadura · Reliquia · Consumible ×2  (icono, marco por rareza)
                  └─ "Mochila del grupo" (stash): grilla de ItemStack
```
- Clic en un ítem de la mochila → `can_equip()`; si `""` → `equip()`. Si no, tooltip con la razón. Clic en un slot ocupado → `unequip()` (vuelve al stash; si está lleno, bloquea con texto flotante).
- Tooltip: `ItemData.describe_modifiers()` + comparación `actual → nuevo` (mismo formato que "Subir de nivel").
- Consumibles: botón "Usar" y atajo en el retrato (`HeroPortrait`), deshabilitado en cooldown.
- HUD: contador de mochila junto a `BottomBar` (`HUDController`), toast "Obtenido: X" con `item_acquired`.
- Se refresca por señales (`equipment_changed`, `stash_changed`, `stats_changed`), igual que el resto del popup.
- Drag & drop = fase posterior (§6.12).

### 2.5 Fuentes de ítems
Cofres de salas Botín (existente); recompensa de élites/pisos vía `RoomTypeRule` (campo nuevo `loot_chance`); **no** hay tienda ni moneda (eliminadas en `session/fix-3`).

### 2.6 Assets (ya integrados)
`assets/art/{weapons,armor,items}` (hojas 16×16 normalizadas por `tools/normalize_assets.gd`), los 18 `ItemData` con `icon`. Faltan (auditoría §6): iconos de slot, marcos de rareza y "armaduras sobre sprite" → se usan `placeholder_*` nuevos y colores `ItemData.RARITY_COLORS` mientras tanto; mostrar la armadura sobre el sprite del héroe queda **fuera de alcance**.

### 2.7 Riesgos
Tope de 60 HP (R5); `set_attack` pisa el equipo (R4); mochila sin límite = abusable; licencias ⚠ de las hojas de ítems antes de publicar (auditoría §7); multijugador sin replicación (el inventario sería local).

### 2.8 Tests
`tests/test_inventory.gd`: equipar/desequipar cambia stats exactamente; subir de nivel con equipo no lo pierde; equipo sobrevive `clear_party()` + re-registro; `reset()` en nueva run; `can_equip` por `allowed_heroes` y slot lleno; stash lleno; consumible respeta cooldown.

---

## 3. IA de enemigos con objetivos distintos

### 3.1 Problema actual
El destino se decide dentro de `Enemy` con dos ejes mezclados: `EnemyType.role` (HUNTER/RAIDER) y `Enemy.Variant` (SWARM/SAPPER/HUNTER; el Sapper tiene un caso especial en `_goal_zone`). Los tipos de objetivo (héroe, Nexo, módulo) están escritos a mano en `_goal_zone`/`_goal_point`/`_try_attack_nexo`/`on_zone_entered`. Añadir "rompe-torres" o "asesino" obliga a tocar `Enemy.gd`.

### 3.2 Estructura de datos

**`TargetType`** *(nuevo, enum en `TargetRule`)*: `HERO_NEAREST`, `HERO_WEAKEST`, `HERO_CARRIER` (el que lleva el Nexo), `NEXO`, `MODULE_GENERATOR`, `MODULE_TURRET`, `MODULE_TRAP`, `MODULE_ANY`.

**`TargetRule`** *(nuevo, `Resource`)* — una prioridad:
```gdscript
class_name TargetRule
extends Resource
enum Type { HERO_NEAREST, HERO_WEAKEST, HERO_CARRIER, NEXO,
	MODULE_GENERATOR, MODULE_TURRET, MODULE_TRAP, MODULE_ANY }
enum Condition { ALWAYS, NEXO_CARRIED, NEXO_IDLE }
@export var type: Type
## px; 0 = cualquier punto alcanzable por el grafo revelado.
@export var aggro_range: float = 0.0
@export var condition: Condition = Condition.ALWAYS
## 0 = usar EnemyType.attack_range.
@export var attack_range: float = 0.0
```

**`TargetProfile`** *(nuevo, `Resource`)* — `scripts/core/enemies/TargetProfile.gd`, `.tres` en `resources/enemies/profiles/`:
```gdscript
class_name TargetProfile
extends Resource
enum Fallback { NEAREST_HERO_ZONE, NEXO, HOLD }
@export var id: StringName
@export var display_name: String          # lo usa el bestiario (§4)
@export_multiline var description: String
@export var rules: Array[TargetRule] = []  # ORDEN = prioridad (la primera válida gana)
@export var retaliate: bool = false        # responde al héroe que lo golpea
@export var retaliate_sec: float = 3.0     # = Enemy.REACT_SEC
@export var reeval_sec: float = 1.2        # reemplaza ai_interval de VARIANT_CONFIG
@export var drop_range_mult: float = 1.25  # histéresis para soltar un héroe
@export var fallback: Fallback = Fallback.NEAREST_HERO_ZONE
```
`EnemyType` gana `@export var target_profile: TargetProfile`. **Si es `null`** se deriva de los campos de hoy (`role` RAIDER → perfil Asedio; `behavior` Sapper → Saboteador; si no, Cazador), así los 20 `.tres` actuales funcionan sin editarlos.

### 3.3 Componente `TargetSelector`
*(nuevo)* `scripts/entities/TargetSelector.gd`, `Node` hijo de `Enemy` (se añade a `Enemy.tscn`).

```gdscript
class_name TargetSelector
extends Node

signal target_changed(old: Target, new: Target)
signal target_lost(old: Target)

var profile: TargetProfile
var current: Target                       # null = sin objetivo

func select() -> Target                   # evalúa reglas en orden
func reevaluate(reason: StringName) -> void
func note_hit_by_hero(hero: Player) -> void   # activa retaliate
```
`Target` *(nuevo, `RefCounted`)*: `type`, `node: Node2D`, `zone_id`, `point: Vector2` (dónde acercarse), `attack_range`, `is_valid() -> bool` (`is_instance_valid` + vivo/activo + alcanzable).

Candidatos por tipo (sin tocar las clases objetivo):
| Tipo | Fuente | Válido si |
|---|---|---|
| `HERO_*` | `ManagerLocator.get_heroes()` | `stats.is_alive()` y (`aggro_range` = 0 o distancia ≤ `aggro_range`) y `find_zone_path` ≥ 2 (o misma zona) — la lógica de `Enemy._aggro_hero` actual |
| `HERO_CARRIER` | `ManagerLocator.get_nexo().get_carrier()` | hay portador vivo |
| `NEXO` | `ManagerLocator.get_nexo()` | `is_alive()`; zona/posición = `get_target_zone(rm)`/`get_target_position()` |
| `MODULE_*` | `RoomManager.get_zone_ids()` + `get_modules_in_group()` en salas **reveladas** (la lógica de `_find_zone_with_modules`) | `module.is_active` (aunque esté apagado por falta de energía) y tipo coincide |

**Contrato "targetable"** (duck-typed, ya casi cumplido): `take_damage(int)`, posición global y zona. `Player` ya tiene `global_position`/`current_zone_id`; `Nexo` ya expone `get_target_position()`/`get_target_zone()`; `Module` tiene `global_position`/`zone_id`.

`Enemy` queda **solo** con movimiento (`_pursue_zone` + `EnemyMoveAction`, que ya re-planifica con `goal_changed()`) y ataque. `Enemy._perform_attack()` despacha por `current.type`:
- héroe → daño por **contacto** (`HitboxComponent`, sin cambios; el `attack_range` no interviene, ver `PERSONAJES.md` #15);
- Nexo → `damage_vs_nexo` × multiplicadores (código actual de `_perform_attack`);
- módulo → `module_damage` × multiplicadores.

### 3.4 Reglas de re-evaluación
| Disparador | Cuándo | Acción |
|---|---|---|
| Timer | cada `profile.reeval_sec` (el `AiTimer` actual) | `reevaluate(&"tick")` |
| Objetivo muere/desaparece | `Enemy.died` del objetivo, `Module.module_destroyed`, `Nexo.destroyed`, `tree_exiting` | `target_lost` → `reevaluate(&"lost")` **inmediato** |
| Héroe lo golpea | `Enemy._on_hurt` | si `retaliate`: fija ese héroe durante `retaliate_sec` (reemplaza `_provoked_until_msec`, `BLOCK_RANGE` y `REACT_SEC`) |
| Héroe entra en rango | tick | solo cambia si la regla ganadora tiene **mejor rango de prioridad** |
| Nexo recogido/soltado | `ExtractionManager.phase_changed` | `reevaluate(&"nexo_carried")` (activa `HERO_CARRIER` / condiciones `NEXO_*`) |
| Módulo construido en sala revelada | señal de `RoomManager` (hoy `slot_clicked`/build; se emitirá `module_built`) | `reevaluate(&"module_built")` |
| Objetivo inalcanzable | `find_zone_path` < 2 | marca inválido y pasa a la siguiente regla |

**Estabilidad (anti-parpadeo):** se cambia de objetivo solo si (a) el actual es inválido, o (b) aparece una regla de prioridad **estrictamente mejor**. Un héroe se suelta al superar `aggro_range × drop_range_mult`. Entre dos candidatos del mismo tipo gana el más cercano (menos zonas, luego distancia).

### 3.5 Qué pasa cuando el objetivo muere
`target_lost` → el enemigo detiene el `AttackTimer` (`_resume_moving()` ya existe) → `select()` en el mismo frame → si no hay candidato aplica `fallback`:
- `NEAREST_HERO_ZONE` (default): comportamiento actual (`_player_zone`);
- `NEXO`: va al Nexo;
- `HOLD`: espera en la sala (saboteador sin módulos que no debe vagar).
Si **todos los héroes** son inalcanzables, el perfil Asedio ya apunta al Nexo; los demás usan su `fallback`.

### 3.6 Cambios en Nexo y módulos

**Nexo** (`scripts/world/Nexo.gd`) — ya recibe daño. Cambios:
- *Obligatorios*: ninguno. `take_damage`, `hp_changed`, `under_attack_changed`, `destroyed`, `get_target_position()`, `get_target_zone()` ya cubren el contrato.
- *Opcionales* (diseño): `armor` plano; reparación por recurso; HUD de vida propio (hoy solo grietas y alerta roja).

**Módulos** (`scripts/world/Module.gd`, `TurretModule.gd`, `GeneratorModule.gd`) — reciben daño, pero sin feedback:
- `signal hp_changed(current, maximum)` y `signal damaged(amount)` en `take_damage()`.
- Flash blanco + número flotante reutilizando `resources/shaders/white_flash.gdshader` y el patrón de `Nexo._play_hit` (extraer a un helper pequeño `DamageFeedback` solo si se repite una tercera vez).
- Mini-barra de vida (`Line2D`/`ColorRect` hijo) visible solo si `current_hp < max_hp`.
- `get_target_position() -> Vector2` y `is_targetable() -> bool` (`is_active`, **incluso apagado**: los módulos sin energía siguen siendo destruibles).
- Revisar que un enemigo con `attack_range` ≥ 56 pueda golpear torretas: el `DetectionZone` mide 180 px, así que un "rompe-torres" cuerpo a cuerpo queda **dentro** del alcance de la torreta (efecto deseado: la torre lo castiga mientras destruye).
- `ModuleBuildSystem`/`RoomManager` emiten `module_built(zone_id, module)` *(nueva señal)* para re-evaluar.

### 3.7 Asignación a los 20 enemigos existentes

Perfiles (`resources/enemies/profiles/`):

| Perfil | Reglas (prioridad) | `retaliate` | `fallback` | Nuevo |
|---|---|---|---|---|
| **Asedio** (`siege`) | `NEXO` (siempre) | sí | `NEXO` | no — es el RAIDER de hoy |
| **Cazador** (`hunter`) | `HERO_NEAREST` (aggro 320) → `HERO_NEAREST` (todo el grafo) | no | `NEAREST_HERO_ZONE` | no — es el HUNTER de hoy |
| **Saboteador** (`saboteur`) | `MODULE_GENERATOR` → `MODULE_ANY` → `HERO_NEAREST` | no | `HOLD` | no — es el Sapper de hoy, afinado |
| **Rompe-torres** (`tower_breaker`) | `MODULE_TURRET` → `MODULE_TRAP` → `HERO_NEAREST` | no | `NEAREST_HERO_ZONE` | **sí** |
| **Asesino** (`assassin`) | `HERO_CARRIER` → `HERO_WEAKEST` (aggro 480) → `HERO_NEAREST` | no | `NEAREST_HERO_ZONE` | **sí** |

Asignación (comportamiento de hoy preservado salvo donde se indica *cambio*):

| Enemigo | Perfil | Nota |
|---|---|---|
| `goblin`, `masked_orc`, `orc_warrior` | Asedio | igual que hoy (RAIDER, `damage_vs_nexo` 4) |
| `skelet`, `orc_shaman`, `wogol`, `necromancer`, `tc_eyeball`, `tc_dragon` | Cazador | igual que hoy |
| `tiny_zombie`, `big_zombie`, `ogre`, `tc_ogre` | Saboteador | *cambio menor*: prioriza generadores (economía) antes que cualquier módulo |
| `tc_fire_skull`, `big_demon` | Rompe-torres | *cambio*: antes Sapper/Hunter genérico |
| `imp`, `tc_red_imp`, `tc_wolf`, `chort`, `tc_demon` | Asesino | *cambio*: los rápidos (velocidad 450-700) van por el portador/el héroe más débil; da uso a la fase de extracción |

Enemigos nuevos a considerar (solo datos, sin código, siempre que haya `SpriteFrames`): un 2º **Cazador de portador** para la extracción y, si se acepta romper la estética medieval (§6.10), `zombie`/`ice_zombie` con perfil Saboteador (las familias existen en `assets/art/enemies` sin `SpriteFrames`, auditoría §4-5).

### 3.8 Compatibilidad y migración
1. Introducir `TargetProfile`/`TargetRule`/`TargetSelector` con el **perfil derivado** de `role`/`behavior`; el comportamiento no cambia (aceptación: `test_enemy_roles.gd` y `test_raider_timing.gd` en verde **sin editarlos**).
2. Mantener `Enemy._aggro_hero`, `_goal_zone`, `_goal_point`, `_is_raiding` como **wrappers** que delegan en el selector (los tests los llaman); `Enemy.role` queda como propiedad derivada (`profile.counts_as_raider`: `true` si la primera regla es `NEXO`) para `FloorManager.roll_role`, `EnemyPool.roll`, `EnemyManager.raider_arrival_sec` y `BalanceSim`.
3. Recién después, asignar perfiles nuevos en los `.tres` y actualizar los tests para usar `selector.current`.
4. Actualizar `docs/ENEMY_TARGETING.md` y la sección Enemies de `CLAUDE.md`.

### 3.9 Tests
`tests/test_target_selector.gd`: prioridad entre reglas (hay Nexo y módulo y héroe), histéresis, objetivo muerto → siguiente, retaliate, `HERO_CARRIER` tras recoger el Nexo, módulo apagado sigue siendo objetivo, fallback `HOLD`. Más: los dos tests existentes sin modificar.

---

## 4. Enciclopedia de enemigos (bestiario) en la pausa

### 4.1 Datos

**`EnemyType`** gana (todos opcionales, defaults vacíos → no rompe los 20 `.tres`):
```gdscript
@export_multiline var description: String   # texto de ambientación, ≤ 2 líneas
@export_multiline var lore: String          # se muestra al máximo nivel
@export var bestiary_order: int = 0
```
El **comportamiento** mostrado sale de `TargetProfile.display_name`/`description` (§3.2), no se duplica en el `EnemyType`.

**`BestiaryEntry`** *(nuevo)* — `scripts/core/bestiary/BestiaryEntry.gd`, `RefCounted` serializable a `Dictionary`:
```gdscript
class_name BestiaryEntry
extends RefCounted
enum Tier { UNKNOWN, SEEN, KILLED, MASTERED }
const MASTER_KILLS := 3

var enemy_id: String
var seen_count: int = 0
var kill_count: int = 0
var first_seen_floor: int = 0
var first_kill_floor: int = 0
var max_floor_seen: int = 0

func tier() -> Tier:
	if kill_count >= MASTER_KILLS: return Tier.MASTERED
	if kill_count > 0: return Tier.KILLED
	return Tier.SEEN if seen_count > 0 else Tier.UNKNOWN
func to_dict() -> Dictionary
static func from_dict(d: Dictionary) -> BestiaryEntry
```

### 4.2 Qué se desbloquea y cuándo

| Nivel | Condición | Se muestra |
|---|---|---|
| `UNKNOWN` | nunca visto | silueta oscura + "???" |
| `SEEN` | primera aparición | sprite animado (`idle`), nombre, perfil de comportamiento (`TargetProfile.display_name`), pisos donde apareció |
| `KILLED` | primera muerte | + HP, velocidad, daño de contacto, descripción |
| `MASTERED` | 3 muertes | + daño al Nexo/módulos, rol, rango de pisos del pool (`enemy_pool_f1..f5`), lore |

Qué cuenta como "visto": **recomendado** = primer spawn en una sala revelada (todas lo son: `EnemyManager.get_spawn_rooms` solo usa salas reveladas) — barato y sin ambigüedad. Alternativa (más fiel a "ver"): que comparta zona con un héroe (§6.6).

Las **stats mostradas** son las base × multiplicadores del piso donde se registró (`Enemy.resolved_hp/_speed/_contact_damage/_module_damage` ya son estáticas y reutilizables, `Enemy.gd:37-55`).

### 4.3 Servicio `BestiaryService`
*(nuevo, autoload)* — `scripts/autoload/BestiaryService.gd`, `ManagerLocator.get_bestiary() -> BestiaryService`:
```gdscript
signal entry_updated(enemy_id: String)
signal entry_unlocked(enemy_id: String, tier: BestiaryEntry.Tier)   # subió de nivel

var entries: Dictionary = {}          # enemy_id -> BestiaryEntry

func register_seen(type: EnemyType, floor_index: int) -> void
func register_kill(type: EnemyType, floor_index: int) -> void
func get_entry(enemy_id: String) -> BestiaryEntry   # nunca null (UNKNOWN)
func get_tier(enemy_id: String) -> BestiaryEntry.Tier
func get_all_ordered() -> Array[EnemyType]           # todos los .tres de resources/enemies, por bestiary_order
func unlocked_count() -> int
func write_to(cfg: ConfigFile) -> void
func read_from(cfg: ConfigFile) -> void
func reset() -> void                                 # solo para tests / "borrar slot"
```
**Fuentes de eventos** (sin tocar la lógica de IA):
- `EnemyManager` gana `signal enemy_spawned(enemy: Enemy)` (hoy solo tiene `invasion_triggered`; `_spawn_enemy` ya conecta `Enemy.died`) → `register_seen`.
- `Enemy.died(enemy)` ya existe y `EnemyManager._on_enemy_died` ya lo recibe → `register_kill`. **Solo cuenta si la muerte fue por daño** (héroe/torreta), no por `queue_free()` al cambiar de piso.
- `HUDController` escucha `entry_unlocked` y muestra un hint/toast "Nuevo registro: Goblin" (`show_hint`/`FloatingText`).

### 4.4 Persistencia (guardado)
- **Por slot**, en el mismo `user://slot_N.cfg`: sección `[bestiary]`, una clave por enemigo (`goblin = {seen=…, kills=…, …}`) + `version = 1`.
- `SaveManager.save_game()` agrega `BestiaryService.write_to(cfg)` y `load_game()` llama `read_from(cfg)`. Slot nuevo/sin save → bestiario vacío (`reset()`).
- Guardado **diferido** (`call_deferred` + bandera "dirty") tras cada `entry_updated`, más el `flush_saves()` ya existente al salir/reintentar/avanzar piso. Cubre cierre abrupto sin escribir en cada golpe.
- **No** se resetea en `Main._begin_new_run()` (es progreso permanente). `SaveManager.delete_save(slot)` borra el archivo entero, y con él el bestiario del slot.
- Migración: `version` permite añadir campos; ids desconocidos (enemigo eliminado) se ignoran al cargar.
- Nota: `SaveManager` hoy carga/guarda **solo** cuando hay slot activo; el diagnóstico (§7, R25) señala campos muertos en el guardado. El bestiario es un buen motivo para limpiarlos en la misma sesión.

### 4.5 Escenas y UI
```
scenes/menus/BestiaryPanel.tscn            (nuevo)  extends BaseSubPanel
  ├─ Header: título "Bestiario" + contador "12/20" + botón Volver
  ├─ HSplit
  │   ├─ Lista (ScrollContainer + GridContainer de BestiaryListItem)   [filtros: familia / perfil]
  │   └─ Detalle (BestiaryDetail): sprite animado ×4, nombre, perfil, stats por nivel, descripción, lore
scripts/ui/menus/BestiaryPanel.gd          (nuevo)
scripts/ui/menus/BestiaryListItem.gd       (nuevo)  sprite 32×32 (idle frame 0), oscurecido si UNKNOWN
```
- Los `SpriteFrames` ya existen para los 20 tipos (`resources/sprite_frames/enemy_*`, `tc_*`); los `tc_*` tienen **1 frame** (sin animación, auditoría §5) → el detalle usa el rebote procedural de `CharacterVisual` o queda estático.
- Estilos: `UiStyles.build_panel_style` + `QuestPalette`, mismos que `PauseMenu`/`CharacterPopup`.
- Texto en español inline (como el resto de la UI; i18n sigue a medias, diagnóstico R24).

### 4.6 Integración con el menú de pausa actual
Cambios concretos en `scenes/menus/PauseMenu.tscn` y `scripts/ui/menus/PauseMenu.gd`:
1. Nuevo `BestiaryButton` entre `OptionsButton` y `ExitButton` dentro de `PauseVBox` (mismo `theme_override_*` que `OptionsButton`, texto "BESTIARIO").
2. Instancia de `BestiaryPanel` como hijo de `PauseMenu` (hermana de `OptionsMenu`, `unique_name_in_owner`).
3. `panels: Array[Control] = [pause_panel, options_menu, bestiary_panel]`; en `_set_panel(i)` el caso `i == 2` abre/cierra como el de `1` (`bestiary_panel.open()`); `_on_bestiary_closed` → `_set_panel(0)`; `_on_before_close` también cierra el bestiario.
4. Layout: `PausePanel.custom_minimum_size` 330 → ≈420 y `PauseVBox` offsets ±126 → ≈±171 (un botón de 70 + separación 20 = +90).
5. `connect_button(bestiary_button, func(): _set_panel(2))` en `_connect()`; `_style_button(bestiary_button)` en `_apply_theme()`.
6. Esc dentro del panel cierra solo el panel (mismo manejo de `ui_cancel` que `OptionsMenu`); como `PauseMenu` es `PROCESS_MODE_ALWAYS` y pausa el árbol, no hay interferencia con la pausa táctica (`Engine.time_scale`).
7. Opcional (§6.11): el mismo `BestiaryPanel` también en `MainMenu`, ya que es meta-progresión.

### 4.7 Tests
`tests/test_bestiary.gd`: tiers (`SEEN` → `KILLED` → `MASTERED`), `register_kill` ignora muertes sin daño, ida y vuelta por `ConfigFile` (`write_to`/`read_from`), dos slots independientes, id desconocido ignorado, `get_all_ordered()` devuelve los 20 `.tres`. Un chequeo de `PauseMenu`: abre `BestiaryPanel` y vuelve (con el `Main2d` **completo**, ver aviso de falsos verdes del diagnóstico §10).

---

## 5. Plan de implementación

### 5.1 Orden y dependencias

```
Fase 0 (previa, recomendada)  R1/R2 del diagnóstico: arreglar los 3 tests rojos + runner de tests
        │
        ├─ Fase 3A  TargetSelector (refactor sin cambio de comportamiento)
        │      └─ Fase 3B  perfiles nuevos + HP visible en módulos
        │               └─ Fase 4  Bestiario (usa TargetProfile para "comportamiento")
        │
        ├─ Fase 1  HeroPerk  ──────────┐
        └─ Fase 2A  PartyInventory (datos + stats)
                 └─ Fase 2B  UI de equipo (usa el popup ya ampliado por Fase 1)
```
Orden recomendado: **0 → 3A → 3B → 4 → 1 → 2A → 2B**. Razones: 3 y 4 no dependen de equipo/perks; el bestiario es lo de más valor visible por poco riesgo; 1 y 2 tocan `PlayerStats` y conviene hacerlas seguidas con la red de seguridad ya sólida.

### 5.2 Fases

| Fase | Sesión Claude Code | Crear | Modificar | Riesgo | Criterios de aceptación |
|---|---|---|---|---|---|
| **0** | 1 | `tools/run_tests.ps1` | `tests/test_hud_ui.gd`, `test_map_flow.gd`, `test_sprites.gd` (leer valores de `.tres`) | Bajo | Los 20+ tests pasan; un comando, exit ≠ 0 si falla alguno |
| **3A** | 1 | `scripts/core/enemies/{TargetRule,TargetProfile}.gd`, `scripts/entities/TargetSelector.gd`, `Target.gd` | `Enemy.gd` (delega), `Enemy.tscn` (+nodo), `EnemyType.gd` (+`target_profile`) | **Medio-alto** (corazón de la IA, 444 líneas, tests con privados) | `test_enemy_roles.gd` y `test_raider_timing.gd` **sin editar** en verde; `Enemy.gd` < ~300 líneas; boot `Main2d.tscn --quit-after 90` sin `SCRIPT ERROR`; mismo resultado en `tools/BalanceSim` |
| **3B** | 1 | `resources/enemies/profiles/*.tres` (5), `tests/test_target_selector.gd` | `resources/enemies/*.tres` (asignar), `Module.gd`/`TurretModule.gd`/`GeneratorModule.gd` (HP visible, `hp_changed`, `get_target_position`), `RoomManager` (`module_built`), `docs/ENEMY_TARGETING.md` | Medio (balance: rompe-torres y asesinos cambian la dificultad) | Cada enemigo ataca su objetivo (test); el módulo muestra daño; objetivo muerto → reasigna en el mismo frame; revisar `docs/BALANCE.md` con `BalanceSim` |
| **4** | 1-2 | `scripts/core/bestiary/BestiaryEntry.gd`, `scripts/autoload/BestiaryService.gd`, `scenes/menus/BestiaryPanel.tscn`, `scripts/ui/menus/{BestiaryPanel,BestiaryListItem}.gd`, `tests/test_bestiary.gd` | `EnemyManager.gd` (+`enemy_spawned`), `EnemyType.gd` (+texto), `resources/enemies/*.tres` (descripciones ×20), `SaveManager.gd`, `ManagerLocator.gd`, `project.godot` (autoload), `PauseMenu.gd/.tscn`, `HUDController.gd` (toast) | Medio (primer guardado cruzado de runs, UI nueva de pausa) | Matar un enemigo desbloquea su ficha; reiniciar el juego conserva el progreso (round-trip en test); slots independientes; Esc/Volver correctos dentro de la pausa; sin fugas de `Engine.time_scale` |
| **1** | 1 | `scripts/core/stats/HeroPerk.gd`, `resources/perks/*.tres` (16), `tests/test_perks.gd` | `PlayerStats.gd` (+`run_perks`, elección), `HeroAbilities.gd` (getters), `CharacterData.gd`, `CharacterStats.gd` (+`attack_range_changed`), `Player.gd`, `CharacterPopup.gd`, `resources/characters/*.tres` (asignar perks) | Medio (toca `PlayerStats`) | Un perk cambia exactamente el stat/habilidad; persiste a través de pisos; se resetea por run; `test_abilities`/`test_party` en verde |
| **2A** | 1-2 | `scripts/autoload/PartyInventory.gd`, `scripts/core/items/{ItemStack,InventoryComponent}.gd`, `tests/test_inventory.gd` | `ItemData.gd`, `PlayerStats.gd` (capa de equipo, alias de `found_items`), `CharacterStats.gd`, `LootSpawner.gd`, `Player.gd`, `Main.gd` (`_begin_new_run`), `ManagerLocator.gd`, `project.godot`, `StatBalance.gd` (según §6.1) | **Medio-alto** (R4/R5) | Equipar/desequipar cambia stats exactos; subir de nivel conserva el equipo; sobrevive al cambio de piso; reset por run; `test_items.gd` en verde |
| **2B** | 1 | `scripts/ui/hud/EquipmentSection.gd` (+ ítems de lista) | `CharacterPopup.gd`, `HeroPortrait.gd` (atajo consumible), `HUDController.gd` (contador/toast) | Medio (UI) | Equipar desde el popup en partida real; tooltips con comparación; mochila llena bloquea con mensaje |

### 5.3 Verificación común a todas las fases
- `godot --headless --path . res://scenes/Main2d.tscn --quit-after 90` sin `SCRIPT ERROR`.
- `tests/*.gd` uno por uno (o el runner de Fase 0) tras reindexar con `--editor --quit` si hay `class_name` nuevos.
- Cuidado con el aviso de **falsos verdes** del diagnóstico §10: los tests que arrancan `Main2d` en `--script` pueden correr con `Main2d` incompleto; las pruebas de `PauseMenu`/overlays deben ejecutarse con el árbol completo.
- Verificación **visual en ventana real** al cerrar cada fase con UI (3B módulos, 4, 2B): los tests headless no ven el layout.
- Cada fase actualiza `CLAUDE.md` (una línea de sesión) y el doc correspondiente (`PERSONAJES.md`, `ENEMY_TARGETING.md`, `docs/BALANCE.md`).

### 5.4 Cómo dividirlo en sesiones
Una sesión = una fila de la tabla (las de "1-2" se parten en *datos+tests* y *UI*). Cada sesión: rama propia `session/<tema>-N` desde la anterior (como el resto del proyecto), commits chicos por archivo lógico, y un prompt que cite este documento y la fila de la fase. No mezclar 3A con 3B: 3A **no debe cambiar comportamiento** para que los tests existentes sirvan de prueba.

---

## 6. Decisiones abiertas

Cada una con mi recomendación.

| # | Decisión | Opciones | Recomendación |
|---|---|---|---|
| 6.1 | **Tope de vida** (`PLAYER_MAX_HP` 60) frente a armaduras de +20…+30 | a) subir el tope global (p. ej. 120) · b) tope aparte solo para equipo · c) rebalancear las armaduras a +5…+12 | **(a)** con el tope en 120 y revisar `docs/BALANCE.md`; sin esto las armaduras altas no hacen nada. Es lo primero a resolver |
| 6.2 | **Slots por héroe y mochila** | Arma 1 · Armadura 1 · Reliquia 1 · Consumible 2; mochila de 20 | Esa configuración (más chica = más decisiones, más grande = hoarding) |
| 6.3 | **Persistencia del equipo** | solo la run · entre runs | Entre **pisos**: sí. Entre **runs**: no (no hay meta-progresión; sería abrir R25) |
| 6.4 | **Stats nuevos** (`armor`, `move_speed`, "provocar") | solo existentes · añadir `armor` · añadir `move_speed` y taunt | Empezar con los **existentes**; `armor` plano en una fase posterior (barato: ya hay un mínimo de 1 en `HeroAbilities.incoming_damage`); `move_speed`/taunt cuando se haga el Pícaro/Guerrero |
| 6.5 | **Perks**: elegir 1 de 2 vs. árbol | 1 de 2 en niveles 3 y 5 · árbol libre | **1 de 2**: poca UI, decisiones claras, datos simples |
| 6.6 | **"Visto" en el bestiario** | primer spawn · misma zona que un héroe · dentro del radio del héroe | **Primer spawn** (el spawn ocurre siempre en sala revelada); si se siente "regalado", pasar a "misma zona que un héroe" |
| 6.7 | **Umbrales de desbloqueo** | 1/3 kills · otros | Visto → nombre/sprite; 1 muerte → stats; 3 muertes → todo. Ajustable con la constante `MASTER_KILLS` |
| 6.8 | **Bestiario por slot vs. global** | por slot · un archivo `user://bestiary.cfg` | **Por slot** (consistente con el guardado actual; `delete_save` lo borra); global solo si se quiere que cruce slots |
| 6.9 | **Consumibles en la pausa táctica** | permitidos · bloqueados | **Bloqueados** (`Engine.time_scale > 0`, como la habilidad `Q`, `HeroAbilities._input_allowed`) para no abusar de la pausa |
| 6.10 | **Enemigos nuevos con arte fuera de estética** (`zombie`, `ice_zombie`, `slug`…, auditoría §4) | usarlos · diseñar arte medieval | **No usarlos todavía**; los perfiles nuevos reasignan enemigos existentes, que ya dan variedad |
| 6.11 | **Bestiario también en el menú principal** | solo pausa · también `MainMenu` | Solo pausa en la primera versión (lo pedido); el panel es reutilizable si se agrega después |
| 6.12 | **Drag & drop** en el inventario | clic · arrastrar | Clic en la primera versión; drag & drop después |
| 6.13 | **Antes de la meta-progresión** (bestiario) resolver R13 `RunState` y R25 (guardado con campos muertos) | hacerlo antes · integrarlo | Integrar el bestiario y limpiar los campos muertos de `SaveManager` en la **misma** sesión; el `RunState` completo no es bloqueante |
| 6.14 | **i18n** de los textos nuevos | español inline · `tr()` | Español inline, igual que el resto de la UI (R24 del diagnóstico queda pendiente) |
| 6.15 | **Licencias ⚠** de las hojas de ítems (auditoría §7) | publicar así · resolver antes | Resolver **antes** de publicar en Steam: el inventario las vuelve visibles al jugador |
| 6.16 | **Multijugador** | ignorar · replicar | Ignorar: no hay replicación de partida hoy (diagnóstico §7); el inventario y el bestiario serían locales |
