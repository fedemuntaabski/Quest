# CHANGELOG

## session/juego-30
- Si no alcanza la Comida para subir de nivel a un héroe, se paga con Saber: el doble (por ejemplo, 22 de Saber en vez de 11 de Comida). El botón muestra qué se va a pagar.
- Rescatar a un prisionero también se puede pagar con 15 de Saber en el piso 1 (+5 por piso).
- Versión 1.7: no se puede jugar en co-op con la 1.6.

## session/juego-29
- Difícil: los enemigos pegan ×1,1 (antes ×1,25) y se empieza con los mismos recursos que en Normal. El piso 4 deja de ser una pared (pares: ganan el piso 4 el 28 %, antes el 11 %).
- Rescatar a un prisionero cuesta 8 de Comida o 10 de Hierro en el piso 1 (antes 15 / 20), +5 por piso como antes.
- Versión 1.6: no se puede jugar en co-op con la 1.5.

## session/juego-28
- Difícil: los jefes (pisos 3 y 5) ya no tienen la vida y el daño extra de Difícil, solo los del piso.
- Co-op de 3 y de 4 jugadores: +10 y +20 de Comida en cada bajada de piso (desde el piso 2).
- Al bajar de piso, una tarjeta dice cuánta Comida se recibe («Provisiones»).
- Versión 1.5: no se puede jugar en co-op con la 1.4.

## session/juego-27
- Al bajar a los pisos 4 y 5 se reciben +30 de Comida.
- El Señor Demonio (jefe del piso 5) tiene 150 de vida (antes 220).
- Versión 1.4: no se puede jugar en co-op con la 1.3.

## session/juego-26
- Matar a un jefe (pisos 3 y 5) da +15 de Comida: alcanza mejor para reanimar, subir de nivel y curar antes del piso 4.
- Versión 1.3: no se puede jugar en co-op con la 1.2.

## session/visual-24
- Opciones: Guardar y Volver ya no se salen del marco; las pestañas largas se desplazan.
- Sala de espera: entra en pantalla en 1080p, las descripciones de los héroes se leen enteras y con texto grande se desplaza hasta Abandonar. "Vida" en vez de "HP".
- El tamaño de texto de Accesibilidad ahora agranda todo el HUD y los menús (antes parte quedaba igual). Ningún texto baja de 14 px de base.
- Botones de red: "CREAR PARTIDA" / "UNIRSE" con la red que se usa de verdad (Steam o red local).
- El contador de FPS pasa abajo a la izquierda (tapaba el primer retrato).
- Investigación se abre dentro del mismo marco que Mayores y Menores.
- Ficha del héroe: las casillas de equipo vacías dicen Arma, Armadura y Talismán debajo.
- "Partida en curso" y los botones de victoria y derrota con el marco dorado de los menús.
- Textos: "VACÍA", "1 partida", "Volumen al pasar el cursor".

## session/juego-24
- Armadura: las corazas de acero, dorada y de jade restan 1 a cada golpe recibido (mínimo 1) y dan menos vida (acero +5, dorada +7, jade +12). La hoja del héroe muestra la fila «Armadura».
- Versión 1.2: no se puede jugar en co-op con la 1.1.
- El simulador de balance pelea al jefe como se juega: antes de la extracción, curado con Comida y esquivando parte de las Embestidas. El jefe no cambió.

## session/juego-23
- Espada de acero pasa a Rara (antes Poco común, igual que la de hierro pero siempre mejor).
- Grimorio de mareas: el Mago ataca 0,3 s más rápido (antes 0,15 s).
- Coraza de acero: +23 de vida (antes +20, igual que la de cobre siendo épica).
- El simulador de balance construye Ballestas (con su investigación) y el jefe pega a todo el grupo, como en la partida; el jefe del piso 3 no cambió.

## session/juego-22
- Co-op de 3-4 jugadores: cada jugador entra con su héroe. Antes, el grupo se recortaba a 2 y los jugadores 3 y 4 no tenían héroe.
- En un pasillo vertical, el grupo se ordena a lo largo del pasillo, sin dibujarse sobre los muros; el anillo de selección acompaña.
- Tests nuevos de salas, movilidad y efectos de ítems y perks; el simulador de balance corre partidas completas (sin cambios de números).

## session/juego-21
- Hojas 0x72 y Kenney fuera de `assets/art/_source/` (ahora en `assets/art/tiles/`); `test_licencias` prohíbe `_source/` en runtime.
- Animaciones por código: embestida al atacar, héroe caído que se vuelca, enemigo que cae y se desvanece.
- Efectos propios nuevos: llamas al encender sala, anillo dorado al tomar la Reliquia, portal rojo al aparecer enemigos, polvo al abrir puerta.
- Muros: ladrillos gastados, masa de muro uniforme detrás de las tapas, banners sólidos. Co-op: el cliente ya no ve doble polvo de muerte.

## session/licencias-20
- Arte listo para publicar: armaduras, grimorios, espadas y pociones con arte Kenney/0x72 (CC0) o propio; la Reliquia es una gema roja propia; los efectos de combate son propios (sin unTied Games). Créditos actualizados.
- `tests/test_licencias.gd` falla si el juego referencia un archivo sin licencia conocida (tabla en `docs/CREDITOS.md`). Retoque del arte propio con LibreSprite (`tools/libresprite.sh`).

## session/medieval-15
- Vocabulario medieval en una pasada (textos, código, señales, `.tres`, docs): Reliquia, Brasas, Hierro, Saber, Obra, Taller, Defensa, Paladín, Bendición de las Obras, partida, hueco, Talismán. Ícono de llama en lugar del rayo. Sin cambios de mecánica ni balance.
- Premisa mínima en la selección de héroes (reliquias robadas de la abadía).
- `tests/test_vocabulario.gd` y guardado previo al renombre en `tests/test_save.gd`.

## session/balance-4
- Balance con evidencia: `BalanceSim` + `tools/balance_sim.gd` (CSV en `docs/balance/`), `tests/test_balance.gd`, `docs/BALANCE.md`.
- Héroes con roles distintos (vida/daño/intervalo/rango en `.tres`), enemigos, crecimiento por piso y Reliquia (120 PV) ajustados solo en datos.
- `EnemyType` gana stats base; defensas/trampa leen `Building.CATALOG`.
- Habilidades pasivas y activas por héroe (`AbilityData`, `HeroAbilities`, tecla Q, barra de enfriamiento). `tests/test_abilities.gd`.
- `VfxManager` (pool + tope), 7 escenas en `assets/vfx`, `VfxConfig`, temblor leve en `GameCamera`; conectado a combate, curación, mejora, construcción y habilidades. `tests/test_vfx.gd`.

## session/enemies-2
- Roles de enemigo (cazador/saqueador), Reliquia con PV, grietas, alerta HUD/minimapa y derrota al llegar a 0; proporción de saqueadores por piso y llegada mínima.

## session/assets-4
- Packs nuevos normalizados (ítems, 42 FX curados en `assets/art/vfx`, 29 placeholders de íconos), `ItemData`/`ItemCatalog`, licencias en `CREDITS.md`.

## session/rooms-1
- Auditoría de salas: Rest cura a todo el grupo, sala Taller, textos/hints por tipo, `tests/test_rooms.gd`, `docs/ROOMS.md`.
