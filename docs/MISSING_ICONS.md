# Íconos que faltan

Todos 16×16 (se dibujan ×2 = 32×32, `ArtConfig`). Cada uno tiene un **placeholder** `assets/art/ui/placeholder_<nombre>.png` (color por categoría + X, generado por `tools/normalize_assets.gd`). Al conseguir el arte real: guardarlo como `assets/art/ui/<nombre>.png` y cablearlo; borrar el placeholder. Estilo pedido: medieval oscuro, contorno oscuro, paleta apagada (como 0x72/Kenney), **no** el estilo saturado de Raven.

Hoy ninguno de estos íconos está cableado en la UI (todo se dibuja con `Polygon2D`/`StatIcon` vectorial o con texto); los placeholders dejan el asset listo para cuando se conecten.

## Faltan (29)
| Placeholder | Dónde se usa | Qué dibujar |
|---|---|---|
| `gen_industry` | `Module.CATALOG` GENERATOR_INDUSTRY: carta de `BuildingMenu`, fantasma del slot, `Module.Icon` (hoy `Polygon2D` gris) | engranaje / yunque |
| `gen_food` | GENERATOR_FOOD (hoy `Polygon2D` rojo) | hongos / huerto |
| `gen_science` | GENERATOR_SCIENCE (hoy `Polygon2D` violeta) | instrumento arcano / astrolabio |
| `turret` | TURRET "Ballesta" | ballesta |
| `trap` | TRAP "Trampa" | trampa de pinchos / cepo |
| `nexo` | `Nexo`/`NexoController`, `ExitIndicator` portando el Nexo, minimapa (hoy flask azul 0x72 como cristal) | cristal grande. Candidato: gema de `items/cave_gems.png` |
| `res_industry` | `StatIcon` "industry" (resource bar, tooltips, costes del menú de construcción) | lingote / engranaje |
| `res_food` | `StatIcon` "food", coste de subir de nivel | pan / pata de carne |
| `res_science` | `StatIcon` "science", investigación | pergamino / frasco violeta |
| `res_dust` | `StatIcon` "dust", `RoomZone.POWER_COST` | polvo brillante (hoy sirve `coin_anim_f0` de 0x72 como parche) |
| `res_lock` | `StatIcon` "lock", cartas bloqueadas de `BuildingMenu.get_lock_reason()` | candado |
| `room_start` | `RoomTypeVisual` START ("Inicio"): insignia de sala y minimapa (sin ícono hoy) | hoguera / puerta |
| `room_exit` | `RoomTypeVisual` EXIT ("Salida") (sin ícono; parche posible: `floor_stairs` de 0x72) | escalera |
| `status_slow` | efecto de la Trampa sobre enemigos (`Enemy.apply_slow`), sin indicador | gota / cadena / reloj de arena |
| `research_science_generator` | `ResearchEntry` "Instrumental arcano" (`ResearchPanel`, sin campo de ícono) | astrolabio |
| `research_turret_plans` | "Planos de ballesta" | plano / ballesta |
| `research_generator_tuning` | "Engranajes afinados" | engranaje con chispa |
| `research_dust_lenses` | "Lentes de polvo" | lente |
| `research_cartography` | "Cartografía" | mapa / brújula |
| `research_generator_overclock` | "Sobrecarga" | rayo / engranaje al rojo |
| `research_turret_rifling` | "Virotes estriados" | virote |
| `ability_warrior_passive` | `CharacterData.passive_ability_name` "Piel de Hierro" (popup, selección de héroe) | pecho blindado |
| `ability_warrior_active` | "Grito de Guerra" | boca gritando / cuerno |
| `ability_mage_passive` | "Mente Analítica" | ojo / cerebro |
| `ability_mage_active` | "Sobrecarga de Módulo" | rayo sobre engranaje |
| `ability_rogue_passive` | "Paso Ligero" | bota alada |
| `ability_rogue_active` | "Golpe Furtivo" | daga |
| `ability_tank_passive` | "Muro Viviente" | muro / escudo torre |
| `ability_tank_active` | "Interposición" | escudo con flecha |

## Ya cubiertos (no hacen falta placeholders)
| Ícono | Dónde | Fuente |
|---|---|---|
| Vida / corazón | popup, portraits | 0x72 `ui_heart_full/half/empty` (`assets/art/items`) |
| Ataque | popup | `weapons/weapons.png` (cualquier espada) |
| Descanso, Botín, Élite, Generador (parche) | `RoomTypeVisual` | 0x72 `flask_big_red`, `chest_full_open_anim_f0`, `weapon_double_axe`, `button_blue_up` (Generador: parche, conviene ícono propio) |
| Objetos (armas, armaduras, pociones, grimorios) | cofres, `Pickup`, popup "Hallazgos" | `items/`, `armor/`, `weapons/` (ver `resources/items/`) |
| Estados genéricos animados (alerta, ataque+, defensa+, magia+, veneno, curación, aceleración) | futuros buffs/debuffs | `art/vfx/` (`symbol_*`, `spell_*`, `status_*`) |

## Raven Fantasy Icons
Descartado como fuente por estilo (saturado, contorno grueso) y licencia sin verificar (ver `CREDITS.md`). Si se verifica la licencia, puede cubrir `res_*`, `research_*` y `ability_*` cuando se elijan íconos a mano de `Full Spritesheet/16x16.png` (celdas de 16×16, 16 columnas).
