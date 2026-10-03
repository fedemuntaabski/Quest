# Economía (session economia-8)

Cuatro recursos, cada uno con un rol y al menos un sumidero. Números: `docs/BALANCE.md` "Economía".

| Recurso | Produce | Gasta | Para qué |
|---|---|---|---|
| **Industria** | Puertas (bono aleatorio), **Forja** (+3/puerta), cofres de sala Botín | Construir módulos (costo creciente), **reparar** módulos | Construye |
| **Ciencia** | Puertas (bono), **Scriptorium** (+3/puerta), sala Élite, pasiva del Mago | **Investigar** (módulos y bonos) | Investiga |
| **Comida** | Puertas (bono), **Granja** (+3/puerta) | **Subir de nivel** héroes, **curar** héroes (`CharacterPopup`) | Nivel y vida |
| **Polvo** | Puertas (siempre), salas descubiertas, pasiva del Pícaro | **Energizar** salas (costo +2 por sala encendida) | Energía |

"Ciclo" = una puerta abierta. El contador `+N` del HUD (`ResourceManager.get_turn_yield`) suma lo que pagan los generadores por ciclo.

## Módulos (`resources/modules/*.tres`, `ModuleDef`)
| Módulo | Slot | Tier | Costo base | Efecto |
|---|---|---|---|---|
| Forja / Granja / Scriptorium | Mayor (1 por sala) | 1 | 6 | +3 Industria / Comida / Ciencia por puerta |
| Ballesta | Menor | 1 (investigar) | 4 | 15 de daño / 1 s |
| Brasero (antes Trampa) | Menor | 1 (investigar) | 3 | Ralentiza 50 % 3 s |
| Catapulta | Menor | 2 (investigar, req. Ballesta) | 8 | 25 de daño en área, 1 golpe / 3 s |
| Trampa de pinchos | Menor | 1 | 3 | 10 de daño al enemigo que entra; funciona sin energía |

- **Costo creciente**: `ModuleCostCurve` (`resources/modules/module_cost_curve.tres`): `base + round(base * step * ya_construidos_de_ese_tipo)`, `step` 0.25. Cuenta por piso (`RoomManager.count_modules`).
- **Desmontar** devuelve el 50 % de lo que costó (`Module.paid_cost`). **Reparar**: `base * repair_pct * HP_faltante/HP_max` Industria (mín. 1). Ambos desde el popup que abre el click sobre un módulo construido (`ModulePopup`).

## Investigación
- `ModuleResearch` (`ResearchEntry` con `tier` 1-3, `UNLOCK_MODULE`) en `research_config.tres`, junto a los 5 bonos. Bloqueados al inicio: Ballesta (8), Brasero (6), Catapulta (18, req. Ballesta). Granja/Forja/Scriptorium/Pinchos nacen libres.
- Estado de la run: `ResearchState` (en `ResourceManager`), se reinicia en `Main._begin_new_run`, sobrevive a los pisos.
- Investigar es instantáneo y **exige un Scriptorium construido y activo** ("Construí un Scriptorium").
- Menú de construcción: pestañas **Mayores / Menores / Investigación** (atajos B / V / R, 1-9 elige tarjeta). Un módulo bloqueado muestra candado, "Requiere: X" y el costo en Ciencia.

## Brechas encontradas y cierre
- Comida solo subía de nivel → ahora también cura (`PlayerStats.heal_hero`, 0.15 Comida por HP faltante).
- Ciencia era un árbol finito sin requisito → ahora hay que construir Scriptorium (la Ciencia deja de ser "gratis": hay que invertir Industria antes).
- Industria construía a costo plano (sin sumidero tardío) → costo creciente + reparar.
- `science_generator` (desbloqueaba Gen. Ciencia) contradecía "investigar requiere Scriptorium" → el Scriptorium nace libre.

## No verificado en el motor (ventana real)
Ver `CLAUDE.md` "Session economia-8": layout de las 3 pestañas y del popup, ícono placeholder en tarjetas, click sobre módulo vs. click de sala, atajos B/V/R, pinchos sobre un `Enemy` real (solo hay test de catapulta), tooltip.
