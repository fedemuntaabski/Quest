# Assets gráficos

Todo el arte es 16×16 px por tile, licencia CC0 (ver `CREDITS.md`). Originales intactos en `assets/art/_source/`; copias por categoría en `assets/art/{tiles,characters,enemies,items,ui}/` (las que usa el juego). Tras copiar, mantener PNG en Nearest / lossless / sin mipmaps (default del proyecto).

## Escala y celda lógica
- `ArtConfig` (`scripts/core/art/ArtConfig.gd`): `TILE_SIZE = 16`, `ART_SCALE = 4`, `CELL_PX = 64`.
- **1 celda lógica de `MapLayout`/`MapGenerator` = 1 tile de arte (16 px) dibujado ×4 = 64 px**. Ya coincide con `tile_size` de `resources/tileset/placeholder_tileset.tres` y `RoomManager.DEFAULT_TILE_SIZE` (64). Sala máx 5×5 celdas = 80×80 px de arte = 320 px de mundo; `MapGenerator.SLOT_PITCH` = 9 celdas.
- Sprites: dibujar con `scale = Vector2(ART_SCALE, ART_SCALE)`; colisiones/radios en px de mundo (arte × 4). Héroe 16×28 → 64×112 px.
- Cambiar `ART_SCALE` obliga a cambiar `tile_size` del tileset y `DEFAULT_TILE_SIZE`; `tests/test_art_config.gd` falla si divergen.

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
- Contenido: suelos, muros, puertas, escaleras, cofres, antorchas, props de mazmorra, héroes/enemigos chibi, armas, pociones.

### Tiny Creatures (Clint Bellanger) — `_source/tiny-creatures/`
- `Tilemap/tilemap_packed.png` 160×288 = 10×18 = 180 tiles 16×16; `tilemap.png` (1 px separación); `Kenney_tiny_dungeon.png` (hoja de referencia); 180 PNG en `Tiles/`; `Examples/`, `Tiled/`.
- Contenido: criaturas y animales, **todos miran a la derecha** (usar `flip_h` para izquierda). Sin animación (1 frame por criatura).

## Qué asset para qué (propuesta para etapas siguientes)
| Uso | Asset |
|---|---|
| Héroes (guerrero/mago/pícaro/tanque) | 0x72 `knight_m` / `wizzard_m` / `elf_m` (pícaro) / `dwarf_m` (tanque): idle+run+hit |
| Compañeros | variantes `_f` (knight_f, elf_f, dwarf_f, wizzard_f) |
| Enemigos piso 1 | goblin, skelet, tiny_zombie, tiny_slug (Swarm) |
| Enemigos piso 2 | imp, chort, masked_orc, wogol |
| Enemigos piso 3 | orc_warrior, orc_shaman, zombie/ice_zombie, swampy/muddy |
| Enemigos piso 4-5 / élite | ogre, big_zombie, big_demon, necromancer (Hunter/élite); Sapper → `pumpkin_dude` o `bomb` |
| Suelo | `atlas_floor-16x16` / `floor_1..8` (Kenney packed como alternativa) |
| Paredes | `atlas_walls_low-16x16` (+ `walls_high` para profundidad), `wall_*` |
| Puertas | `doors_frame_*` + `doors_leaf_closed/open` (32×32 en corredor) |
| Salida | `floor_stairs` (ladder alternativa `floor_ladder`) |
| Cristal / El Nexo | `flask_big_blue` (o tile de gema Kenney) |
| Polvo | `coin` (4 frames) |
| Cofres (sala LOOT) | `chest_full_open` (3 frames) / `chest_mimic_open` (trampa) |
| Torretas / trampas | ballesta = `weapon_bow`; trampa = `floor_spikes` |
| HUD vida | `ui_heart_*` |
