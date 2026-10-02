# Auditoría de assets — `session/assets-5`

Base: `session/refactor-2` (`41a44ab`). Revisión de delta sobre `docs/ASSETS.md` y `docs/MISSING_ICONS.md` (assets-1..4) tras el refactor-2 (rutas movidas). **Solo se corrigió lo claramente roto; nada se borró.** Todo lo dudoso está en "Para decidir" al final.

Cómo se midió (scripts descartables, no versionados): recorrido de todo el árbol (sin `.git`/`.godot`) cruzando cada `res://…` y `uid://…` de `.tres/.tscn/.gd/.json/project.godot` contra los archivos, `.uid` y `.import` locales; cabeceras PNG con Pillow; SHA-1 por archivo; búsqueda de uso por ruta/uid/nombre; volcado de animaciones de cada `SpriteFrames`; boot headless de `Main.tscn` y 4 tests de assets.

## Resumen
| Verificación | Resultado |
|---|---|
| Referencias `res://` y `uid://` rotas | **0** (2 falsos positivos: nombres con espacios, `Lobby Multijugador.png` y `Selección de Héroes.png`, existen) |
| `ext_resource` con uid que apunta a otra ruta | **0** |
| PNG sin `.import` local | **0** |
| `.import` con parámetros no default | **0** de 11 348 (todos lossless, sin mipmaps, `fix_alpha_border`) |
| Filtro de textura | `default_texture_filter=0` (Nearest) en `project.godot`; los 7 `.tscn` de `scenes/vfx` y 6 sitios en UI lo fuerzan a Nearest; **ninguno usa Linear** |
| Boot headless `Main.tscn` (`--quit-after 90`) | sin `SCRIPT ERROR` ni `Failed loading` (solo el aviso de Steam) |
| `test_assets_art`, `test_sprites`, `test_items`, `test_art_config` | 4/4 OK |
| Corregido | `CREDITS.md` (tabla cortada; faltaban fuentes, audio, retratos/fondos, ícono/splash) → commit `assets: CREDITS.md…` |

## 1. Ubicación y nombres
- Estructura actual: `assets/art/{armor,characters,enemies,items,tiles,ui,vfx,weapons}` (copias por categoría), `assets/art/_source` (packs intactos), `assets/art/_rejected`, y fuera de `art/`: `assets/{audio,fonts,portraits,texture,ui}`.
- **Carpetas vacías sin referencias** (restos locales, git no las versiona, no hay nada que commitear): `assets/nuevos/…` (anidada, restos de los packs ya movidos a `_source`), `assets/characters/`, `assets/tilesets/`, `assets/vfx/`. Seguras de borrar a mano; no se tocaron.
- `assets/art/characters/tiny_creatures_packed.png` (hoja de **enemigos** Tiny Creatures) vive en `characters/`; la usan los 7 `tc_*.tres`. Sería más coherente en `enemies/`. Mover = tocar 7 `.tres` + `tools/build_characters.gd`: no se hizo (no está roto).
- Nombres inconsistentes: `assets/texture/enviorment/` (typo, `tileset_placeholder.png`, lo sigue usando `placeholder_tileset.tres`); archivos con espacios y tildes en `assets/ui/` (`Lobby Multijugador.png`, `Selección de Héroes.png`, `256x256 textures (113).png`) y retratos en español (`guerrero/mago/picaro/tanque.png`) frente al resto en inglés; `zombie_anim_f10.png` (el pack 0x72 lo llama así, es su frame 0). Renombrar rompe uids/rutas: no se hizo.
- `QuestIcon.png` (1254×1254) y `bazingastudio.png` (1672×941) están en la raíz del repo (los usan `config/icon` y `boot_splash`).

## 2. Referencias, `.import` y tilesets
- Sin roturas. Detalle útil para quien exporte: `resources/tilesets/dungeon_tileset.tres` y `props_tileset.tres` leen directamente `assets/art/_source/0x72…/0x72_DungeonTilesetII_v1.7.png` y `assets/art/_source/kenney_tinyDungeon/Tilemap/tilemap_packed.png`; `tools/build_tilesets.gd` también. O sea que **el juego depende de `_source`**: al crear el preset de exportación no se puede excluir `assets/art/_source/**` entero (sí `super_pixel_effects/`, `raven_fantasy_icons/` y `_rejected/`). Las copias de `assets/art/tiles/` (75 de 76 PNG) no las referencia nadie (solo `atlas_walls_low-16x16.png`).
- `.import` no se versionan (`.gitignore`): lo que vale para un clon limpio es el default del proyecto (Nearest, lossless, sin mipmaps), que `test_assets_art` verifica.

## 3. Tamaño, filtro y escala
| Grupo | Tamaños (px) | Nota |
|---|---|---|
| Héroes 0x72 | 16×28 (idle 4, run 4, hit 1) | en pantalla ×2 = 32×56 |
| Enemigos 0x72 pequeños | 16×16 y 16×23 (`necromancer`, `pumpkin_dude`) | ×2 |
| Enemigos 0x72 grandes | 32×36 (`big_zombie`, `big_demon`, `ogre`) | ×2 |
| Tiny Creatures | 16×16, 1 frame, hoja 160×288 | `visual_scale` 1.2–1.3 en 3 tipos (`tc_demon`, `tc_dragon`, `tc_ogre`) |
| Tiles / ítems / armas / íconos | 16×16 (+ props 16×32, 16×48, 32×32; monedas 6×7, frascos 8–14 px) | tamaños nativos de 0x72 |
| Hojas de ítems | 16×16 por celda (144×304, 128×144, …) | OK |
| FX | 25–96 px por frame (excepción documentada) | OK |
| **Retratos** | **1024×1024** ×4 | arte tipo pixel-art pero con otra densidad de píxel que los sprites de 16 px |
| **Fondos de menú** | 1024×1024 y 1024×572/585 | ídem |
- Escala: todo sprite de mundo usa `ArtConfig.ART_SCALE` (×2) vía `CharacterVisual.setup()`; `test_art_config` ata `CELL_PX` a `tile_size` y `DEFAULT_TILE_SIZE`. Sin desvíos.
- Retratos y fondos con Nearest (`HeroSelectMenu`, `HeroPortrait`, `CharacterPopup`) se reducen a escala **no entera** desde 1024 px: puede verse aliasing/centelleo. No es un error de referencia; ver "Para decidir".

## 4. Duplicados, sin uso, fuera de estética
**Duplicados (SHA-1, fuera de `_source`)**
| Grupo | Veredicto |
|---|---|
| `assets/ui/background.png` = `assets/ui/mainbackground.png` (idénticos) | `background.png` sin ninguna referencia; ya figuraba en `REFACTOR_REPORTE.md` ("confirmar en editor") |
| `*_idle_anim_f1` = `f3` (goblin, imp, tiny_zombie) y `zombie_anim`/`ice_zombie_anim` f1 = f3 | del pack (ciclo de 4 frames), esperado |
| `chest_empty/full/mimic_open_anim_f0` idénticos | del pack (primer frame cerrado), esperado |
| 29 `placeholder_*` en 5 grupos de PNG iguales por categoría | por diseño (color por categoría + X) |
Copias de `_source` en carpetas finales (esperado, ver `ASSETS.md`): 107 characters, 132 enemies, 57 items, 76 tiles, 42 vfx, 7 ui, armor 1, weapons 1; 43 PNG no tienen origen idéntico (`placeholder_*` + hojas recortadas/ensambladas).

**Sin referencias** (ni ruta ni uid en `.tres/.tscn/.gd/.json`)
| Carpeta | Sin uso | Detalle |
|---|---|---|
| `art/characters` | 8 de 9 familias | usados: `knight_m`, `wizzard_m`, `elf_m`, `dwarf_m` + TC. Sin uso: `angel`, `doc`, `*_f` (dwarf, elf, knight, wizzard), `lizard_f/m` |
| `art/enemies` | 8 de 21 familias | sin uso: `ice_zombie`, `muddy`, `pumpkin_dude`, `slug`, `swampy`, `tiny_slug`, `zombie` (+`zombie_anim_f10`) |
| `art/items` | 47 de 58 | 25 de 27 `weapon_*` y `flask_*`/`crate`/`skull`/`bomb`/cofres abiertos: a la espera de un sistema de equipo/loot; en uso: `books`, `chests`, `consumables`, `potions`, `cave_gems`, `flask_big_blue/red`, `weapon_regular_sword`, `weapon_double_axe`, `coin_anim_f0`, `chest_full_open_anim_f0` |
| `art/tiles` | 75 de 76 | ver §2 (los tilesets leen `_source`) |
| `art/ui` | 35 de 36 | solo se usa `button_blue_up`; 29 `placeholder_*` sin cablear (a propósito), `button_red_*`, `button_*_down`, `ui_heart_*` |
| `art/vfx` | 34 de 42 | (por nombre en `vfx_config.tres`/código) en uso 8: `directional_impact_002_white`, `round_sparkle_burst_002_green`, `spell_attack_up_001_red`, `spell_defense_up_001_blue`, `spell_haste_001_green`, `symbol_magic_up_001_violet`, `symmetrical_impact_001_yellow`, `symmetrical_smoke_burst_001_brown`. Los otros 34 son stock curado para efectos futuros (estados, explosiones, rayos) |
| `assets/ui` | `background.png`, `256x256 textures (113).png` | sin referencias |
| `assets/portraits/`, `assets/ui/{Opciones,Lobby…,Selección…,mainbackground}.png`, audio, fuentes | todo en uso | |
| `CharacterData.profile_bg` | campo sin lector en todo el código | no es asset, pero espera un fondo de perfil que nunca se usa |

**Fuera de la estética medieval/oscura (solo listados)**
- 0x72: `angel`, `doc` (médico), `pumpkin_dude` (calabaza), `tiny_slug`/`slug`/`muddy`/`swampy`/`ice_zombie` (criaturas caricaturescas), `lizard_*` (ya sin uso).
- Armas 0x72: `weapon_anime_sword`, `weapon_katana`, `weapon_lavish_sword`, `weapon_saw_sword`, `weapon_red_gem_sword`, `weapon_baton_with_spikes` (el resto es medieval).
- `art/ui`: `button_blue_*`/`button_red_*` (botones planos de 0x72, genéricos).
- `assets/ui/256x256 textures (113).png`: textura genérica sin referencias.
- Ya apartados en `_rejected/`: FX sci-fi, splatters, `stylized_explosion_*`, símbolos arcade (ver `assets/art/_rejected/README.md`).
- Retratos y fondos de `assets/` (ilustraciones 1024 px): oscuros/medievales, pero con otro estilo y densidad que los sprites 16 px (ver §3).

## 5. Animaciones (de `resources/sprite_frames/*.tres`)
Convención del código (`CharacterVisual`): reconoce **`idle`**, **`run`** (= caminar) y **`hit`**; si no hay `hit` hace un parpadeo blanco (shader); si no hay `run` rebota procedural (`BOUNCE_*`). No existe ningún nombre `attack`/`death` en código ni en recursos: ataque = VFX de tajo/chispas (`VfxManager`), muerte del enemigo = VFX `death_dust` + `queue_free()`, muerte de héroe = sin animación (la run termina).

| Entidad | idle | caminar (`run`) | ataque | daño (`hit`) | muerte |
|---|---|---|---|---|---|
| Héroes ×4 (`hero_knight_m`, `wizzard_m`, `elf_m`, `dwarf_m`) | 4 f ✔ | 4 f ✔ | ✘ (VFX) | 1 f ✔ + flash | ✘ |
| Enemigos 0x72 ×13 (`goblin`, `skelet`, `tiny_zombie`, `imp`, `masked_orc`, `orc_warrior`, `orc_shaman`, `chort`, `wogol`, `necromancer`, `big_zombie`, `ogre`, `big_demon`) | 4 f ✔ | 4 f ✔ | ✘ (contacto sin anim) | ✘ (solo flash) | ✘ (VFX polvo) |
| Tiny Creatures ×7 (`tc_wolf`, `tc_eyeball`, `tc_fire_skull`, `tc_red_imp`, `tc_demon`, `tc_ogre`, `tc_dragon`) | 1 f (estático) | ✘ (rebote procedural) | ✘ | ✘ (flash) | ✘ (VFX polvo) |
- Velocidades: idle 6 fps, run 10 fps, hit 1 fps sin loop.
- **Faltan** para todos: ataque y muerte; para enemigos además `hit`; para TC además caminar. Ningún pack incluido (0x72, Kenney, Tiny Creatures) trae ataque/muerte → harían falta otro pack o animación por código (tween de embestida, fundido).
- `pumpkin_dude`, `slug*`, `muddy`, `swampy`, `zombie`, `ice_zombie`, `lizard_*`, `*_f`, `angel`, `doc` tienen frames pero no `SpriteFrames` (ver §4).

## 6. Íconos faltantes
`docs/MISSING_ICONS.md` sigue vigente: **29 placeholders** en `assets/art/ui/placeholder_*.png` (gen_×3, turret, trap, nexo, res_×5, room_start/exit, status_slow, research_×7, ability_×8), todos sin cablear. Cubiertos con arte real (disponible, no cableado): corazones (`ui_heart_*`; el `MISSING_ICONS.md` los ubica en `art/items` pero están en `art/ui`, y la vida se dibuja con `HealthBarStyle`), armas/armaduras/pociones/grimorios (hojas de ítems), estados genéricos animados (`art/vfx`).
Faltan, además de lo anterior (no tienen ni placeholder):
| Ícono | Dónde haría falta |
|---|---|
| Torre (Ballesta) y módulos construidos como ícono propio de mapa | `Module.CATALOG` hoy dibuja `Polygon2D`/ícono genérico; sprite de la torre en la sala |
| Estado "módulo apagado / sin energía" y "bajo ataque" | `Module.powered`/`is_working()`, `Module.take_damage` sin indicador |
| Estados de buff/escudo de héroe (ataque+, escudo, sobrecarga) | `HeroAbilities` los aplica solo con VFX temporal, sin ícono persistente en el retrato |
| Rol del enemigo (cazador / saqueador) | hoy rombo rojo dibujado por código (`Enemy._mark_as_raider`) |
| Estado del Nexo (intacto / dañado / cargado) | grietas por código y borde rojo de HUD |
| Slots de equipo (arma/armadura/consumible/reliquia) y marcos de rareza | `ItemData.Slot`/`Rarity` existen, no hay UI de equipo |
| Armaduras por héroe | existen en `armor/armours.png` pero sin sistema que las muestre sobre el sprite |

## 7. Licencias (`CREDITS.md`, ya corregido)
| Pack | Estado |
|---|---|
| Kenney Tiny Dungeon, Tiny Creatures | CC0, `License.txt` presente en `_source/` |
| 0x72 DungeonTileset II | CC0 según la web del autor; el README del repo no trae licencia |
| Super Pixel Effects | licencia propia, **atribución obligatoria**; falta el texto en créditos in-game; el pack crudo no se versiona |
| Almendra SC, EB Garamond | OFL 1.1 (leído de la tabla `name` de cada `.ttf`); al redistribuir, incluir el texto de la OFL |
| ⚠ Hojas de ítems, pixelquest16, Raven (no se usa) | autor/licencia **desconocidos** |
| ⚠ Retratos y fondos de `assets/`, audio click/hover, `QuestIcon`/`bazingastudio` | origen **desconocido** (nunca estuvieron en `CREDITS.md`) |

## Para decidir (no tocado)
1. Borrar o archivar: carpetas vacías locales, `assets/ui/background.png` (duplicado exacto) y `256x256 textures (113).png`, copias sin uso de `assets/art/tiles/`, familias de `characters`/`enemies` sin `SpriteFrames`.
2. Mover `tiny_creatures_packed.png` a `enemies/` y renombrar `enviorment`/archivos con espacios (rompe rutas y uids).
3. Retratos/fondos 1024 px: reexportar a una resolución con escala entera o aceptar el aliasing.
4. Resolver licencias ⚠ antes de Steam (ítems, pixelquest16, retratos/fondos, audio, ícono/splash) y agregar la atribución de unTied Games en los créditos del juego.
5. Animaciones de ataque/muerte (y `hit` para enemigos): elegir pack o hacerlas por código.
6. Al exportar: incluir `assets/art/_source/0x72…` y `kenney_tinyDungeon/Tilemap` (los tilesets los leen) o repuntar los tilesets a copias en `art/tiles/` y regenerar con `tools/build_tilesets.gd`.
7. Eliminar o cablear `CharacterData.profile_bg` (campo sin uso).
