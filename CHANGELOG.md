# CHANGELOG

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
