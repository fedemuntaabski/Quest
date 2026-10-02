# Personajes de Quest — héroes, enemigos y Nexo

Archivo de referencia para otras sesiones. **Todo sale del código y los `.tres` de `session/refactor-2` (`41a44ab`)**; lo que no existe se dice "no existe". Valores base = piso 1, sala normal, nivel 1. Las rutas son relativas a la raíz del repo; las referencias `archivo:línea` son de este commit. Los números derivados (DPS, HP a nivel máx., stats de enemigos tras multiplicadores) se calcularon con las fórmulas del código (`Enemy.resolved_*`, `UpgradeConfig`, `FloorConfig`) y se contrastaron con `docs/BALANCE.md`.

Índice: [1 Héroes](#1-héroes-jugables) · [2 Enemigos](#2-enemigos) · [3 El Nexo](#3-el-nexo) · [4 Tablas comparativas](#4-tablas-resumen) · [5 Inconsistencias y faltantes](#5-inconsistencias-o-datos-faltantes)

---

## 1. Héroes jugables

### Cómo funciona un héroe (común a los 4)
- **Datos**: `CharacterData` (`scripts/core/stats/CharacterData.gd`), un `.tres` por héroe en `resources/characters/` (`warrior`, `mage`, `rogue`, `tank`), registrados en orden fijo en `CharacterDatabase.CHARACTER_PATHS` (`scripts/core/stats/CharacterDatabase.gd:9`). Hay `party_config.tres` (`PartyConfig`) solo como grupo por defecto si no hubo selección en `HeroSelectMenu`.
- **Escena**: una sola, `scenes/entities/Player.tscn` (`Player.gd`), con `AnimatedSprite2D` (`CharacterVisual`), `Stats` (`CharacterStats`), `Hurtbox` (capa 3 `player_hurtbox`), `Hitbox` (máscara capa 4 `enemy_hurtbox`, AoE circular), `Camera2D` (`GameCamera`, solo la usa el primer héroe). `Player.configure(data)` aplica `base_hp`, ataque, rango, sprite y habilidades en `_ready()` (`Player.gd:40-57`).
- **Combate**: automático, sin input. El `Hitbox` es un círculo de radio `attack_range` que cada `attack_interval` s daña a **todos** los enemigos que lo solapan (`HitboxComponent`). No hay proyectiles ni selección de objetivo.
- **Daño recibido**: los enemigos pegan por contacto (1 golpe/s); `HeroAbilities.incoming_damage()` aplica pasiva y escudo, mínimo 1 (`HeroAbilities.gd:70`). **No existe stat de defensa/armadura**: solo `damage_taken_mult` (escudo temporal) y las pasivas.
- **Velocidad de movimiento**: **no existe stat por héroe**. Todos planean a `MoveAction.DEFAULT_SPEED_PX = 420` px/s (`MoveAction.gd:8`); el portador del Nexo va a ×0.75 = 315 px/s (`PlayerActionController.gd:216`).
- **Muerte**: si cualquier héroe muere, termina la partida (`PlayerStats.player_died` → `Main2d._on_player_died`).
- **Habilidad activa**: tecla **Q** (`hero_ability`) para todos los héroes seleccionados; se aplica solo con tiempo de juego (la pausa táctica congela los cooldowns). Una sola pasiva y una sola activa por héroe (`AbilityData`).
- **Selección**: se eligen 2 de 4 en `HeroSelectMenu` (guardado en `GameSession`); `SelectionManager` maneja selección múltiple y grupos 1–3.

### Fichas
Sprites 0x72 `16×28` (idle 4 f, run 4 f, hit 1 f), dibujados ×2 (`ArtConfig.ART_SCALE`). Todos tienen: ataque ✘, muerte ✘ (ver `docs/ASSETS_AUDITORIA.md` §5). Retratos 1024×1024 en `assets/portraits/`.

#### Guerrero — `warrior`
| Campo | Valor | Fuente |
|---|---|---|
| Rol | "Tanque y Provocador" | `warrior.tres` |
| Sprite | `resources/sprite_frames/hero_knight_m.tres` · retrato `assets/portraits/guerrero.png` | |
| Vida | **26** | `base_hp` |
| Ataque | **4** de daño cada **1.2 s** (DPS 3.33 por objetivo), radio **150** px | `attack_damage/interval/range` |
| Defensa / velocidad | no existe (420 px/s común) | |
| Pasiva "Piel de Hierro" | `DAMAGE_REDUCTION_PCT` 0.2: ignora **20 %** del daño recibido, siempre | `warrior_passive.tres` |
| Activa "Grito de Guerra" | `TEAM_ATTACK_BUFF` 0.5: héroes **vivos de su misma sala** (él incluido) ×1.5 de daño durante **8 s**; cooldown **25 s**; VFX `buff_attack` | `warrior_active.tres` |
| Color VFX | (0.92, 0.36, 0.26) | |

#### Mago — `mage`
| Campo | Valor |
|---|---|
| Rol | "Ciencia y Módulos" |
| Sprite | `hero_wizzard_m.tres` · `assets/portraits/mago.png` |
| Vida | **18** |
| Ataque | **3** cada **0.9 s** (DPS 3.33), radio **220** px (el mayor) |
| Pasiva "Mente Analítica" | `SCIENCE_ON_DISCOVERY` 2: **+2 Ciencia** cada vez que se descubre una sala (`FloorManager.on_room_discovered`) |
| Activa "Sobrecarga de Módulo" | `MODULE_OVERCHARGE` 1.0: torres de su sala ×2 de daño durante **8 s**; **cada generador de su sala paga un tick extra al instante**; cooldown **30 s**; VFX `buff_module` |
| Color VFX | (0.62, 0.52, 1.0) |

#### Pícaro — `rogue`
| Campo | Valor |
|---|---|
| Rol | "Explorador Rápido" |
| Sprite | `hero_elf_m.tres` · `assets/portraits/picaro.png` |
| Vida | **18** |
| Ataque | **2** cada **0.5 s** (DPS 4.0, el mayor), radio **130** px (el menor) |
| Pasiva "Paso Ligero" | `DUST_ON_DISCOVERY` 2: **+2 Polvo** al descubrir una sala (se suma a los 4 base de `FloorConfig.dust_per_discovery`) |
| Activa "Golpe Furtivo" | `BURST_STRIKE` 3.0: daña **una vez** a todo enemigo dentro de su radio con **3×** su daño de ataque; sin duración; cooldown **12 s**; VFX `hit_slash` + temblor de cámara |
| Color VFX | (0.45, 0.92, 0.50) |

#### Tanque — `tank`
| Campo | Valor |
|---|---|
| Rol | "Defensor de Cristal" |
| Sprite | `hero_dwarf_m.tres` · `assets/portraits/tanque.png` |
| Vida | **40** (la mayor) |
| Ataque | **3** cada **1.3 s** (DPS 2.31, el menor), radio **170** px |
| Pasiva "Muro Viviente" | `NEXO_PROXIMITY_REDUCTION` 0.5, radio 640: reduce hasta **50 %** el daño recibido junto al Nexo, decreciendo linealmente a 0 a **640 px** (mide contra la posición del Nexo; si lo lleva alguien, contra el portador) |
| Activa "Interposición" | `TEAM_SHIELD` 0.5: **todos** los héroes vivos reciben **50 %** del daño durante **6 s**; cooldown **30 s**; VFX `buff_shield` |
| Color VFX | (0.62, 0.78, 1.0) |

### Escalado con mejoras (en partida)
No hay XP ni persistencia entre partidas: solo **niveles de héroe** comprados con **Comida** en el popup del héroe (`PlayerStats.level_up_hero()`, `scripts/core/stats/PlayerStats.gd:221`; datos en `UpgradeConfig` + `resources/upgrades/run_upgrade_config.tres`). Se reinician cada partida (`Main._begin_new_run`), sobreviven a los pisos.
- Hasta **5 niveles** (nivel 1 → 6). Costo en Comida: `round(8 × 1.4^nivel)` = **8, 11, 16, 22, 31** (88 en total).
- Por nivel, los tres juntos: **+4 vida máx.** (y vida actual), **+1 daño**, intervalo de ataque **−5 %** del base por nivel (el `.tres` pisa el default de 10 %; mínimo 0.3 s, `.tres` pisa el default 0.2).
- Vida máxima tope global: `StatBalance.PLAYER_MAX_HP = 60` (`StatBalance.gd:9`).
- Investigación (`ResearchConfig`) no toca stats de héroes (solo módulos, costo de energizar y descubrimiento).

| Héroe | Nivel 1 | Nivel 6 (máx.) |
|---|---|---|
| Guerrero | 26 vida · 4 dmg · 1.2 s | 46 vida · 9 dmg · 0.90 s |
| Mago | 18 · 3 · 0.9 s | 38 · 8 · 0.675 s |
| Pícaro | 18 · 2 · 0.5 s | 38 · 7 · 0.375 s |
| Tanque | 40 · 3 · 1.3 s | **60** (justo el tope) · 8 · 0.975 s |

Efectos temporales sobre `CharacterStats`: `attack_mult` (Grito de Guerra) y `damage_taken_mult` (Interposición), ambos revertidos por temporizador (`HeroAbilities._buff`).
Otros efectos que tocan al héroe: salas **Rest** curan 15 a todo el grupo al descubrirse (`RoomTypeRule.heal_on_discovery`).

### Equipamiento
**Ningún héroe admite equipamiento hoy.** `ItemData` (`scripts/core/items/ItemData.gd`) define `slot` {WEAPON, ARMOR, CONSUMABLE, RELIC}, `rarity` y `modifiers` (solo `hp`, `attack_damage`, `attack_interval`), y hay 18 ítems en `resources/items/`, pero **no se aplican a los héroes**: solo se muestran (`Pickup`, cofres de salas Botín, sección "Hallazgos" del popup; `PlayerStats.found_items`). Los héroes no tienen slots de equipo ni restricciones por clase.
| Slot | Ítems (modificadores) |
|---|---|
| Arma | bronce +1 dmg · hierro +2 · acero +3 · jade +4 · brasa +3 dmg y −0.1 s · dorada +5 dmg y −0.1 s |
| Armadura | cuero +5 vida · túnica +6 vida y +1 dmg · hierro +10 · cobre +14 · acero +20 · dorada +25 · jade +30 vida y +2 dmg |
| Consumible | poción de vida +10 vida · de furia +2 dmg · de claridad −0.05 s |
| Reliquia | grimorio de brasas +2 dmg · de mareas −0.15 s |

---

## 2. Enemigos

### Cómo funciona un enemigo (común)
- **Escena**: una sola, `scenes/entities/Enemy.tscn` (`scripts/entities/Enemy.gd`, `CharacterBody2D`, capa 2 `enemy_body`, grupo `enemies`): `Visual` (`CharacterVisual`), `AiTimer`, `AttackTimer` (1 s), `Hurtbox` (capa 4 `enemy_hurtbox`, radio inicial 14), `Hitbox` (máscara capa 3 `player_hurtbox`, contacto, radio 24). Cada tipo solo cambia el `SpriteFrames` y los números; `Enemy._apply_visual()` ajusta radios al tamaño dibujado.
- **Datos**: `EnemyType` (`scripts/core/enemies/EnemyType.gd`; **no existe `EnemyData`**), 20 `.tres` en `resources/enemies/`: 13 0x72 + 7 Tiny Creatures (`tc_*`). Stats base por `behavior` (Swarm/Sapper/Hunter) en `Enemy.VARIANT_CONFIG` (`Enemy.gd:13-17`):
  | behavior | HP | velocidad px/s | daño de contacto | daño a módulos/tick | `ai_interval` |
  |---|---|---|---|---|---|
  | Swarm (0) | 6 | 500 | 2 | 2 (`DEFAULT_ATTACK_DAMAGE`) | 1.2 s |
  | Sapper (1) | 10 | 380 | 1 | 3 (`damage_per_tick`) | 2.0 s |
  | Hunter (2) | 8 | 400 | 3 | 2 | 1.2 s |
- **Stats finales** = base × multiplicadores del tipo (`hp_mult`, `damage_mult`, `speed_mult`) × piso × sala:
  - HP = `round(base_hp × hp_mult_tipo × hp_piso × hp_sala)`, mínimo 1; daño de contacto y a módulos = `round(base × dmg_mult_tipo × dmg_piso × dmg_sala)`, mínimo 1.
  - Piso (`default_floor_config.tres`): HP `1 + 0.15·(piso−1)` (1.0, 1.15, 1.30, 1.45, 1.60); daño `1 + 0.10·(piso−1)` (1.0 … 1.40).
  - Sala **Élite**: HP ×1.5, daño ×1.25 (`RoomTypeRule`). Sala **Rest** no genera enemigos.
  - Velocidad = `base_speed × speed_mult` (el piso no la modifica); una **Trampa** la reduce a ×0.5 durante 3 s.
- **Roles** (`EnemyType.role`, desde `session/enemies-2`; detalle en `docs/ENEMY_TARGETING.md`):
  - **HUNTER**: persigue al héroe más cercano dentro de `aggro_range` (320 px, alcanzable por el grafo revelado); si no hay, va a la zona del héroe más cercano. El Sapper va primero a salas con módulos.
  - **RAIDER**: ignora héroes y módulos, camina por `RoomManager.find_zone_path` hasta la zona del Nexo (sala de inicio o la del portador) y lo golpea desde `attack_range` (56 px) cada 1 s con `damage_vs_nexo`. Se comporta como hunter si un héroe está a ≤48 px o lo golpeó en los últimos 3 s. Marcado con tinte rojizo y rombo rojo. Solo `goblin`, `masked_orc`, `orc_warrior` son RAIDER (`damage_vs_nexo` 4, `attack_range` 56).
- **Movimiento**: sin física ni pathfinding real; `EnemyMoveAction` planea tweens entre centros de zonas reveladas (re-planifica tras cada tramo). Se reparten en un anillo de 8 posiciones (`slot`) para no apilarse.
- **Ataque a héroes**: solo **contacto** (`Hitbox` de contacto, 1 golpe/s, sin proyectiles ni habilidades). **Ataque a módulos**: al entrar a una sala con un `Module` activo (si no es raider), se queda y lo golpea cada 1 s hasta destruirlo.
- **Aparición**: invasiones al abrir puerta (`EnemyManager._on_turn_advanced`: P = mín(0.85, 0.05 + 0.08·salas_oscuras + 0.015·turno + 0.05·(piso−1)); cantidad 1 + ⌊turno/5⌋ + extra por piso) y oleadas de extracción (1 enemigo por sala oscura cada 5 s, −0.5 s por piso, mín 2 s). Siempre en salas **oscuras** reveladas (sin energía).
- **Rol y tipo al aparecer**: `FloorManager.roll_role()` (proporción de RAIDER por piso: **5 %, 20 %, 35 %, 50 %, 60 %**), luego `EnemyPool.roll(role)` por pesos del piso; un raider que llegaría al Nexo en menos de 4 s desde su sala de aparición se cambia por un hunter.
- **Sin recompensa**: matar a un enemigo no da recursos ni botín (`EnemyManager._on_enemy_died` solo lo saca de la lista).
- **Animaciones** (idéntico para todos los de una misma familia): 0x72 → `idle` 4 f + `run` 4 f; ataque ✘, daño ✘ (parpadeo blanco), muerte ✘ (VFX `death_dust`). Tiny Creatures → 1 frame estático (rebote procedural), todo lo demás ✘.

### Fichas por tipo (piso 1, sala normal)
`beh` = behavior (S Swarm · P Sapper · H Hunter); la velocidad ya incluye `speed_mult`. "Contacto" = daño a héroes por golpe; "Módulo" = daño a módulos/tick. Todos tienen `base_hp/base_speed/contact_damage/module_damage` = −1 (usan el `VARIANT_CONFIG`) y `damage_vs_heroes` = 0.

| id | Sprite (`resources/sprite_frames/`) | beh | Rol | HP | Contacto | Módulo | Veloc. | Mult. (hp/dmg/vel) | Escala visual | Daño al Nexo |
|---|---|---|---|---|---|---|---|---|---|---|
| `goblin` | `enemy_goblin` | S | **RAIDER** | 6 | 2 | 2 | 500 | 1/1/1 | 1 | 4 |
| `skelet` | `enemy_skelet` | S | HUNTER | 6 | 2 | 2 | 450 | 1/1/0.9 | 1 | — |
| `tiny_zombie` | `enemy_tiny_zombie` | P | HUNTER | 8 | 1 | 3 | 342 | 0.8/1/0.9 | 1 | — |
| `imp` | `enemy_imp` | S | HUNTER | 5 | 2 | 2 | 650 | 0.88/1.04/1.3 | 1 | — |
| `masked_orc` | `enemy_masked_orc` | S | **RAIDER** | 8 | 2 | 2 | 450 | 1.3/1.08/0.9 | 1 | 4 |
| `orc_warrior` | `enemy_orc_warrior` | S | **RAIDER** | 8 | 2 | 2 | 475 | 1.36/1.12/0.95 | 1 | 4 |
| `orc_shaman` | `enemy_orc_shaman` | H | HUNTER | 8 | 4 | 2 | 400 | 1/1.2/1 | 1 | — |
| `chort` | `enemy_chort` | S | HUNTER | 9 | 2 | 2 | 550 | 1.48/1.16/1.1 | 1 | — |
| `wogol` | `enemy_wogol` | H | HUNTER | 10 | 4 | 2 | 400 | 1.3/1.2/1 | 1 | — |
| `necromancer` | `enemy_necromancer` | H | HUNTER | 12 | 4 | 3 | 400 | 1.48/1.4/1 | 1 | — |
| `big_zombie` | `enemy_big_zombie` (32×36) | P | HUNTER | 22 | 1 | 4 | 266 | 2.2/1.2/0.7 | 1 | — |
| `ogre` | `enemy_ogre` (32×36) | P | HUNTER | 25 | 1 | 4 | 285 | 2.5/1.32/0.75 | 1 | — |
| `big_demon` | `enemy_big_demon` (32×36) | H | HUNTER | 18 | 4 | 3 | 360 | 2.2/1.4/0.9 | 1 | — |
| `tc_eyeball` | `tc_eyeball` | H | HUNTER | 8 | 3 | 2 | 400 | 1/1/1 | 1 | — |
| `tc_wolf` | `tc_wolf` | S | HUNTER | 7 | 2 | 2 | 700 | 1.12/1.08/1.4 | 1 | — |
| `tc_fire_skull` | `tc_fire_skull` | P | HUNTER | 10 | 1 | 3 | 380 | 1/1.16/1 | 1 | — |
| `tc_red_imp` | `tc_red_imp` | S | HUNTER | 7 | 2 | 2 | 650 | 1.12/1.2/1.3 | 1 | — |
| `tc_demon` | `tc_demon` | S | HUNTER | 10 | 3 | 3 | 550 | 1.6/1.32/1.1 | 1.2 | — |
| `tc_ogre` | `tc_ogre` | P | HUNTER | 17 | 1 | 4 | 304 | 1.72/1.24/0.8 | 1.2 | — |
| `tc_dragon` | `tc_dragon` | H | HUNTER | 15 | 4 | 3 | 440 | 1.9/1.4/1.1 | 1.3 | — |

Habilidades propias: **ninguno tiene** (no hay ataques a distancia, hechizos, invocaciones ni auras). Lo único especial por `behavior` es el **Sapper** (`tiny_zombie`, `big_zombie`, `ogre`, `tc_fire_skull`, `tc_ogre`), que va primero a las salas con módulos. Los nombres "shaman", "necromancer", "dragon" son solo arte con stats de Hunter.

### Pisos donde aparecen (`resources/floors/enemy_pool_f1..f5.tres`; `*` = RAIDER; peso (% del pool))
| Piso | Pool |
|---|---|
| 1 | goblin* 5 (45 %), skelet 4 (36 %), tiny_zombie 2 (18 %) |
| 2 | goblin* 3 (21 %), skelet 2 (14 %), tiny_zombie 2 (14 %), imp 3 (21 %), masked_orc* 3 (21 %), tc_eyeball 1 (7 %) |
| 3 | skelet 2 (12 %), imp 2 (12 %), masked_orc* 3 (18 %), orc_warrior* 3 (18 %), orc_shaman 2 (12 %), tc_wolf 3 (18 %), tc_fire_skull 2 (12 %) |
| 4 | masked_orc* 3 (17 %), orc_warrior* 3 (17 %), chort 3 (17 %), wogol 1 (6 %), big_zombie 1 (6 %), tc_ogre 1 (6 %), tc_red_imp 3 (17 %), tc_wolf 3 (17 %) |
| 5 | chort 3 (20 %), orc_warrior* 2 (13 %), ogre 2 (13 %), big_demon 1 (7 %), necromancer 1 (7 %), tc_dragon 1 (7 %), tc_demon 3 (20 %), tc_ogre 2 (13 %) |
Los porcentajes son el peso dentro del pool entero; en la práctica primero se sortea el rol (ver arriba) y el peso solo reparte **dentro de ese rol** (p. ej. piso 1: todo raider es `goblin`; piso 5: todo raider es `orc_warrior`). Los 20 tipos aparecen al menos en un piso. Un piso fuera del rango (> 5) reusa el pool 5. Sin pool configurado cae a `goblin` (`EnemyManager.FALLBACK_TYPE`).

---

## 3. El Nexo

**Qué es hoy**: un objeto con **vida** (`Nexo.gd`, `scenes/world/Nexo.tscn`, `Area2D` radio 18, sprite = `Pickup` con `flask_big_blue` de 0x72) colocado en la **sala de inicio**, 56 px sobre su centro (`Main2d.NEXO_OFFSET`, `Main2d.gd:18`). Se crea de nuevo en cada piso con `FloorConfig.nexo_max_hp` (**120** en el `.tres`; el default del script es 100).

| Función | Estado |
|---|---|
| **Condición de derrota** | **Sí.** `Nexo.destroyed` (HP 0) → `Main2d._on_player_died`, la misma derrota que la muerte de un héroe (`Main2d.gd:229`). |
| **Punto de defensa** | **Sí.** Los RAIDER caminan hacia la zona del Nexo y lo golpean desde el inicio del piso (no hace falta haberlo recogido); la alerta HUD `NexoAlert` (borde rojo) y un aro rojo en el minimapa avisan mientras recibe daño. |
| **Objetivo de extracción / victoria** | **Sí.** Recogerlo (`NexoController.confirm_pickup()`) pone `is_carrying_nexo`, inicia `ExtractionManager.start_extraction()` (puertas bloqueadas, oleadas cada 5 s en salas oscuras) y el portador va a ×0.75 de velocidad. Llevarlo a la **sala de salida** (`is_exit_room`) dispara `declare_victory()`. |
| **Fuente de recursos** | **No.** No produce ni modifica Industria/Comida/Ciencia/Polvo. |
| **Relación con módulos y salas** | Indirecta: está en la sala de inicio (encendida gratis por `Main2d`); los RAIDER ignoran los módulos; las torres pueden dañar raiders en su rango; el Tanque lo usa como ancla de su pasiva; `ExitIndicator` se pone dorado mientras se lleva. No depende de la energía de ninguna sala. |

**Stats**: `max_hp` 120 (`FloorConfig.nexo_max_hp`), sin regeneración ni reparación ni escudo. Feedback de daño: parpadeo blanco 0.15 s, número flotante, 3 grietas dibujadas por código al 75 %/50 %/25 % de vida, `under_attack` activo hasta 1.5 s tras el último golpe. Al recogerlo se oculta y su vida se conserva (los enemigos siguen golpeándolo en la posición del portador).

**Quién lo daña**: solo `Nexo.take_damage()`, llamado por `Enemy._perform_attack()` (RAIDER, cada 1 s, `damage_vs_nexo` × multiplicador de daño: goblin/masked_orc/orc_warrior hacen **4** por golpe en piso 1: un solo raider necesita 30 golpes = 30 s sin oposición para romper 120 HP). Nada más lo daña (héroes, módulos y trampas no).
**Quién interactúa**: clic izquierdo (`Nexo.nexo_clicked`) → `NexoController`: exige tener la **sala de salida descubierta** ("Descubrí la salida antes de llevarte el Nexo") y que el héroe principal esté en la sala de inicio ("Acercate al Nexo para recogerlo") → `ConfirmationDialog`. `PlayerStats`/`HeroAbilities` leen su posición (Tanque), `EnemyManager` calcula el tiempo de llegada de raiders, `Minimap`/`HUDController` muestran la alerta.

---

## 4. Tablas resumen

### Héroes
| Héroe | Rol | Vida | Daño | Intervalo | DPS | Radio | Pasiva | Activa (cooldown) | Vida/Daño/Interv. nivel 6 |
|---|---|---|---|---|---|---|---|---|---|
| Guerrero | Tanque y Provocador | 26 | 4 | 1.2 s | 3.33 | 150 | −20 % daño recibido | Grito de Guerra: aliados de la sala ×1.5 daño, 8 s (25 s) | 46 / 9 / 0.90 |
| Mago | Ciencia y Módulos | 18 | 3 | 0.9 s | 3.33 | 220 | +2 Ciencia al descubrir sala | Sobrecarga: torres ×2 8 s + tick extra de generadores (30 s) | 38 / 8 / 0.675 |
| Pícaro | Explorador Rápido | 18 | 2 | 0.5 s | 4.00 | 130 | +2 Polvo al descubrir sala | Golpe Furtivo: ×3 daño a todo en rango (12 s) | 38 / 7 / 0.375 |
| Tanque | Defensor de Cristal | 40 | 3 | 1.3 s | 2.31 | 170 | hasta −50 % daño cerca del Nexo (640 px) | Interposición: todos −50 % daño 6 s (30 s) | 60 / 8 / 0.975 |
Común: velocidad 420 px/s (315 con el Nexo), sin defensa/armadura, sin equipamiento aplicado, cap de vida 60, 5 niveles (8/11/16/22/31 Comida).

### Enemigos (agrupados por familia)
| Familia | Tipos | Rol | HP (piso 1) | Contacto | Veloc. | Pisos |
|---|---|---|---|---|---|---|
| Swarm ligero 0x72 | goblin, skelet, imp, chort | goblin RAIDER, resto HUNTER | 5–9 | 2 | 450–650 | 1–5 |
| Orcos 0x72 | masked_orc, orc_warrior | RAIDER | 8 | 2 | 450–475 | 2–5 |
| Hunter 0x72 | orc_shaman, wogol, necromancer, big_demon | HUNTER | 8–18 | 4 | 360–400 | 3–5 |
| Sapper 0x72 | tiny_zombie, big_zombie, ogre | HUNTER | 8–25 | 1 | 266–342 | 1, 2, 4, 5 |
| Tiny Creatures | tc_wolf, tc_red_imp, tc_demon (Swarm); tc_eyeball, tc_dragon (Hunter); tc_fire_skull, tc_ogre (Sapper) | HUNTER | 7–17 | 1–4 | 304–700 | 2–5 |
(Detalle por tipo en la tabla de §2.)

### Nexo
| HP | Derrota si 0 | Daña | Se recoge | Efecto al recogerlo |
|---|---|---|---|---|
| 120 (por piso) | sí | solo RAIDER, 4/s c/u (piso 1) | sala de inicio, con la salida descubierta | puertas bloqueadas, oleadas cada 5 s, portador ×0.75 de velocidad |

---

## 5. Inconsistencias o datos faltantes

**Héroes**
1. **Dos "vida base" distintas**: `StatBalance.PLAYER_BASE_HP = 20` (`StatBalance.gd:7`) vs `base_hp` por héroe (26/18/18/40). `CharacterStats.reset_modifiers()` fija `max_hp = PLAYER_BASE_HP` (`CharacterStats.gd:43-48`) y enseguida `PlayerStats._apply_base_stats()` lo pisa con el valor del héroe (`PlayerStats.gd:93`); el Mago y el Pícaro (18) quedan por debajo de ese "base" y de `clamp_player_hp` (mínimo 20). Además `PlayerStats.base_hp` (cuenta, = héroe por defecto) se "clampa" a sí mismo (`PlayerStats.gd:20, 81-82`) y no se usa para nada más.
2. **Tope de 60 de vida**: `apply_hp_delta` limita a `PLAYER_MAX_HP` (`StatBalance.gd:20`); el Tanque llega justo a 60 con 5 niveles. Cualquier bono extra de vida (los ítems `hp` si algún día se aplican) quedaría recortado sin aviso.
3. **"Provocador" sin provocación**: el Guerrero se describe como "Tanque y Provocador / Atrae el peligro" pero no existe mecánica de provocar (los enemigos eligen por distancia: `Enemy._aggro_hero`, `Enemy.gd:356`; solo hay `_provoked_until_msec` de los raiders hacia quien los golpea).
4. **"Explorador Rápido" sin velocidad**: el Pícaro no se mueve más rápido; no hay stat de velocidad por héroe (`MoveAction.DEFAULT_SPEED_PX` es global).
5. **Texto vs mecánica**: "Piel de Hierro … mientras protege la sala actual" (`warrior.tres`) pero la pasiva es −20 % plano siempre (`HeroAbilities.passive_reduction`). "Interposición" del Tanque es un escudo de grupo, no una interposición posicional.
6. **Valores del `.tres` que pisan los defaults del script**: `attack_speed_per_level` 0.05 y `min_attack_interval` 0.3 (script: 0.1 y 0.2; el comentario de `UpgradeConfig.gd:28` habla de 10 %). `Player.tscn` trae `Hitbox damage = 3` y radio 160, que `Player._ready()` sobrescribe con los de `CharacterData`.
7. `CharacterData.profile_bg` (`CharacterData.gd:13`) **no lo lee nadie**. Hay `passive_ability_desc` pero **no `active_ability_desc`**: `HeroSelectMenu` (`HeroSelectMenu.gd:307`) y `CharacterPopup` solo muestran el *nombre* de la activa.
8. Los cooldowns de habilidades no tienen ícono (29 `placeholder_*`, 8 son `ability_*`; `docs/MISSING_ICONS.md`), ni hay barra visible en el retrato según ese documento.
9. **Sin sistema de equipo**: 18 `ItemData` con modificadores (hp, daño, intervalo) que ningún código aplica; `ItemData.Slot.RELIC` y `Rarity` sin consumidor más allá de mostrar texto/color.
10. El héroe `description`/`role` está solo en español en los `.tres` (sin i18n).

**Enemigos**
11. **Stats base hardcodeados** en `Enemy.VARIANT_CONFIG` (`Enemy.gd:13-17`, incluido `ai_interval`); los campos `EnemyType.base_hp/base_speed/contact_damage/module_damage` existen pero **los 20 `.tres` los dejan en −1**, y `damage_vs_heroes` está en 0 en todos. `current_speed()` y `configure()` repiten la lógica de `resolved_*`.
12. **Nomenclatura doble**: `Enemy.Variant.HUNTER` (behavior, base stats) vs `EnemyType.Role.HUNTER` (rol/destino). Un `tc_dragon` es "behavior Hunter, rol HUNTER", un `goblin` "behavior Swarm, rol RAIDER"; confunde al leer. `docs/ENEMY_TARGETING.md` tiene arriba el comportamiento previo a `enemies-2` (marcado como histórico).
13. **Enemigos sin habilidades ni ataque a distancia**: `orc_shaman`, `necromancer`, `tc_dragon`, `tc_demon`, `big_demon` solo cambian arte y números respecto del Hunter base.
14. **Sin recompensas por matar** (no hay drops ni recursos), **sin animaciones** de ataque, daño y muerte (ver `ASSETS_AUDITORIA.md` §5); los TC no tienen animación de caminar.
15. `EnemyType.attack_range` (40 por defecto, 56 raiders) es el mismo campo para "alcance al héroe" y "alcance al Nexo"; el daño a héroes es solo por el `Hitbox` de contacto de radio fijo (`Enemy.tscn`, 24 + 10 de `CONTACT_REACH`), así que `attack_range` no afecta el daño a héroes.
16. `EnemyManager` tiene el motor de riesgo **hardcodeado** (`BASE_CHANCE`, `CHANCE_PER_DARK_ROOM`, `CHANCE_PER_TURN`, `MAX_CHANCE`, `TURNS_PER_WAVE_STEP`, `EnemyManager.gd:11-15`) y `ExtractionManager.SPAWN_INTERVAL = 5.0` duplica `FloorConfig.extraction_spawn_interval` (usado solo como valor por defecto de `setup`).
17. `default_floor_config.tres:52` escribe `raider_ratio_by_floor = null`: al cargar, Godot ignora el `null` y queda el default del script (5/20/35/50/60 %), verificado con `FloorConfig.raider_ratio()`; es frágil (si el default cambia, cambia el juego sin tocar el `.tres`). Otros pisos de escala distintos al default del script: `enemy_hp_growth` 0.15 (script 0.25), `enemy_damage_growth` 0.10 (0.2), `extra_invasion_enemies_per_floor` 0.34 (0.5), `nexo_max_hp` 120 (100).
18. `CLAUDE.md` describe "HUNTER solo se mueve cuando se lleva el Nexo" en la sección Enemies (texto previo a `enemies-2`); el código actual ya no lo hace.

**Nexo**
19. `Nexo.max_hp` default 100 (`Nexo.gd:28`) vs 120 configurado (`FloorConfig`): el real es el del `.tres` (lo asigna `Main2d._spawn_nexo`, `Main2d.gd:227`).
20. **Sin reparación ni regeneración**, y ni héroes ni módulos pueden defenderlo activamente salvo matando raiders; no hay resistencia/escudo propios. La vida se reinicia en cada piso (se crea un Nexo nuevo).
21. El sprite del Nexo es el frasco azul de 0x72 (`placeholder_nexo.png` pendiente en `MISSING_ICONS.md`).
22. `NexoController.get_block_reason()` evalúa al héroe *principal* (`ManagerLocator.get_player()`), no a cualquier héroe de la selección ni al que está más cerca.

**Datos faltantes**
- Ningún stat de defensa/armadura, velocidad por héroe, crítico, evasión ni resistencias en héroes o enemigos.
- No hay datos de **jefes**; `visual_scale` 1.2–1.3 de los TC grandes es el único indicio.
- No hay tabla de rarezas/probabilidades de ítems más allá del sorteo de cofres (`Main2d._roll_chest_item`).
