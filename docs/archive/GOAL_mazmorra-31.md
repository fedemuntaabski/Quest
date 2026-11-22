# Goal sesión mazmorra-31 — la mazmorra se ve y se arma mejor

Abrí session/mazmorra-31 desde session/juego-30 (commit + push de lo pendiente antes, incluido este archivo). Primero integrá a main: si session/juego-30 no está en main, mergeala (avance directo si se puede) y dejá la suite verde.

**Tema:** la mazmorra se ve y se arma mejor, siguiendo el estilo actual (16 px ×2, paleta y muros de hoy): salas con formatos más diversos, tipos de sala revisados, decoración propia de mejor calidad e iluminación con fuentes de luz y sombras.

## 0. Antes de tocar código

- Leé CLAUDE.md, docs/MAP_RENDER.md, docs/ROOMS.md, docs/ASSETS.md, docs/CREDITOS.md, tools/build_tilesets.gd, tools/build_own_art.gd y tools/libresprite.sh (LibreSprite en E:/LibreSprite/libresprite.exe; si no está, buscalo en G: y avisame).
- Corré tools/run_tests.sh para tener la línea base.
- Sacá capturas del estado actual (tests/tools/shot_*.gd) de 3 semillas × pisos 1, 3 y 5 como «antes».

## Fases

Hacer por fases; **mostrame capturas y preguntame al cerrar cada una antes de seguir.**

### 1. Auditoría (sin tocar nada)

Cómo se reparten hoy tiles, muros, suelo y decoración (MapTileRenderer, DungeonTiles, tilesets, densidades en MapVisualConfig) y los 10 tipos de sala (RoomTypeRule, RoomTypeVisual; ROOMS.md solo audita 7: faltan PRISONER, ALTAR, SECRET). Por tipo: qué hace, cuándo aparece, si se entiende y si se distingue a simple vista. Entregame una tabla con problemas y propuestas.

### 2. Interior variado, sin tocar la lógica

Más tamaños y proporciones de rectángulo (ROOM_SIZES dentro de SLOT_PITCH) y plantillas de interior por sala (columnas, pozos, alfombras, escombros, suelo distinto por zona), deterministas por semilla y con su RNG propio. Nada puede tapar slots de obras, puertas, la Reliquia, jaulas ni cuerpos. Con test en test_tile_renderer / test_map_generator.

### 3. Formas nuevas (L, cruz, esquinas cortadas)

Antes de escribir código, proponeme cuáles y qué sistemas tocan (RoomData/MapLayout.validate, RoomZone y su clic, slots de BuildingSlot, find_zone_path y centros, anillo de enemigos, Minimap, guardado por semilla, red). Aplicá solo las que elija, con tests que recorran 150+ mapas (test_rooms, test_salas_exhaustivo).

### 4. Identidad por tipo de sala

Cada tipo con su suelo, props y color de luz propios (por ejemplo, Descanso cálido, Élite rojo, Altar frío), y propuesta de tipos nuevos o de quitar los que no aportan. Lo que cambie una mecánica, preguntámelo antes; si toca balance, medilo con BalanceSim.

### 5. Decoración propia en LibreSprite

Pixel art de 16 px con la paleta actual (antorchas y braseros animados, estanterías, cadenas, huesos, telarañas, grietas, charcos, lo que tenga sentido en una mazmorra) y mejora de los props que se vean pobres. Fuente .ase en assets/art/own/src, PNG exportados fuera de _source, filas en docs/CREDITOS.md como arte propio, tilesets rehorneados conservando los uid; test_licencias verde.

### 6. Iluminación

Luz propia que parpadea en antorchas y braseros (PointLight2D con textura suave, color por tipo de sala), sombras de muros con LightOccluder2D y una transición más suave al encender una sala, con la sala oscura todavía legible. Mostrame 2-3 variantes en capturas antes de fijar valores. Medí el costo en FPS con 4 héroes y una oleada (bench en tests/tools) y en GL Compatibility; si cuesta más de 1 ms por cuadro, decímelo.

## Reglas

- Seguí el estilo actual.
- Nada en runtime puede apuntar a assets/art/_source/.
- Las salas sin revelar no muestran tiles, luz ni sombras.
- Las VFX nuevas del mundo se reproducen del lado del host.
- Si cambia algo que calculan los dos pares (layout, RunState), bump de config/version (hoy 1.7) y test_net_* verdes.
- Preguntame ante cualquier duda de diseño.

## Criterio de terminado

- Lo elegido hecho, con tests y con capturas «antes / después» en 720p y 1080p.
- tools/run_tests.sh sin FAIL (OK* = crash conocido de Godot 4.6.2).
- Bloque en docs/archive/SESSIONS.md.
- docs/MAP_RENDER.md, docs/ROOMS.md, docs/ASSETS.md, docs/CREDITOS.md y docs/PLAYTEST.md actualizados; CHANGELOG.md.
- CLAUDE.md solo donde cambió (≤20 KB; hoy 19 984 bytes: recortá si sumás).
- Informe actualizado (secciones de arriba editadas en el lugar, la sesión nueva como pliego al principio del Historial, este /goal reemplazado, capturas incluidas).
- Al cerrar, mover este archivo a docs/archive/ (como GOAL_juego-22.md) y dejar otro prompt al final.
