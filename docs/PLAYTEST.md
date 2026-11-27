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
- [x] ~~Abrí Investigación: las 3 pestañas se ven enteras.~~ Visto en `shot_barrido` (visual-24): ahora van dentro del mismo marco que las cartas.

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
- [ ] (juego-35) Mandá a un héroe lejos y, mientras camina, hacé clic derecho en otra sala: cambia de rumbo enseguida (vuelve al centro de la zona donde está y sigue). Probalo también en pausa táctica (Espacio): la última orden es la que vale al reanudar. Si aun así **un clic derecho no mueve a nadie**, anotá la semilla del piso y buscá en el log (`user://logs`) la línea `Click ignored: …` o `Move rejected: …`: dice por qué.
- [ ] (juego-35) Clic medio en la sala inicial (la de la Reliquia): no se apaga y sale "La sala de la Reliquia no se apaga". Las demás se prenden y apagan como antes, y arrastrar con el botón del medio no las prende.
- [ ] (juego-35) Puertas este-oeste: ahora giradas sin espejo (arco hacia afuera de la sala). ¿Se ven bien o preferís la opción B (todas derechas, como las de arriba)? Capturas en `capturas/juego-35/puertas_despues_f2f5.png` y `puertas_opcionB_f2f5.png`.
- [ ] (juego-35) Selección de héroes: pasá el mouse por los cuatro; la ficha muestra pasiva y activa con números, y con texto ×1,5 los botones de abajo siguen a la vista.
- [ ] El portador de la Reliquia camina más lento (×0,85). ¿Se nota?
- [ ] **Jefe del piso 3 con vida real**: en la captura de juego-23 (`tests/tools/shot_jefe.gd`, sin órdenes) un par de nivel 2 con vida llena lo gana solo junto a una Ballesta, por 4 de vida; sin ella cae a los 9 s. Jugándolo de verdad (esquivando la Embestida, llegando curado): ¿se puede? ¿Hubo que llevarlo hasta una torre? Si es una pared, decidir: ayuda de texto, bajarle la vida o curar antes de la salida.
- [ ] Co-op de 3-4 jugadores: cada jugador entra con su héroe (antes los jugadores 3 y 4 entraban sin héroe).
- [ ] **Jefe, juego-24**: el simulador supone que esquivás la mitad de las Embestidas (moverte cuando se pone rojo) y que te curás con Comida antes de pelear. Según el modelo, en Normal se gana junto a una Ballesta y nunca a oscuras. ¿Esquivás más o menos que la mitad? ¿Lo llevaste hasta una Ballesta sin que te lo digan? En la ventana, `tests/tools/shot_jefe.gd -- <dir> esquiva_ballesta` lo gana con el Guerrero en 18 de vida.
- [ ] **Armadura** (juego-24): equipá la coraza de acero al Guerrero. La hoja muestra «Armadura +1» y los golpes de 2 le sacan 1. ¿Se nota en los pisos 1-2? ¿Se entiende que tiene menos vida que antes (+5)?

## Menús y HUD con el barrido visual (visual-24, 5 min, aparte)
Capturas de referencia: `tests/tools/shot_barrido.gd -- <dir>` (cada pantalla en 1280x720, 1920x1080 y 1920x1080 con el texto al 150 %). Ya se vio en captura, no hace falta mirarlo: ~~Opciones con Guardar/Volver dentro del marco~~, ~~sala de espera entera en 1080p~~, ~~descripciones de héroes completas~~, ~~el texto al 150 % llega al HUD~~, ~~botones de red con la red real~~, ~~contador de FPS abajo a la izquierda~~, ~~diálogo "Partida en curso" y botones de victoria/derrota con marco dorado~~, ~~casillas de equipo con nombre~~.
Lo que solo se ve con input real:
- [ ] Opciones → Audio con el texto al 150 %: la rueda del mouse desplaza la pestaña y Guardar/Volver quedan quietos.
- [ ] Sala de espera con el texto al 150 %: se desplaza con la rueda hasta ABANDONAR.
- [ ] Con teclado o mando: Tab/flechas en el menú, ranuras, modo de red, Opciones y el diálogo "Partida en curso". ¿Se ve siempre qué botón tiene el foco?
- [ ] En 1280x720, ¿se leen las cartas de Investigación y la Mochila sin acercarse? (mínimo de texto 14 px de base)

## Mazmorra nueva (mazmorra-31, 5 min, aparte)
Capturas guionadas en `capturas/mazmorra-31/`; nada visto jugando.
- [ ] Salas en L y en cruz: clic derecho en un brazo lleva al héroe a la sala; clic en la esquina recortada no selecciona la sala.
- [ ] Columnas y pozos no estorban: los héroes no caminan por encima al entrar; en combate los enemigos sí pueden pararse sobre ellos (solo visual).
- [ ] El cartel del tipo y el ícono de luz no quedan sobre una esquina recortada.
- [ ] ¿Se distingue cada tipo por su luz al encenderla? (mazmorra-32 bajó el relleno dorado a 0,10).
- [ ] Minimapa: las salas con forma se dibujan con su forma y el tooltip sale solo dentro.
- [ ] La escalera de la Salida se ve debajo del hueco central.

## Decoración y luz (mazmorra-32, 5 min, aparte)
Capturas guionadas en `capturas/mazmorra-32/`; nada visto jugando ni en movimiento.
- [ ] Al encender una sala: la luz sube suave y las antorchas/braseros se prenden un instante después; parpadean sin ir al unísono; apagarla las apaga.
- [ ] Las salas sin descubrir no muestran luz, sombras ni antorchas; la luz de una sala encendida no pasa los muros y sí sale por la puerta al pasillo.
- [ ] Sala oscura todavía legible (suelo, props y héroes) con la capa oscura que late.
- [ ] Cada tipo con lo suyo: catres y brasero en Descanso, cadenas y grilletes en Prisionero, velas alrededor del Altar, musgo en la Secreta, sangre y huesos en Élite, estanterías en Taller.
- [ ] El Altar nuevo: gema y runa rojas; después de la ofrenda queda apagado.
- [ ] Prisionero con el grupo lleno (co-op de 4, u offline tras rescatar a los dos): aparece un cofre y se abre al entrar.
- [ ] FPS con 4 héroes y una oleada en el piso 5 (el bench midió ~1 ms de render extra en una GTX 1660 SUPER).

## Menú nuevo (menu-33/34, 5 min, aparte)
En menu-34 el dueño lo miró en movimiento y aprobó llamas, gema, brasas, parallax, marcador, aparición de paneles y foco con teclado. Queda:
- [ ] Opciones → Accesibilidad → "Reducir destellos": las llamas del fondo y del marcador quedan fijas.
- [ ] Con mando: el foco se ve siempre.
- [ ] Texto al 150 %, Esc en un piso: la pausa entra entera en su marco (arreglado en menu-34, visto solo en capturas).
- [ ] Sala de espera: sigue con su fondo viejo (tinte frío); si generás `sala_espera.png` con el mismo estilo, reemplaza a `Lobby Multijugador.png`.

## Fuera de esta prueba
Co-op real, Steam con dos cuentas y mando físico siguen sin probar (`docs/COOP_PRUEBAS.md`). Pisos 3 y 5 con jefe, la extracción con oleadas altas y el rendimiento con 4 héroes quedan para la partida larga.

## Editor
`project.godot` guarda la rotación de logs y la versión. Si el editor estaba abierto mientras se editó y guarda sus ajustes viejos, los pisa: `test_estabilizar` falla en "log rotation" si eso pasa. Solución: cerrar el editor, `git checkout project.godot`, reabrir.

## juego-36 (falta probar en ventana)
- Íconos de habilidades: legibles a 720p en el botón del retrato, en la ficha (CharacterPopup) y en la selección de héroe; solo vistos ampliados en capturas.
- Panel de Investigación: el precio baja con el Mago en pie y vuelve al caer/reanimarse.
- Bendición en una sala apagada: no paga ni potencia nada.
- Golpe Furtivo a 8 s: que no se sienta excesivo.
- Placas GUARDAR/VOLVER/LISTO/VOLVER (Créditos) a 720, 1080 y texto ×1,5.
- Siguen abiertos los ítems de juego-35 de más arriba.

## juego-44 (falta probar en ventana)
- Cartel de pistas: fondo opaco con borde dorado, 440 px de ancho a texto ×1 y hasta 640 px a ×1,5. Visto en capturas de juego-44 y de juego-45 (`capturas/juego-44/barrido_despues/`: Descanso, rechazo, «¡Sala secreta!»). Falta verlo jugando: que no tape demasiado mapa a ×1,5 y que una Oleada larga entre bien.
- Reliquia sola: ¿cuánto tarda el grupo en volver a la sala inicial cuando una oleada de puerta trae un saqueador? El modelo supone que nadie vuelve (`relic_left`, `docs/BALANCE.md`).
- Catapulta nueva (5 Hierro, 10 Saber, 35 de daño): si se siente fuerte contra grupos o si sigue sin valer la pena frente a la Ballesta.

## juego-45 (falta probar en ventana)
- Cartel de pistas, en ventana real con `shot_barrido.gd` (`capturas/juego-45/barrido/`, 720, 1080 y 1080x15): Descanso, rechazo («No alcanza el Hierro: faltan 12…») y «¡Sala secreta!» en el piso 5 con fondo opaco que cubre todo el texto. A ×1,5 en el piso 5 la barra del jefe queda pegada al borde de arriba del cartel y la flecha verde de la salida lo toca.
- **No jugado a mano:** el piso 1 con texto ×1,5 hasta ver una Invasión, un rechazo real y la pista de una sala especial. Esta sesión no tuvo control del mouse; lo de arriba es un script en ventana, no una partida.
- [ ] Con texto ×1,5: ¿el cartel de una Invasión tapa demasiado mapa? ¿Se lee el rechazo mientras se arma una Obra?
- [ ] Reliquia sola: ¿cuánto se aleja el grupo de la sala inicial y cuántos segundos tarda en volver cuando entra un saqueador? BalanceSim supone 5 s (`relic_back_sec`, `docs/BALANCE.md`).
