# Assets gráficos

Todo el arte es 16×16 px por tile: CC0 (0x72, Kenney, Tiny Creatures) o propio; licencias en `docs/CREDITOS.md`, verificadas por `tests/test_licencias.gd`. Originales intactos en `assets/art/_source/`; copias por categoría en `assets/art/{tiles,characters,enemies,items,ui}/` (las que usa el juego). Tras copiar, mantener PNG en Nearest / lossless / sin mipmaps (default del proyecto).

## Escala y celda lógica
- `ArtConfig` (`scripts/core/art/ArtConfig.gd`): `TILE_SIZE = 16`, `ART_SCALE = 2`, `CELL_TILES = 2`, `CELL_PX = 64`.
- **1 celda lógica de `MapLayout`/`MapGenerator` = 2×2 tiles de arte (16 px) dibujados ×2 = 64 px de mundo**. Coincide con `tile_size` de `resources/tilesets/placeholder_tileset.tres` (rejilla lógica oculta) y `RoomManager.DEFAULT_TILE_SIZE` (64). Sala máx 5×5 celdas = 10×10 tiles = 320 px de mundo; `MapGenerator.SLOT_PITCH` = 9 celdas.
- Muro de 1 celda = 2 tiles (tapa + cara de 0x72); puerta `doors_leaf_*` (32×32) = 1 celda (`Sprite2D` hijo de `Door`, no tile); pasillo (1 celda) = 2 tiles de ancho.
- Sprites: dibujar con `scale = Vector2(ART_SCALE, ART_SCALE)`; colisiones/radios en px de mundo (arte × 2). Héroe 16×28 → 32×56 px.
- `tests/test_art_config.gd` falla si `CELL_PX`, el `tile_size` del tileset lógico y `DEFAULT_TILE_SIZE` divergen.

## Inventario por pack

### 0x72 DungeonTileset II v1.7 — `_source/0x72_DungeonTilesetII_v1.7/`
- Hoja completa 512×512 + `tile_list_v1.7` (nombre x y w h de cada frame) + 370 PNG sueltos en `frames/`.
- Atlas autotile: `atlas_floor-16x16` (112×112), `atlas_walls_low-16x16` (192×64), `atlas_walls_high-16x32` (384×128; y-offset 8 la mayoría).
- Animaciones (4 frames `_f0.._f3`): `*_idle_anim` y `*_run_anim`; `*_hit_anim` = 1 frame, solo héroes.
  - Héroes 16×28: knight_m/f, elf_m/f, dwarf_m/f, lizard_m/f, wizzard_m/f (idle 4, run 4, hit 1). Otros: angel, doc (16×16/…, idle/run).
  - Enemigos pequeños 16×16 (idle+run): goblin, imp, skelet, chort, masked_orc, orc_warrior, orc_shaman(idle/run), wogol, tiny_zombie, tiny_slug, pumpkin_dude (16×23), necromancer (16×23, 1 anim), zombie/ice_zombie/muddy/swampy/slug (1 anim de 4 frames).
  - Enemigos grandes 32×36: big_zombie, big_demon, ogre (idle+run).
- Ítems/props: chest_empty/full/mimic_open (3 frames), coin (4, 6×7), flask_* ×8 (16×16), bomb (3), crate, skull, 27 `weapon_*`, floor_spikes (4), lever_left/right, column (16×48), column_wall, hole, button_red/blue up/down, doors_* (frame left/right/top, leaf closed/open, 32×32), wall_banner ×4, wall_fountain (top/mid/basin, 3 frames), wall_goo, wall_hole, wall_edge_* / wall_outer_* / wall_top_* (piezas de muro), floor_1..8, floor_stairs, floor_ladder, ui_heart_full/half/empty.

### Kenney Tiny Dungeon — `_source/kenney_tinyDungeon/`
- `Tilemap/tilemap_packed.png` 192×176 = 12×11 = 132 tiles 16×16 (sin separación); `tilemap.png` con 1 px de separación; 132 PNG sueltos `Tiles/tile_0000..0131`; `Tiled/` (tmx/tsx), `Tilesheet.txt`, `Sample.png`.
- Contenido: suelos, muros, puertas, cofres, barriles/props, héroes (y algunos monstruos), armas, pociones.

### Tiny Creatures (Clint Bellanger) — `_source/tiny-creatures/`
- `Tilemap/tilemap_packed.png` 160×288 = 10×18 = 180 tiles 16×16; `tilemap.png` (1 px separación); `Kenney_tiny_dungeon.png` (hoja de referencia); 180 PNG en `Tiles/`; `Examples/`, `Tiled/`.
- Contenido: monstruos fantásticos (goblins, esqueletos, slimes, dragones, demonios, no-muertos) y animales; fuente extra de enemigos/jefes. **Todos miran a la derecha** (usar `flip_h` para izquierda). Sin animación (1 frame por criatura).

## Qué asset para qué (session/assets-3)
Recursos: `resources/sprite_frames/*.tres` (SpriteFrames), `resources/enemies/*.tres` (`EnemyType`), `resources/floors/enemy_pool_f1..f5.tres` (`EnemyPool`, enlazados en `default_floor_config.tres`). Se regeneran con `tools/build_characters.gd`; después se pueden ajustar a mano. Los sprites miran a la derecha (`CharacterVisual` hace `flip_h`).

| Uso | Asset |
|---|---|
| Guerrero / Mago / Pícaro / Paladín | 0x72 `knight_m` / `wizzard_m` / `elf_m` / `dwarf_m` (idle 4, run 4, hit 1; 16×28) |
| Retrato HUD y popup | frame idle del héroe (Nearest, ×2); `portrait` PNG solo en selección de héroe |
| Piso 1 | 0x72 goblin, skelet, tiny_zombie |
| Piso 2 | goblin, skelet, tiny_zombie, imp, masked_orc + Tiny Creatures ojo flotante |
| Piso 3 | skelet, imp, masked_orc, orc_warrior, orc_shaman + TC lobo, calavera ígnea |
| Piso 4 | masked_orc, orc_warrior, chort, wogol, big_zombie (32×36) + TC ogro verde, demonio rojo, lobo |
| Piso 5 | chort, orc_warrior, ogre, big_demon (32×36), necromancer + TC dragón, demonio mayor, ogro |
| Comportamiento | cada `EnemyType.behavior` = Swarm/Sapper/Hunter; stats = variante × piso × multiplicadores del tipo |
| Reliquia | gema roja propia, celda 9 de `own/items.png` vía `Pickup.RELIC_REGION` |
| Brasas / Arma | 0x72 `coin` / `weapon_regular_sword` (`Pickup`, aún sin cablear) |
| Cofre (sala Botín) | Kenney `(5,7)` vía `Pickup`, aparece al descubrir la sala |
| Suelo / muros / puertas / escalera | ver etapa 2 (`docs/MAP_RENDER.md`) |
| HUD vida | `ui_heart_*` (pendiente) |

## Packs retirados por licencia (licencias-20)
`assets-4` sumó tres packs que ya no usa el juego ni versiona el repo (público). Copias solo locales, gitignoreadas: `_source/items_sheets/` (hojas de ítems y `pixelquest16` cave, autor/licencia desconocidos), `_source/super_pixel_effects/` (unTied Games: prohíbe distribuir el pack fuera de un juego), `_source/raven_fantasy_icons/` (licencia desconocida, nunca usado) y las copias normalizadas en `_rejected/licencia/` (`armor/`, `weapons/`, `items/{chests,consumables,potions,books,cave_gems}.png`, `vfx/` con los 42 FX). El historial de git anterior a `licencias-20` todavía los contiene (ver `docs/CREDITOS.md`).

## Arte propio — `assets/art/own/` (licencias-20)
Generado por `tools/build_own_art.gd` (headless, determinista):
| Archivo | Contenido |
|---|---|
| `own/items.png` | fila de celdas 16×16, orden `OWN_CELLS`: 7 armaduras (escudos Kenney `tile_0101`/`0102` re-coloreados por material), grimorios de brasas y mareas, gema de la Reliquia (celda 9), espadas de jade y oro (Kenney `0105`/`0106` re-coloreadas) |
| `own/vfx/*.png` + `index.json` | 8 tiras horizontales a 15 FPS: `own_slash` (32 px, 6 frames, blanco teñido por código), `own_sparks_yellow`, `own_smoke_brown`, `own_sparkle_green` (32 px), `own_ring_{red,blue,violet,green}` (40 px, 8 frames) |
| `own/src/*.ase`, `own/src/vfx/*.ase` | fuentes editables en LibreSprite (ver abajo) |

**Retoque a mano con LibreSprite** (`E:\LibreSprite`, GPL: la herramienta no afecta la licencia del arte): `tools/libresprite.sh import` crea los `.ase` (no pisa los existentes; cada FX entra como animación de un frame por cuadro), se retocan en LibreSprite, `tools/libresprite.sh export` escribe los PNG del juego y actualiza `index.json` (frames y tamaño). Con un `.ase` presente, `build_own_art.gd` ya no regenera ese PNG: para volver a la versión por fórmula, borrar el `.ase`. Ida y vuelta verificada exacta al píxel. `items.png` no cambia de ancho sin tocar `OWN_CELLS`, `build_items.gd` y `Pickup.RELIC_REGION`.

## Tamaños
- Ítems e íconos: celdas 16×16, dibujadas a `ArtConfig.ART_SCALE`. FX: frames de 32–40 px, misma densidad de píxel (×2).
- `tests/test_assets_art.gd`: hojas en celdas de 16 px, cada hoja de `vfx_config.tres` presente en `own/vfx/index.json`, frames dentro de la hoja, `.import` lossless sin mipmaps.
- `tools/normalize_assets.gd` ahora solo genera los `placeholder_*` de `assets/art/ui/`.

## Ítems (session/assets-4)
`ItemData` (`scripts/core/items/`) + 18 `.tres` en `resources/items/` (6 espadas, 7 armaduras, 3 pociones, 2 grimorios) y `item_catalog.tres`; se regeneran con `tools/build_items.gd` (tabla id → hoja/celda; desde `licencias-20` las hojas son Kenney `tilemap_packed.png` y `own/items.png`: espadas y pociones Kenney, espadas de jade/oro, armaduras y grimorios propios) y se pueden editar a mano. Modificadores solo con stats existentes: `hp` (vida máx.), `attack_damage`, `attack_interval` (delta en s).
- **Sin sistema de equipo**: los ítems no se aplican a los héroes. Se muestran: `Pickup.item` (ícono; en un cofre flota encima), cofre de sala Botín (`Main2d._roll_chest_item`, sorteo por rareza sembrado por piso+sala), y sección "Hallazgos" de solo lectura en `CharacterPopup` (`PlayerStats.found_items`, se vacía al empezar partida). Equipar/aplicar modificadores queda para una sesión de diseño aparte.
- Test: `tests/test_items.gd`.

## VFX en juego (balance-4, arte desde licencias-20)
Escenas en `scenes/vfx/*.tscn` (slash_arc, projectile_trail, impact_sparks, heal_glow, buff_aura, death_dust, damage_flash) usadas por `VfxManager` (`resources/vfx/vfx_config.tres`). Hojas de `assets/art/own/vfx` por uso: tajo `own_slash`, chispas `own_sparks_yellow`, curación `own_sparkle_green`, ataque+ `own_ring_red`, escudo `own_ring_blue`, obras `own_ring_violet`, nivel `own_ring_green`, polvo de muerte `own_smoke_brown`. Partículas: cuadrados de 1-2 px de arte, Nearest, color = `CharacterData.vfx_color`.
