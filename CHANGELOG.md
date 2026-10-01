# CHANGELOG

## session/balance-4
- Balance con evidencia: `BalanceSim` + `tools/balance_sim.gd` (CSV en `docs/balance/`), `tests/test_balance.gd`, `docs/BALANCE.md`.
- Héroes con roles distintos (vida/daño/intervalo/rango en `.tres`), enemigos, crecimiento por piso y Nexo (120 PV) ajustados solo en datos.
- `EnemyType` gana stats base; torretas/trampa leen `Module.CATALOG`.
- Habilidades pasivas y activas por héroe (`AbilityData`, `HeroAbilities`, tecla Q, barra de enfriamiento). `tests/test_abilities.gd`.
- `VfxManager` (pool + tope), 7 escenas en `assets/vfx`, `VfxConfig`, temblor leve en `GameCamera`; conectado a combate, curación, mejora, construcción y habilidades. `tests/test_vfx.gd`.

## session/enemies-2
- Roles de enemigo (cazador/saqueador), Nexo con PV, grietas, alerta HUD/minimapa y derrota al llegar a 0; proporción de saqueadores por piso y llegada mínima.

## session/assets-4
- Packs nuevos normalizados (ítems, 42 FX curados en `assets/art/vfx`, 29 placeholders de íconos), `ItemData`/`ItemCatalog`, licencias en `CREDITS.md`.

## session/rooms-1
- Auditoría de salas: Rest cura a todo el grupo, sala Generador, textos/hints por tipo, `tests/test_rooms.gd`, `docs/ROOMS.md`.
