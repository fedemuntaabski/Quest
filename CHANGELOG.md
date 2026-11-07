# CHANGELOG

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
