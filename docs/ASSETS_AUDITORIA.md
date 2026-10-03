# Auditoría de íconos (session economia-8)

Íconos de módulos: `ModuleDef.icon_path`, dibujados en la tarjeta del menú de construcción (`BuildingMenu._make_card`). No hay arte final: todos son placeholders 16x16 (se dibujan a ART_SCALE) en `assets/art/ui/`.

| Módulo | Ícono usado | Estado |
|---|---|---|
| Forja | `placeholder_gen_industry.png` | placeholder |
| Granja | `placeholder_gen_food.png` | placeholder |
| Scriptorium | `placeholder_gen_science.png` | placeholder |
| Ballesta | `placeholder_turret.png` | placeholder |
| Brasero | `placeholder_trap.png` | placeholder |
| Catapulta | `placeholder_catapult.png` | **falta** (copia de `placeholder_turret.png`) |
| Trampa de pinchos | `placeholder_spikes.png` | **falta** (copia de `placeholder_trap.png`; hay `floor_spikes_anim_f0-3` en `_source` de 0x72 para el arte real) |

Faltan además: ícono de reparar y de desmontar (el popup usa solo texto) y pestañas con ícono. Los íconos de investigación de módulos (`Planos de ballesta`, `Forja de brasas`, `Ingeniería de asedio`) reutilizan los placeholders existentes `research_*` o no tienen ícono.
