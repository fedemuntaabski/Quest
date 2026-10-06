# Assets: inventario, reemplazos y pendientes de arte

Sesión `multijugador-11`. Base: `docs/ASSETS.md`, `docs/ASSETS_AUDITORIA.md`, `docs/MISSING_ICONS.md`, licencias en `docs/CREDITOS.md`. No se borró nada.

## 1. Inventario de packs

El "% en uso" es una estimación: archivos o tiles que alguna `.tres`, `.tscn` o `.gd` referencia, sobre el total del pack.

| Pack | Archivos | Contenido | En uso | Notas |
|---|---|---|---|---|
| `_source/0x72_DungeonTilesetII_v1.7` | 377 (370 frames) | héroes, enemigos, tiles, props, 27 armas, 8 frascos | ~45 % | la hoja alimenta `dungeon_tileset.tres` (19 tiles + relleno); 4 héroes, 13 enemigos y 9 ítems. Ahora también 10 íconos (ver §3) |
| `_source/kenney_tinyDungeon` | 142 (132 tiles) | muros, props, cofres, personajes, armas, pociones | ~14 % | `build_tilesets.gd` hornea los 132, pero solo ~19 se referencian (props, cofres y `decor_props`) |
| `_source/tiny-creatures` | 193 (180 tiles) | monstruos de un frame | ~4 % | 7 `tc_*` |
| `_source/items_sheets` | 8 hojas | armaduras 171 celdas, armas 72, pociones 315, libros 168, cofres 48, consumibles 748, cueva 24 | <5 % | 18 ítems. `chests.png`, `consumables.png` y `cave_gems.png` solo se usan en tests |
| `_source/super_pixel_effects` | 5932 | efectos | 42 curados en `art/vfx`, 8 en uso | crudo gitignoreado (licencia) |
| `_source/raven_fantasy_icons` | 4387 | 2192 íconos | 0 % | licencia desconocida: **no usar** hasta verificarla |
| `art/characters` | 107 | | 37 | sin usar: angel, doc, variantes `*_f` y lizard |
| `art/enemies` | 132 | | 13 tipos | sin usar: ice_zombie, muddy, pumpkin_dude, slug, swampy, tiny_slug, zombie |
| `art/items` | 58 | | 10 → 19 | |
| `art/tiles` | 76 | | ~2 → 4 | el resto sale de la hoja completa |
| `art/ui` | 38 | | 15 de 31 placeholders; 1 de 4 botones; 0 de 3 `ui_heart_*` | |
| `assets/portraits`, `assets/fonts`, `assets/audio` | 4 / 2 / 2 | | 100 % | autor/licencia ⚠ de retratos y audio |
| `assets/ui` | 6 | | 4 | sin usar: `background.png`, `256x256 textures (113).png` |

## 2. Faltantes y placeholders, cruzados con assets sin usar

Kenney: `Tiles/tile_NNNN.png`, donde (x, y) = (N % 12, N / 12).

| Uso en el juego | Hoy | Candidato (origen → uso) | Estado |
|---|---|---|---|
| Módulo Forja | `placeholder_gen_industry` | `art/items/weapon_hammer.png` | **aplicado** |
| Módulo Scriptorium | `placeholder_gen_science` | `art/items/flask_big_green.png` | **aplicado** |
| Módulo Ballesta | `placeholder_turret` | `art/items/weapon_bow_2.png` | **aplicado** |
| Módulo Catapulta | `placeholder_catapult` | `art/items/bomb_f0.png` | **aplicado** |
| Módulo Pinchos | `placeholder_spikes` | `art/tiles/floor_spikes_anim_f3.png` | **aplicado** |
| Módulo Brasero | `placeholder_trap` | `art/tiles/wall_fountain_basin_red_anim_f0.png` | **aplicado** (provisorio: es una fuente, no un brasero) |
| Módulo Granja | `placeholder_gen_food` | celda de comida/barril en `items_sheets/consumables.png` | pendiente (necesita `AtlasTexture`; licencia ⚠) |
| Habilidad activa Guerrero | `placeholder_ability_warrior_active` | `art/items/weapon_knight_sword.png` | **aplicado** |
| Habilidad activa Maga | `placeholder_ability_mage_active` | `art/items/weapon_red_magic_staff.png` | **aplicado** |
| Habilidad activa Pícaro | `placeholder_ability_rogue_active` | `art/items/weapon_knife.png` | **aplicado** |
| Habilidad activa Tanque | `placeholder_ability_tank_active` | `art/items/weapon_big_hammer.png` | **aplicado** |
| Pasivas (4 héroes) | `placeholder_ability_*_passive` | celdas de `armours.png` / `books.png`; escudo Kenney `tile_0102` (tanque) | pendiente (`AtlasTexture`) |
| Cofres por tier | Kenney (5,7) teñido (`Chest.gd`) | `items_sheets/chests.png` (madera/hierro/oro, cerrado y abierto) | pendiente: cambiar `Chest.gd` y verificar en ventana |
| Jaula del prisionero | líneas en código (`PrisonerCage.gd`) | Kenney `tile_0081` (barrotes de madera) o `tile_0070` (reja) | pendiente: verificar en ventana |
| Altar | rectángulo + brillo (`AltarShrine.gd`) | Kenney `tile_0020` (gárgola) sobre `tile_0032` (pedestal con orbe), o la fuente roja de 0x72 | pendiente |
| Nexo | `flask_big_blue` + grietas en código | gema de `cave_gems.png` o Kenney `tile_0032` | pendiente (el actual funciona) |
| Proyectil a distancia | círculo + estela (`Projectile.gd`) | `art/items/weapon_arrow.png` (7×21) para arqueros | pendiente. Para el mago hace falta un **proyectil mágico**: pendiente de arte (se puede tomar del pack de FX) |
| Íconos de recursos HUD | vectores (`StatIcon.gd`) | `weapon_hammer` / comida / `flask_big_green` / `coin_anim_f0` | pendiente (los vectores se leen bien) |
| Corazones de HP | vector | `art/ui/ui_heart_full/half/empty.png` (copiados, sin usar) | pendiente |
| Estado "lento" | `placeholder_status_slow` (sin usar) | `art/items/flask_blue.png` | pendiente (no hay UI de estados) |
| Sala inicio / salida | sin ícono | `art/tiles/floor_ladder.png` / `art/tiles/floor_stairs.png` | pendiente |
| Investigación (7) | `placeholder_research_*` (sin usar) | libros de colores de `books.png`; `weapon_arrow` | pendiente |

## 3. Aplicados en esta sesión

10 reemplazos, todos de bajo riesgo: solo cambia la ruta de textura en un `.tres` (`resources/modules/{forja,scriptorium,ballesta,catapulta,pinchos,brasero}.tres` → `icon_path`; `resources/abilities/{warrior,mage,rogue,tank}_active.tres` → `ext_resource`).
- Son archivos ya copiados en `assets/art/` desde 0x72 (CC0 ⚠, ver `CREDITOS.md`).
- El filtro es Nearest por defecto en el proyecto (`project.godot`, `default_texture_filter=0`); la escala no cambia.
- No se tocaron SpriteFrames ni escenas.
- Se comprobó que cada ruta existe. Los `placeholder_*` siguen en disco (los usa `test_assets_art`).
- **No verificado en ventana:** cómo se ven los íconos verticales (armas de 10×21) en las tarjetas de `BuildingMenu` y en `AbilityButton`.

## 4. Pendiente de arte (sin reemplazo medieval en los packs)

| Qué | Descripción de lo que se necesita |
|---|---|
| Jefes únicos (Señor Demonio, Jefe Ogro) | sprites propios con idle, caminar y ataque, de unos 32×36. Hoy reusan `big_demon`/`ogre` escalados ×2.1/×1.8, iguales a los enemigos de los pisos 4–5 |
| Minijefe (sala Élite) | variante visual de un enemigo (armadura o corona), o un tinte con shader como solución provisoria |
| Proyectil mágico | bola o rayo arcano de 8–16 px con 3–4 frames y un impacto |
| UI de bestiario | marco o pergamino para la ficha, silueta "no descubierto" e íconos de tier (visto / derrotado / dominado) |
| UI de inventario | casillas de equipo (arma/armadura/reliquia/consumible), marco de rareza (común → legendario) y fondo de mochila |
| Retratos de reclutables | retrato 64×64 por héroe reclutable con el estilo de `assets/portraits` (autor ⚠: sin coincidencia en los packs CC0) |
| Íconos de estado | lento, veneno, escudo, buff de ataque, caído |
| Brasero | brasero/fogata animado (hoy, una fuente roja) |
| Granja | gavilla, granero o barril (no hay sprite suelto CC0) |
| Arte del Altar y de la Jaula | si los tiles Kenney no convencen en ventana: altar de piedra con runa y jaula de hierro de 2×2 tiles |
| Música y SFX | `assets/audio/music/floor_1..5.ogg` y `assets/audio/sfx/*.ogg` están cableados en `AudioDirector` pero no existen (lista en `CREDITOS.md`) |

## 5. Observaciones de pipeline

- `.gitignore` excluye `*.import`. Godot 4 guarda en ese archivo el `uid://` de cada textura, así que en un clon nuevo se regeneran y las referencias por uid (p. ej. `room_type_visual_config.tres`) caen a la ruta con warnings. **Recomendado:** versionar los `.import` (la guía de Godot 4 solo ignora `.godot/`). Decisión del dueño del repo.
- `build_tilesets.gd` hornea los 132 tiles de Kenney: los nuevos props y decor salen de ahí sin otro paso.
