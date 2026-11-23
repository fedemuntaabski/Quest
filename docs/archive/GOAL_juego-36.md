# Goal juego-36 (archivado)

Sesión juego-36: ajuste de habilidades, Bendición solo con Obras que funcionan, íconos propios de habilidades y pulido de menús.

Inicio: leer CLAUDE.md, docs/PERSONAJES.md («Revisión de habilidades (juego-35)»), BALANCE.md, PLAYTEST.md, MISSING_ICONS.md, CREDITOS.md y el bloque juego-35 de docs/archive/SESSIONS.md. Verificar que session/juego-35 esté limpia y pusheada; integrarla a main (avance directo si se puede), suite verde, push. Abrir session/juego-36. Capturas en capturas/juego-36/.

Fase 1 — habilidades (el dueño da el OK a las propuestas de juego-35): Bendición de las Obras 30 → 20 s y solo Obras que funcionan (Building.is_working()); Golpe Furtivo 12 → 8 s; Mente Analítica +2 Saber y −10 % al costo de la Investigación con el Mago en pie (un solo punto de lectura; el panel muestra el precio real); Muro Viviente «10 casillas». BalanceSim, test_balance y test_abilities con chequeos nuevos; BALANCE.md y PERSONAJES.md al día; versión 1.9 → 1.10.

Fase 2 — los 8 íconos de habilidades como arte propio en assets/art/own/ (pedido del dueño durante la sesión: armados en LibreSprite, calidad acorde a Kenney, reusando lo que hay), legibles a 720p en retrato, ficha de selección y CharacterPopup; CREDITOS, test_licencias, MISSING_ICONS; shot_barrido antes/después.

Fase 3 — Guardar/Volver de Opciones y Listo de WaitingRoom en mayúsculas; revisar con shot_barrido (720, 1080, ×1,5).

Fase 4 — puertas: opción A de juego-35, sin tocar.

Verificación: tools/run_tests.sh verde; shot_barrido sin FAIL; capturas antes/después; PLAYTEST.md con lo que falta en ventana. Cierre: SESSIONS, CHANGELOG, docs, CLAUDE.md ≤20 KB con la versión 1.10, este archivo, push, /goal siguiente.

Cambio pedido por el dueño durante la sesión: la Fase 2 no usa tools/build_own_art.gd; los íconos se arman en LibreSprite con tools/libresprite_icons.js (tools/libresprite.sh icons), fuente assets/art/own/src/abilities/*.ase.

Resultado: bloque juego-36 de docs/archive/SESSIONS.md.
