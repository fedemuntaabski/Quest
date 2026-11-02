# Guía de playtest: una run completa

Una run de 5 pisos nunca se jugó de corrido. Todo el balance sale del simulador, así que lo que más vale ahora es tu sensación. Calculá unos 60–90 minutos; podés anotar y seguir.

## Antes de empezar
1. Reiniciá el editor si estaba abierto durante esta rama (ver "Editor" al final) y arrancá con F5, no F6.
2. En Opciones activá el contador de FPS si querés mirar rendimiento.
3. Ranura nueva, Offline, Guerrero + Mago, Normal.

Si algo se rompe, anotá piso y qué hacías, y adjuntá el `quest.log` más reciente (Opciones → Accesibilidad → "Abrir carpeta de registros"; se guardan los últimos 10).

## Primer piso: controles (5 min)
- [ ] Clic izquierdo selecciona; clic derecho mueve. Clic izquierdo en una sala vacía no hace nada.
- [ ] Clic central enciende una sala al soltar; arrastrando con el botón central mueve la cámara y no enciende.
- [ ] Espacio congela combate y deja dar órdenes de caminar; las puertas no abren en pausa.
- [ ] **Esc en pleno combate:** nada se mueve, nadie pierde vida, no llegan oleadas. Esc de nuevo reanuda. Con el Bestiario abierto, Esc cierra solo el Bestiario.

## Durante la run: bugs arreglados en esta rama
- [ ] Bajá a un héroe y subile de nivel o equipalo: **sigue caído**. Reanimar sigue costando Comida y pide un aliado en la sala.
- [ ] Al reanimarlo vuelve a la selección si estaba elegido, y a sus grupos Ctrl+1..3.
- [ ] Cruzá un corredor con trampa **sin detenerte**: salta igual. Cruzá una sala con cofre sin detenerte: se abre.
- [ ] Si cae un héroe caminando, se queda donde cayó, no sigue deslizándose.
- [ ] Si cae el portador en un corredor, el Nexo queda ahí. Otro héroe lo recoge yendo a ese corredor.
- [ ] Durante la pantalla de victoria, el mundo queda congelado. Dejala abierta un minuto con enemigos cerca: no puede volverse derrota.

## Lo que solo vos podés juzgar
Anotá por piso, aunque sea una línea:
- **Ritmo:** ¿cuántas puertas abrís antes de tener miedo de abrir otra? ¿Sobra o falta tiempo?
- **Economía:** ¿te sobra o te falta Polvo, Industria, Comida, Ciencia? ¿Alguno no lo usaste nunca?
- **Módulos:** ¿construiste los 7? ¿Cuál no valió la pena?
- **Dificultad:** vida perdida por piso. El simulador predice piso 1–3 tranquilos y salto fuerte en 4–5 (28 % → 230 % de pérdida sin torres ni niveles).
- **Jefes (pisos 3 y 5):** ¿se entiende que custodian la salida? ¿Es justa la embestida?
- **Extracción:** ¿da tensión o es solo caminar? ¿15 % más lento se nota?
- **Lectura:** ¿sabías siempre qué estaba pasando y por qué perdiste vida?

## Fuera de esta prueba
Co-op real, Steam con dos cuentas y mando físico: siguen sin probar (`docs/COOP_PRUEBAS.md`). Vocabulario medieval y la vuelta de Nexo a Reliquia quedan para una fase posterior.

## Editor
Esta rama agregó la rotación de logs a `project.godot` con tu editor abierto. Si el editor guarda sus ajustes viejos, la pisa: `test_estabilizar` falla en "log rotation" si eso pasa. Solución: cerrar el editor, `git checkout project.godot`, reabrir.
