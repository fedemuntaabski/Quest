# Goal sesión juego-35 — luz y paso entre salas, puertas, ficha de héroes, revisión de habilidades

Sesión juego-35: luz y paso entre salas, puertas, ficha de héroes, revisión de habilidades.

Inicio: leer CLAUDE.md, docs/BUCLE_JUEGO.md, ECONOMIA.md, ROOMS.md, MAP_RENDER.md, PERSONAJES.md, BALANCE.md y el bloque menu-34 de docs/archive/SESSIONS.md. En session/menu-34 hay 4 .tres sin commitear (solo uids del editor): verificarlo, commit + push. Integrar menu-34 a main (avance directo si se puede), suite verde, push. Abrir session/juego-35. Capturas en capturas/juego-35/.

Fase 1 — héroe trabado (lo más grave). Síntoma del dueño: a veces el clic derecho no mueve al héroe a ninguna sala, ni a las apagadas ni de vuelta a las iluminadas. Las salas apagadas se caminan igual (solo no se construye). Sospecha a confirmar: en PlayerActionController, si un _walk nunca termina (tween que no avanza, error dentro de la corrutina, héroe caído o liberado a mitad) _busy/_busy_peers no se limpian y la línea 57 (is_peer_busy) rechaza toda orden para siempre. Revisar también current_zone_id inválido, zona no revelada en find_zone_path, clic capturado por Door/LightHint/otra Area2D. Herramienta en tests/tools/: N semillas × 5 pisos, abrir puertas, prender/apagar salas, caer/revivir, reclutar, pausa táctica, y comprobar que tras cada paso el héroe camina a cada sala revelada (find_zone_path + caminata real). Arreglar la causa en el punto común; el barrido queda como test. Loguear con QuestLogger por qué se rechaza una orden. Si no se reproduce, pedir semilla/captura al dueño.

Fase 2 — luz: la sala inicial (Reliquia) está siempre prendida y no se puede apagar de ninguna forma; hoy RoomZone.toggle_light()/light_down() no lo impiden. Un solo guard por donde pasen offline, NetCommands y RunState, con show_refusal. Revisar el resto: costo creciente, reembolso, Obras en sala apagada (requires_light), clic medio tras arrastre. Test.

Fase 3 — puertas: el dueño las ve a veces giradas o desalineadas, o feas. shot_mazmorra de puertas horizontales y verticales, cerradas y abiertas, en varios temas; revisar en Door.gd región del atlas, orientación, alineación con la pared y capa. Corregir lo roto; si el arte es lo feo, proponer 2 opciones con captura (solo CC0 o propio, fila en docs/CREDITOS.md, test_licencias verde).

Fase 4 — ficha de héroes: en HeroSelectMenu._show_preview mostrar la descripción de la activa (AbilityData.format_description, con duración y cooldown) como la pasiva; completar description vacías en vocabulario medieval. Que entre a 720p y texto ×1,5 (shot_barrido). Actualizar test_hero_select.

Fase 5 — habilidades de los 4 héroes (pasiva y activa): explicarle al dueño en palabras simples qué hace cada una según el código (no solo el .tres) y verificar que haga eso. Tabla con efecto, valor, duración, cooldown, aporte aproximado y cuándo sirve. Señalar las flojas o pasadas y proponer ajustes; no aplicar sin su OK. Si se aplican: test_balance y test_abilities verdes, BALANCE.md y PERSONAJES.md al día; si cambian números que calculan ambos peers, subir application/config/version.

Restricciones: las de CLAUDE.md (input por Area2D.input_event, Net.is_authority, ManagerLocator, QuestLogger, Accessibility.font, vocabulario medieval, nada del RNG global escondido).

Verificación: tools/run_tests.sh verde; shot_barrido y shot_mazmorra sin FAIL; capturas antes/después. Decir qué se vio solo en capturas y anotar en PLAYTEST.md lo que falta probar en ventana.

Cierre: commits chicos; bloque en SESSIONS.md, línea en CHANGELOG.md, docs del tema al día; CLAUDE.md solo lo duradero (≤20 KB, wc -c). Archivar en docs/archive/GOAL_juego-35.md. Push. Terminar con el /goal siguiente (≤4000 caracteres) apuntando a los docs.
