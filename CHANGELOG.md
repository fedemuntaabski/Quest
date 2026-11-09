# CHANGELOG

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
