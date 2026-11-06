# Créditos y licencias

Revisión de licencias de todos los assets antes de Steam (uso comercial), sesión `progresion-10`.
Tabla única: reemplaza a la de `CREDITS.md` (que ahora solo apunta acá). Nada se borró: lo dudoso queda marcado.

- ✅ = licencia verificada en el pack, uso comercial permitido.
- ⚠ = no permite uso comercial, no tiene licencia clara o falta verificar el origen. **Resolver antes de publicar.**

## Arte y fuentes

| Pack / archivo | Autor | Licencia | Estado | Dónde se usa |
|---|---|---|---|---|
| Tiny Dungeon 1.0 | Kenney (https://kenney.nl/assets/tiny-dungeon) | CC0 1.0 | ✅ `License.txt` en el pack | tiles, props, cofres (`assets/art/_source/kenney_tinyDungeon`, `resources/tilesets/`) |
| Tiny Creatures 1.0 | Clint Bellanger (clintbellanger.net) | CC0 1.0 | ✅ `License.txt` en el pack; atribución opcional | enemigos `tc_*` |
| DungeonTileset II v1.7 | 0x72 (https://0x72.itch.io/dungeontileset-ii) | CC0 1.0 según la página del autor | ⚠ el README del pack no trae texto de licencia: guardar captura de la página de itch.io | héroes, enemigos, ítems (`assets/art/{characters,enemies,items}`); desde `multijugador-11` también los íconos de obras (martillo, ballesta, bomba, frasco, pinchos, fuente roja) y de habilidades activas (espada, báculo, cuchillo, martillo grande) |
| Super Pixel Effects Gigapack (Free) v2.9.0 | Will Tice / unTied Games (https://untiedgames.itch.io/super-pixel-effects-gigapack) | Propia: uso comercial OK, **atribución obligatoria**, prohibido redistribuir el pack crudo o usarlo para entrenar IA | ✅ atribución ya incluida en la pantalla de Créditos (`CreditsPanel`); el pack crudo no se versiona | `assets/art/vfx` (42 efectos curados) |
| Raven Fantasy Icons (Free) | ⚠ desconocido | ⚠ desconocida | ⚠ solo local (`assets/nuevos`, `_source/raven_fantasy_icons`, gitignored); **no se usa en el juego** | — |
| Hojas de ítems (armours, weapons, chests, consumables, potions, books) | ⚠ desconocido | ⚠ desconocida | ⚠ verificar origen/licencia | `assets/art/{armor,weapons,items}`, `resources/items/` |
| pixelquest16 (cave, july-2025) | ⚠ desconocido | ⚠ desconocida | ⚠ verificar | `assets/art/items/cave_gems.png` |
| Retratos de héroe (`assets/portraits/*.png`) | ⚠ desconocido | ⚠ desconocida | ⚠ verificar autor/origen | `CharacterData.portrait` |
| Fondos de menú (`assets/ui/*.png`: `mainbackground`, `background`, `Opciones`, `Selección de Héroes`, `Lobby Multijugador`, `256x256 textures (113)`) | ⚠ desconocido | ⚠ desconocida | ⚠ verificar | menús |
| GodotSteam 4.22.1 (`addons/godotsteam`) | GodotSteam (https://godotsteam.com) | MIT | ✅ (Steamworks SDK: términos de Valve) | red / Steam |
| Ícono y splash (`QuestIcon.png`, `bazingastudio.png`) | ⚠ ¿propios del proyecto? | ⚠ por confirmar | ⚠ confirmar que son propios | `project.godot` |
| Tile placeholder (`assets/texture/enviorment/tileset_placeholder.png`) | proyecto | propio | ✅ (no se ve: grilla lógica oculta) | `Floor` |
| Íconos `placeholder_*` (`assets/art/ui`) | generados por `tools/normalize_assets.gd` | propios | ✅ | investigación, pasivas de habilidades, Granja (el resto se reemplazó en `multijugador-11`, ver `docs/ASSETS_REEMPLAZOS.md`) |
| Almendra SC (`assets/fonts/mainfont.ttf`) | Ana Sanfelippo | SIL OFL 1.1 | ✅ incluir el texto de la OFL al distribuir | UI |
| EB Garamond (`assets/fonts/secundaryfont.ttf`) | Georg Duffner / The EB Garamond Project Authors | SIL OFL 1.1 | ✅ incluir el texto de la OFL al distribuir | UI |

## Audio

| Archivo | Autor | Licencia | Estado | Dónde se usa |
|---|---|---|---|---|
| `assets/audio/click.mp3`, `hover.mp3` | ⚠ desconocido | ⚠ desconocida | ⚠ verificar o reemplazar por Kenney Interface Sounds (CC0) | menús (bus UI) |
| Alerta de enemigos (respaldo) | generada en código (`HUDController._load_alert_stream`, onda seno) | propia | ✅ suena solo mientras falte `sfx/alert.ogg` | HUD |

`audio-18`: no entró ningún archivo nuevo (en `assets/audio/` solo están `click.mp3` y `hover.mp3`). Cuando entre uno, sumarlo a la tabla de arriba con autor y licencia; si la licencia no es clara, no se usa.

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

1. Resolver cada ⚠: conseguir autor y licencia, o reemplazar el asset.
2. Guardar el texto de la OFL junto al ejecutable exportado.
3. Si entra audio nuevo, sumarlo a las tablas y a `CreditsPanel`.
