# Assets gráficos

Todo el arte es 16×16 px por tile, licencia CC0 (ver `CREDITS.md`). Originales intactos en `assets/art/_source/`; copias por categoría en `assets/art/{tiles,characters,enemies,items,ui}/` (las que usa el juego). Tras copiar, mantener PNG en Nearest / lossless / sin mipmaps (default del proyecto).

## Escala y celda lógica
- `ArtConfig` (`scripts/core/art/ArtConfig.gd`): `TILE_SIZE = 16`, `ART_SCALE = 2`, `CELL_TILES = 2`, `CELL_PX = 64`.
- **1 celda lógica de `MapLayout`/`MapGenerator` = 2×2 tiles de arte (16 px) dibujados ×2 = 64 px de mundo**. Coincide con `tile_size` de `resources/tileset/placeholder_tileset.tres` (rejilla lógica oculta) y `RoomManager.DEFAULT_TILE_SIZE` (64). Sala máx 5×5 celdas = 10×10 tiles = 320 px de mundo; `MapGenerator.SLOT_PITCH` = 9 celdas.
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
| Guerrero / Mago / Pícaro / Tanque | 0x72 `knight_m` / `wizzard_m` / `elf_m` / `dwarf_m` (idle 4, run 4, hit 1; 16×28) |
| Retrato HUD y popup | frame idle del héroe (Nearest, ×2); `portrait` PNG solo en selección de héroe |
| Piso 1 | 0x72 goblin, skelet, tiny_zombie |
| Piso 2 | goblin, skelet, tiny_zombie, imp, masked_orc + Tiny Creatures ojo flotante |
| Piso 3 | skelet, imp, masked_orc, orc_warrior, orc_shaman + TC lobo, calavera ígnea |
| Piso 4 | masked_orc, orc_warrior, chort, wogol, big_zombie (32×36) + TC ogro verde, demonio rojo, lobo |
| Piso 5 | chort, orc_warrior, ogre, big_demon (32×36), necromancer + TC dragón, demonio mayor, ogro |
| Comportamiento | cada `EnemyType.behavior` = Swarm/Sapper/Hunter; stats = variante × piso × multiplicadores del tipo |
| Cristal (Nexo) | 0x72 `flask_big_blue` vía `Pickup` |
| Polvo / Arma | 0x72 `coin` / `weapon_regular_sword` (`Pickup`, aún sin cablear) |
| Cofre (sala Botín) | Kenney `(5,7)` vía `Pickup`, aparece al descubrir la sala |
| Suelo / muros / puertas / escalera | ver etapa 2 (`docs/MAP_RENDER.md`) |
| HUD vida | `ui_heart_*` (pendiente) |

## Packs nuevos (session/assets-4)
Originales intactos en `assets/art/_source/` (los `.import` no se versionan, ver `.gitignore`). **Raven y el pack FX crudo no se suben al repo** (ver Licencias).

### Hojas de ítems sueltas — `_source/items_sheets/` ⚠ autor/licencia DESCONOCIDOS
Sin readme/licencia. Todas en celdas 16×16 sin separación. `all-assets-preview.png` = vista previa de todo el set.
| Hoja | Tamaño | Celdas | Contenido |
|---|---|---|---|
| `armours.png` | 144×304 | 9×19 | cascos/armaduras por material (cuero, tela, hierro, acero, cobre, oro, verde…) |
| `weapons.png` | 128×144 | 8×9 | espadas, hachas, mazas, lanzas, arcos |
| `chests.png` | 128×96 | 8×6 | cofres (madera, hierro, oro; cerrado/abierto) |
| `consumables.png` | 704×272 | 44×17 | frascos, bolsas, barriles, comida, jarras (muy variados) |
| `potions.png` | 336×240 | 21×15 | pociones por color y forma |
| `books.png` | 224×192 | 14×12 | libros/grimorios por color |
| `pixelquest16-july-2025-cave.png` | 99×64 (→96×64) | 6×4 | gemas, pico, mineral, herramientas; 3 px sobrantes a la derecha (se recortan) |

### Raven Fantasy Icons (free) — `_source/raven_fantasy_icons/` ⚠ licencia DESCONOCIDA (sin archivo)
- `Full Spritesheet/16x16.png` 256×2192 (16×137 = 2192 íconos), `32x32.png` 512×4384 (mismos íconos ×2), `RPG Maker MV and MZ/IconSet.png`, `Separated Files/{16x16,32x32}/faN.png` (2192 c/u).
- Contenido: íconos RPG de ítems, habilidades, estados, recursos. Fuente para íconos de HUD/habilidades (ver `docs/MISSING_ICONS.md`). Se usa solo la copia 16×16.

### Super Pixel Effects Gigapack (free) v2.9.0 — `_source/super_pixel_effects/` — unTied Games / Will Tice
- Licencia propia (`license.txt`): comercial OK, **atribución obligatoria**, prohibido redistribuir el pack, prohibido usarlo para entrenar IA, 15 FPS por animación.
- Cada animación existe en variante `large_*` y `small_*` por color; frames **no son 16 px**: small = 16–64 px, large = 32–128 px (múltiplos de 8). Hojas en `spritesheet/`, frames sueltos en `PNG/`.
| Categoría | Animaciones | Frame small | Veredicto |
|---|---|---|---|
| Fantasy Spells (absorb, attack/defense up, death, haste, heal, poison, status) | 9 | 32–64 | conservar |
| Magic Bursts | 11 | 32–48 | conservar |
| Impacts (directional/symmetrical) | 9 | 32–48 | conservar salvo `toon` |
| Lightning | 4 | 32–64 | conservar |
| Smoke Bursts | 3 | 32 | conservar |
| Symbols (iconos de estado: alert, level_up, crown…) | 38 | 32–40 | conservar solo símbolos sin texto |
| Explosions | 8 | 32–48 | conservar `epic`/`symmetrical`; `stylized` rechazado |
| Splatters | 4 | 24–48 | rechazado (caricaturesco) |
| Sci-fi | 10 | 16–48 | rechazado (no medieval) |

## Licencias a verificar para Steam
| Pack | Estado | Acción |
|---|---|---|
| items_sheets (armours, weapons, chests, consumables, potions, books, cave) | ⚠ autor y licencia desconocidos | identificar origen y licencia **antes de publicar**; si no hay permiso comercial, reemplazar |
| Raven Fantasy Icons | ⚠ sin archivo de licencia | confirmar en la página del autor (uso comercial/atribución) |
| Super Pixel Effects | atribución obligatoria | acreditar en créditos del juego: "Super Pixel Effects Gigapack - Will Tice / unTied Games"; no subir el pack crudo a repos públicos |
| 0x72 / Kenney / Tiny Creatures | CC0 | sin obligación |

## Filtro de estética (session/assets-4)
Criterio: medieval fantástico oscuro. Rechazados → `assets/art/_rejected/` (lista y motivos en `assets/art/_rejected/README.md`):
- FX: todo `Sci-fi`, todo `Splatters`, `stylized_explosion_*`, Magic Bursts festivos (bubble/music/firework/heart) y Symbols de UI arcade (texto, ranking, pulgares…). Conservados: 42 animaciones (Fantasy Spells 9, Impacts 9, Lightning 4, Magic Bursts 5, Smoke 3, Explosions 5, Symbols 7).
- Raven Fantasy Icons: la hoja usa colores saturados y contorno grueso (más "cartoon" que 0x72/Kenney). No se importa en bloque; solo íconos concretos elegidos a mano si el juego los necesita.
- Hojas de ítems (armours, weapons, chests, consumables, potions, books, cave): conservadas (paleta apagada, medieval).

## Tamaños finales (session/assets-4)
Reproducible: `godot --headless --path . --script res://tools/normalize_assets.gd` (copia de `_source` → carpeta final; idempotente). Ningún pack nuevo se reescaló: ítems/íconos ya vienen en celdas 16×16 (factor 1). El escalado en pantalla siempre es `ArtConfig.ART_SCALE`.

| Destino | Contenido | Tamaño en disco | Celda / frame | En pantalla (×2) |
|---|---|---|---|---|
| `art/armor/armours.png` | armaduras/cascos | 144×304 | 16×16 (9×19) | 32×32 |
| `art/weapons/weapons.png` | armas | 128×144 | 16×16 (8×9) | 32×32 |
| `art/items/{chests,consumables,potions,books}.png` | cofres, consumibles, pociones, libros | ver inventario | 16×16 | 32×32 |
| `art/items/cave_gems.png` | gemas/herramientas (recortada de 99×64) | 96×64 | 16×16 (6×4) | 32×32 |
| `art/vfx/*.png` + `index.json` | 42 FX `small`, tira horizontal, 15 FPS | frames 25–96 px (ver `index.json`) | variable (excepción) | ×2 = 1 px FX = 1 px arte |
| personajes (existentes) | 0x72 héroes | — | 16×28 | 32×56 |
| enemigos (existentes) | pequeños 16×16 / 16×23; grandes 32×36 | — | — | ×2 |
| íconos UI | 16×16 | — | 16×16 | 32×32 |

- **Excepción FX**: las 96 hojas `small` se probaron contra reducción ×½ por Nearest y **ninguna** es exacta (0/96), así que no se pueden bajar a 16 px sin perder calidad. No son personajes/ítems/íconos: se mantienen nativas y se dibujan a `ART_SCALE` (misma densidad de píxel que el resto). Las `large` no se usan.
- Héroe 16×28 y jefes 32×36 son de 0x72 (ya integrados antes); no cambian, así que colisiones/hitboxes/hurtboxes existentes siguen vigentes.
- Los `.import` no se versionan (`.gitignore`); el proyecto ya fuerza `default_texture_filter=0` (Nearest) y el importador 2D por defecto es lossless sin mipmaps. `tests/test_assets_art.gd` lo verifica.
- `art/vfx/index.json`: por FX `frame_w/frame_h`, `frames` (nº real), `columns` (frames por fila de la hoja; casi todas son tira de 1 fila) y `fps` 15.

## Ítems (session/assets-4)
`ItemData` (`scripts/core/items/`) + 18 `.tres` en `resources/items/` (6 espadas, 7 armaduras, 3 pociones, 2 grimorios) y `item_catalog.tres`; se regeneran con `tools/build_items.gd` (tabla id → hoja/celda) y se pueden editar a mano. Modificadores solo con stats existentes: `hp` (vida máx.), `attack_damage`, `attack_interval` (delta en s).
- **Sin sistema de equipo**: los ítems no se aplican a los héroes. Se muestran: `Pickup.item` (ícono; en un cofre flota encima), cofre de sala Botín (`Main2d._roll_chest_item`, sorteo por rareza sembrado por piso+sala), y sección "Hallazgos" de solo lectura en `CharacterPopup` (`PlayerStats.found_items`, se vacía al empezar partida). Equipar/aplicar modificadores queda para una sesión de diseño aparte.
- Test: `tests/test_items.gd`.

## VFX en juego (balance-4)
Escenas en `assets/vfx/*.tscn` (slash_arc, projectile_trail, impact_sparks, heal_glow, buff_aura, death_dust, damage_flash) usadas por `VfxManager` (`resources/vfx/vfx_config.tres`). Hojas de `assets/art/vfx` por uso: tajo `directional_impact_002_white`, chispas `symmetrical_impact_001_yellow`, curación `round_sparkle_burst_002_green`, ataque+ `spell_attack_up_001_red`, escudo `spell_defense_up_001_blue`, módulos `symbol_magic_up_001_violet`, nivel `spell_haste_001_green`, polvo `symmetrical_smoke_burst_001_brown`. Partículas: cuadrados de 1-2 px de arte, Nearest, color = `CharacterData.vfx_color`.
