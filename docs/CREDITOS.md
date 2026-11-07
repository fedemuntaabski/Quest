# Créditos y licencias

Revisión de licencias de todos los assets antes de Steam (uso comercial). Primera pasada en `progresion-10`; en `licencias-20` se retiró todo lo dudoso del juego y del repo público.
Tabla única: `CREDITS.md` solo apunta acá.

- ✅ = licencia verificada, uso comercial permitido.
- 🟦 = propio del proyecto, declarado por el dueño del repo (`licencias-20`).
- ⛔ = licencia desconocida o sin permiso para el repo público: **retirado** del juego y del índice de git (copia local gitignoreada en `assets/art/_rejected/licencia/` o en su carpeta de `_source`).

## Arte y fuentes

| Pack / archivo | Autor | Licencia | Estado | Dónde se usa |
|---|---|---|---|---|
| Tiny Dungeon 1.0 | Kenney (https://kenney.nl/assets/tiny-dungeon) | CC0 1.0 | ✅ `License.txt` en el pack | tiles, props, cofres, espadas y pociones de los ítems, base de los escudos teñidos (`_source/kenney_tinyDungeon`, `resources/tilesets/`, `resources/items/`) |
| Tiny Creatures 1.0 | Clint Bellanger (clintbellanger.net) | CC0 1.0 | ✅ `License.txt` en el pack | enemigos `tc_*` |
| DungeonTileset II v1.7 | 0x72 (https://0x72.itch.io/dungeontileset-ii) | CC0 1.0 | ✅ verificado en la página del autor el 2026-11-07; texto citado en `_source/0x72_DungeonTilesetII_v1.7/LICENSE_VERIFICADA.txt` (el zip no trae licencia) | héroes, enemigos, tiles, íconos de obras y habilidades activas, espadas de brasa y dorada (`assets/art/{characters,enemies,items,tiles,ui}`) |
| Arte propio (`assets/art/own/`) | proyecto (`tools/build_own_art.gd`) | propio | ✅ | armaduras (escudo Kenney 101/102 re-coloreado), grimorios, gema de la Reliquia (`items.png`), 8 hojas de efectos (`own/vfx/`) |
| Íconos `placeholder_*` (`assets/art/ui`) | proyecto (`tools/normalize_assets.gd`) | propio | ✅ | investigación, pasivas de habilidades, Granja |
| Tile placeholder (`assets/texture/enviorment/tileset_placeholder.png`) | proyecto | propio | ✅ (no se ve: grilla lógica oculta) | `Floor` |
| Retratos de héroe (`assets/portraits/*.png`) | dueño del repo | propio / con licencia | 🟦 | `CharacterData.portrait` |
| Fondos de menú (`assets/ui/*.png`) | dueño del repo | propio / con licencia | 🟦 | menús |
| Ícono y splash (`QuestIcon.png`, `bazingastudio.png`) | dueño del repo | propio | 🟦 | `project.godot` |
| Almendra SC (`assets/fonts/mainfont.ttf`) | Ana Sanfelippo | SIL OFL 1.1 | ✅ texto en `assets/fonts/OFL.txt`; distribuirlo con el ejecutable | UI |
| EB Garamond (`assets/fonts/secundaryfont.ttf`) | Georg Duffner / The EB Garamond Project Authors | SIL OFL 1.1 | ✅ ídem | UI |
| GodotSteam 4.22.1 (`addons/godotsteam`) | GodotSteam (https://godotsteam.com) | MIT | ✅ (Steamworks SDK: términos de Valve) | red / Steam |
| Hojas de ítems (armours, weapons, chests, consumables, potions, books) | desconocido | desconocida | ⛔ retiradas en `licencias-20`: ítems → Kenney/0x72/propio | — |
| pixelquest16 (`cave_gems.png`) | desconocido | desconocida | ⛔ retirada: la Reliquia es una gema propia | — |
| Super Pixel Effects Gigapack (Free) v2.9.0 | Will Tice / unTied Games | propia: OK dentro de un juego, prohibido distribuir el pack fuera de él | ⛔ retirado: el repo es público y versionaba 42 efectos; los 8 en uso pasaron a hojas propias | — |
| Raven Fantasy Icons (Free) | desconocido | desconocida | ⛔ nunca se usó; solo local | — |

**Historial de git:** los archivos ⛔ siguen en commits anteriores a `licencias-20` del repo público. Sacarlos del todo requiere reescribir el historial (`git filter-repo`) y forzar el push: decisión del dueño, no se hizo.

### Licencias permitidas (la lee `tests/test_licencias.gd`)

Cada ruta `res://` de arte, fuente o audio nombrada en `scenes/`, `resources/`, `scripts/` o `project.godot` debe ser igual a una fila o empezar con una fila terminada en `/`. Al sumar un asset: agregar su fila acá con licencia verificada (o sumarlo bajo una carpeta ya listada solo si es del mismo pack y licencia).

<!-- licencias:inicio -->
| Regla | Licencia |
|---|---|
| `res://assets/art/_source/0x72_DungeonTilesetII_v1.7/` | CC0 1.0 (0x72) |
| `res://assets/art/_source/kenney_tinyDungeon/` | CC0 1.0 (Kenney) |
| `res://assets/art/_source/tiny-creatures/` | CC0 1.0 (Clint Bellanger) |
| `res://assets/art/characters/` | CC0 1.0 (0x72) |
| `res://assets/art/enemies/` | CC0 1.0 (0x72, Tiny Creatures) |
| `res://assets/art/items/` | CC0 1.0 (0x72) |
| `res://assets/art/tiles/` | CC0 1.0 (0x72, Kenney) |
| `res://assets/art/ui/` | CC0 1.0 (0x72) + propio (`placeholder_*`) |
| `res://assets/art/own/` | propio (`tools/build_own_art.gd`) |
| `res://assets/texture/enviorment/` | propio |
| `res://assets/fonts/mainfont.ttf` | SIL OFL 1.1 (Almendra SC) |
| `res://assets/fonts/secundaryfont.ttf` | SIL OFL 1.1 (EB Garamond) |
| `res://assets/portraits/` | propio (declarado) |
| `res://assets/ui/` | propio (declarado) |
| `res://assets/audio/click.mp3` | propio (declarado) |
| `res://assets/audio/hover.mp3` | propio (declarado) |
| `res://QuestIcon.png` | propio (declarado) |
| `res://bazingastudio.png` | propio (declarado) |
<!-- licencias:fin -->

## Audio

| Archivo | Autor | Licencia | Estado | Dónde se usa |
|---|---|---|---|---|
| `assets/audio/click.mp3`, `hover.mp3` | dueño del repo | propio / con licencia | 🟦 declarado en `licencias-20` | menús (bus UI) |
| Alerta de enemigos (respaldo) | generada en código (`HUDController._load_alert_stream`, onda seno) | propia | ✅ suena solo mientras falte `sfx/alert.ogg` | HUD |

`licencias-20`: no entró ningún archivo nuevo (en `assets/audio/` solo están `click.mp3` y `hover.mp3`). Cuando entre uno, sumarlo a la tabla de arriba y a "Licencias permitidas" con autor y licencia; si la licencia no es clara, no se usa (`test_licencias` falla hasta que tenga fila).

### Audio faltante (rutas ya cableadas en `AudioDirector`)

Un archivo ausente suena en silencio y deja un aviso en el log una sola vez. Cada ruta acepta la misma base con `.wav` o `.mp3`. `tests/test_audio.gd` lista los que faltan (`PENDIENTE`); con `-- --audio-strict` falla si falta alguno.

| Ruta | Uso | Bus | Qué buscar |
|---|---|---|---|
| `assets/audio/sfx/door.ogg` | abrir una puerta (`PlayerActionController.open_door`) | SFX | puerta de madera pesada con chirrido, <1,5 s |
| `assets/audio/sfx/chest.ogg` | abrir un cofre (`Chest.try_open`) | SFX | cerradura + tintineo, <1 s |
| `assets/audio/sfx/hit.ogg` | golpe de un héroe (`Player._on_attack_landed`, máx. 1 cada 80 ms) | SFX | impacto de espada corto, <0,3 s |
| `assets/audio/sfx/tower.ogg` | disparo de defensa (`DefenseBuilding`) | SFX | ballesta (twang + silbido), <0,5 s |
| `assets/audio/sfx/light.ogg` | encender una sala pagando Brasas (`RoomZone.try_light_up`; apagar no suena) | SFX | antorcha que se enciende, <1 s |
| `assets/audio/sfx/build.ogg` | obra construida (`BuildingSlot.build`) | SFX | martillazos / madera colocada, <1 s |
| `assets/audio/sfx/relic.ogg` | recoger la Reliquia (`RelicController.confirm_pickup`) | SFX | campanada o coro breve, 1-2 s |
| `assets/audio/sfx/alert.ogg` | enemigos aparecen (`HUDController._play_alert`, reemplaza el beep) | SFX | cuerno de guerra o campana de alarma, <1,5 s |
| `assets/audio/sfx/victory.ogg` | piso superado / partida ganada | SFX | jingle triunfal, 2-4 s |
| `assets/audio/sfx/defeat.ogg` | partida perdida | SFX | jingle fúnebre, 2-4 s |
| `assets/audio/music/menu.ogg` | menú principal e intro (`Main.show_main_menu`, `_play_intro_if_due`) | Music | loop lento de abadía (laúd, órgano, coro), sin percusión fuerte |
| `assets/audio/music/floor_1.ogg` … `floor_5.ogg` | música de cada piso (`FloorTheme.music_path`, bucle, fundido 1 s); el Tutorial usa la del piso 1 | Music | loops de mazmorra sin intro/outro: 1 calmo (drones, cuerdas) → 5 tenso (percusión grave) |
| `assets/audio/music/extraction.ogg` | fase de extracción, todos los pisos (`AudioDirector.MUSIC_EXTRACTION`) | Music | loop tenso y rápido, percusión |

### Packs gratuitos sugeridos (verificar la licencia en la página de cada uno antes de bajar)

| Pack | Autor | Licencia declarada | Para |
|---|---|---|---|
| RPG Audio | Kenney (https://kenney.nl/assets/rpg-audio) | CC0 | puerta, cofre, pasos |
| Impact Sounds | Kenney (https://kenney.nl/assets/impact-sounds) | CC0 | golpe, torre |
| Interface Sounds | Kenney (https://kenney.nl/assets/interface-sounds) | CC0 | reemplazo de click/hover |
| Music Jingles | Kenney (https://kenney.nl/assets/music-jingles) | CC0 | victoria / derrota |
| Música de mazmorra en OpenGameArt filtrada por "CC0" (https://opengameart.org/art-search-advanced?field_art_type_tid[]=12&field_art_licenses_tid[]=4) | varios | CC0 (filtro) | música por piso |

Si se usa un pack CC-BY en lugar de CC0, agregar su autor a esta tabla y al texto de `CreditsPanel`.

## Pendiente antes de Steam

1. Decidir si se purga el historial de git de los archivos ⛔ (ver arriba).
2. Distribuir `assets/fonts/OFL.txt` junto al ejecutable exportado.
3. Si entra audio o arte nuevo, sumarlo a las tablas, a "Licencias permitidas" y, si pide atribución, a `CreditsPanel`.
