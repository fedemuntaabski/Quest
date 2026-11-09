# Guía de playtest: primera partida (30 minutos)

Nadie jugó todavía una partida completa de corrido, y lo que más vale ahora es tu sensación. Son 30 minutos con 5 paradas: lo importante es ver qué se entiende sin ayuda externa. No hace falta ganar. Una partida de 5 pisos lleva 60–90 minutos: si querés seguir después, seguí; no entra en esta guía.

## Antes de empezar (2 min)
1. Cerrá el editor si quedó abierto y arrancá con F5, no F6.
2. Ranura nueva, Offline, Guerrero + Mago, Normal.
3. No abras esta guía de nuevo hasta el minuto 10: leé primero lo que te muestra el juego.

Opcional, antes (5 min): menú principal → **TUTORIAL**. Muestra la intro (una vez) y guía un piso fijo en 8 pasos; anotá el paso donde te trabaste. Desde ahí no se guardan récords ni bestiario.

Si querés volver a ver las ayudas (y la intro): Opciones → Accesibilidad → "Volver a ver las ayudas". Ahí también se apagan.

Si algo se rompe, anotá piso y qué hacías, y adjuntá el `quest.log` más reciente (Opciones → Accesibilidad → "Abrir carpeta de registros").

## Minutos 0–10: entender el objetivo
Jugá sin mirar nada más. Al minuto 10 contestá:
- [ ] ¿Entendiste qué hay que hacer leyendo solo la lista "Objetivo" arriba a la izquierda?
- [ ] ¿La ayuda "Cómo se juega" alcanzó para moverte y abrir una puerta?
- [ ] ¿Encontraste solo la Reliquia? Es una gema roja sobre la sala inicial.
- [ ] Hacé clic en la Reliquia antes de encontrar la salida: el motivo debe salir en la tarjeta de arriba, legible.

## Minutos 10–15: encender y construir
- [ ] Al descubrir la primera sala oscura aparece la ayuda "Sala oscura". ¿Llegó a tiempo o ya habías abierto otras puertas? Puede salir hasta 14 s después, porque espera a la ayuda anterior.
- [ ] ¿El cartel "Clic central: encender" se lee sobre la sala oscura?
- [ ] Encendé una sala con clic central. Después arrastrá con el botón central: mueve la cámara y no enciende.
- [ ] Construir → Mayores → elegí una obra. El hueco crece y pulsa sobre los héroes. ¿Lo viste sin buscarlo?
- [ ] Hacé clic en el hueco aunque haya un héroe parado encima: debe construir, no seleccionar al héroe.
- [ ] Abrí Investigación: las 3 pestañas se ven enteras.

## Minutos 15–22: Reliquia y salida
- [ ] Con la salida descubierta, volvé a la sala inicial y recogé la Reliquia.
- [ ] Debe verse sobre la cabeza del portador y al lado de su nombre en el retrato. ¿Se nota mientras caminás?
- [ ] La tarjeta dice quién la lleva. El objetivo pasa al paso 3.
- [ ] Hacé clic en una puerta cerrada: la tarjeta explica que están bloqueadas.
- [ ] ¿La extracción da tensión o es solo caminar? ¿15 % más lento se nota?

## Minutos 22–27: que caiga un héroe
Dejá que el portador muera (no lo defiendas, o usá solo a ese héroe). Si la Reliquia no está en juego, igual probá la caída de otro héroe.
- [ ] Aparece la ayuda "Héroe caído" con las reglas. ¿Se entiende que se pierde si bajás de piso sin reanimarlo?
- [ ] La tarjeta dice en qué sala quedó la Reliquia, con anillo y rótulo sobre ella, y marca dorada en el minimapa.
- [ ] **Hacé clic justo sobre la Reliquia caída** con el otro héroe en la sala: debe recogerla y **no** gastar Comida en reanimar. El cuerpo está debajo, así que este es el caso más delicado.
- [ ] Reanimá con clic en el cuerpo o con el botón del retrato.
- [ ] Si caen todos: pantalla de derrota con resumen.

## Minutos 27–30: anotá
Una línea por tema, aunque sea corta:
- **Ritmo:** ¿cuántas puertas abriste antes de tener miedo de abrir otra?
- **Economía:** ¿qué recurso sobró o faltó?
- **Lectura:** ¿sabías siempre qué pasaba y por qué perdías vida?
- **Ayudas:** ¿alguna llegó tarde, sobró o tapó algo?
- **Lo peor de los 30 minutos:** una sola cosa.

## Guardado entre pisos (5 min, aparte)
Sin conexión, en una ranura:
- [ ] Ganá el piso 1 y bajá al 2. Esc → Salir: el aviso dice que se pierde el piso y que se retoma desde el inicio del piso 2.
- [ ] En el menú, la ranura dice "PISO 2" y al elegirla ofrece "Continuar partida (piso 2)", "Nueva partida" y "Volver".
- [ ] Continuar: mismos héroes, nivel, equipo, mochila, recursos e investigación; el mapa del piso 2 es el mismo que antes.
- [ ] Perder (o elegir "Nueva partida" y empezar) borra el guardado: la ranura vuelve a "GUARDADA".

## Arte nuevo por licencias (3 min, aparte)
Capturas de referencia: `tests/tools/shot_licencias.gd` (HUD, Reliquia, ficha, mochila).
- [ ] En pelea a zoom normal, ¿se ven el tajo, las chispas y el polvo de muerte? (los efectos propios son más chicos y simples que los de antes)
- [ ] Grito de Guerra, escudo del Paladín, subir de nivel y curar: ¿el anillo de color se distingue de cada uno?
- [ ] La Reliquia (gema roja) se lee como objeto valioso sobre el suelo y mientras se la lleva.
- [ ] Mochila y equipo: ¿se distinguen las 7 armaduras (escudos por color) y las espadas?

## Animaciones y efectos nuevos (3 min, aparte)
Captura de referencia: `tests/tools/shot_juego21.gd` (`j21_fx`).
- [ ] Al pegar, el héroe y el enemigo dan un pasito hacia el otro. ¿Se nota sin marear con 4 héroes?
- [ ] Un héroe caído se vuelca de costado (no salta de golpe) y se levanta al reanimarlo.
- [ ] El enemigo que muere cae de costado y se desvanece junto al polvo.
- [ ] Encender una sala: llamas doradas en el centro. Recoger la Reliquia: anillo dorado. Enemigos que aparecen: portal rojo. Abrir una puerta: polvo.
- [ ] Muros: algunos ladrillos gastados en salas y pasillos. ¿Se ven como variación o como error?

## Movilidad y jefe (juego-22, 5 min, aparte)
Capturas de referencia: `tests/tools/shot_movilidad.gd` (`j22_party`, `j22_corridor`, `j22_vertical`).
- [ ] Con 4 héroes (2 + 2 reclutas) en un pasillo vertical, se ordenan a lo largo del pasillo, dentro de los muros. En una sala vuelven a quedar lado a lado.
- [ ] Mandá a un héroe lejos y, mientras camina, hacé clic derecho en otra sala: la tarjeta dice "Ya hay una orden en curso" y el héroe sigue su camino. ¿Molesta, o preferirías que cambie de rumbo? (está en Propuestas de `docs/BALANCE.md`)
- [ ] El portador de la Reliquia camina más lento (×0,85). ¿Se nota?
- [ ] **Jefe del piso 3 con vida real**: en la captura de juego-23 (`tests/tools/shot_jefe.gd`, sin órdenes) un par de nivel 2 con vida llena lo gana solo junto a una Ballesta, por 4 de vida; sin ella cae a los 9 s. Jugándolo de verdad (esquivando la Embestida, llegando curado): ¿se puede? ¿Hubo que llevarlo hasta una torre? Si es una pared, decidir: ayuda de texto, bajarle la vida o curar antes de la salida.
- [ ] Co-op de 3-4 jugadores: cada jugador entra con su héroe (antes los jugadores 3 y 4 entraban sin héroe).
- [ ] **Jefe, juego-24**: el simulador supone que esquivás la mitad de las Embestidas (moverte cuando se pone rojo) y que te curás con Comida antes de pelear. Según el modelo, en Normal se gana junto a una Ballesta y nunca a oscuras. ¿Esquivás más o menos que la mitad? ¿Lo llevaste hasta una Ballesta sin que te lo digan? En la ventana, `tests/tools/shot_jefe.gd -- <dir> esquiva_ballesta` lo gana con el Guerrero en 18 de vida.
- [ ] **Armadura** (juego-24): equipá la coraza de acero al Guerrero. La hoja muestra «Armadura +1» y los golpes de 2 le sacan 1. ¿Se nota en los pisos 1-2? ¿Se entiende que tiene menos vida que antes (+5)?

## Fuera de esta prueba
Co-op real, Steam con dos cuentas y mando físico siguen sin probar (`docs/COOP_PRUEBAS.md`). Pisos 3 y 5 con jefe, la extracción con oleadas altas y el rendimiento con 4 héroes quedan para la partida larga.

## Editor
`project.godot` guarda la rotación de logs y la versión. Si el editor estaba abierto mientras se editó y guarda sus ajustes viejos, los pisa: `test_estabilizar` falla en "log rotation" si eso pasa. Solución: cerrar el editor, `git checkout project.godot`, reabrir.
