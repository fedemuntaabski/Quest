# Íconos que faltan

Todos 16×16 (se dibujan ×2 = 32×32, `ArtConfig`). Cada uno tiene un **placeholder** `assets/art/ui/placeholder_<nombre>.png` (color por categoría + X, generado por `tools/normalize_assets.gd`). Al conseguir el arte real: guardarlo como `assets/art/ui/<nombre>.png` y cablearlo; borrar el placeholder. Estilo pedido: medieval oscuro, contorno oscuro, paleta apagada (como 0x72/Kenney), **no** el estilo saturado de Raven.

Hoy ninguno de estos íconos está cableado en la UI (las habilidades ya existen desde balance-4 y sus íconos irían junto a la barra de enfriamiento del retrato); todo se dibuja con `Polygon2D`/`StatIcon` vectorial o con texto.

## Faltan (29)
| Placeholder | Dónde se usa | Qué dibujar |
|---|---|---|
| `gen_iron` | `Building.CATALOG` WORKSHOP_IRON: carta de `BuildingMenu`, fantasma del slot, `Building.Icon` (hoy `Polygon2D` gris) | engranaje / yunque |
| `gen_food` | WORKSHOP_FOOD (hoy `Polygon2D` rojo) | hongos / huerto |
| `gen_lore` | WORKSHOP_LORE (hoy `Polygon2D` violeta) | instrumento arcano / astrolabio |
| `defense` | DEFENSE "Ballesta" | ballesta |
| `trap` | TRAP "Trampa" | trampa de pinchos / cepo |
| `relic` | `Relic`/`RelicController`, `ExitIndicator` portando la Reliquia, minimapa (hoy la gema propia de `own/items.png`) | cristal grande. Cubierto en `licencias-20` por la gema propia |
| `res_iron` | `StatIcon` "iron" (resource bar, tooltips, costes del menú de construcción) | lingote / engranaje |
| `res_food` | `StatIcon` "food", coste de subir de nivel | pan / pata de carne |
| `res_lore` | `StatIcon` "lore", investigación | pergamino / frasco violeta |
| `res_embers` | `StatIcon` "embers", `RoomZone.LIGHT_COST` | brasas encendidas (hoy sirve `coin_anim_f0` de 0x72 como parche) |
| `res_lock` | `StatIcon` "lock", cartas bloqueadas de `BuildingMenu.get_lock_reason()` | candado |
| `room_start` | `RoomTypeVisual` START ("Inicio"): insignia de sala y minimapa (sin ícono hoy) | hoguera / puerta |
| `room_exit` | `RoomTypeVisual` EXIT ("Salida") (sin ícono; parche posible: `floor_stairs` de 0x72) | escalera |
| `status_slow` | efecto de la Trampa sobre enemigos (`Enemy.apply_slow`), sin indicador | gota / cadena / reloj de arena |
| `research_lore_workshop` | `ResearchEntry` "Instrumental arcano" (`ResearchPanel`, sin campo de ícono) | astrolabio |
| `research_defense_plans` | "Planos de ballesta" | plano / ballesta |
| `research_workshop_tuning` | "Engranajes afinados" | engranaje con chispa |
| `research_dry_tinder` | "Yesca seca" | lente |
| `research_cartography` | "Cartografía" | mapa / brújula |
| `research_workshop_bellows` | "Sobrecarga" | rayo / engranaje al rojo |
| `research_defense_rifling` | "Virotes estriados" | virote |
| `ability_warrior_passive` | `CharacterData.passive_ability_name` "Piel de Hierro" (popup, selección de héroe) | pecho blindado |
| `ability_warrior_active` | "Grito de Guerra" | boca gritando / cuerno |
| `ability_mage_passive` | "Mente Analítica" | ojo / cerebro |
| `ability_mage_active` | "Bendición de las Obras" | rayo sobre engranaje |
| `ability_rogue_passive` | "Paso Ligero" | bota alada |
| `ability_rogue_active` | "Golpe Furtivo" | daga |
| `ability_tank_passive` | "Muro Viviente" | muro / escudo torre |
| `ability_tank_active` | "Interposición" | escudo con flecha |

## Ya cubiertos (no hacen falta placeholders)
| Ícono | Dónde | Fuente |
|---|---|---|
| Vida / corazón | popup, portraits | 0x72 `ui_heart_full/half/empty` (`assets/art/items`) |
| Ataque | popup | espada de Kenney |
| Descanso, Botín, Élite, Taller (parche) | `RoomTypeVisual` | 0x72 `flask_big_red`, `chest_full_open_anim_f0`, `weapon_double_axe`, `button_blue_up` (Taller: parche, conviene ícono propio) |
| Objetos (armas, armaduras, pociones, grimorios) | cofres, `Pickup`, ficha del héroe | Kenney + `own/items.png` (ver `resources/items/`, `tools/build_items.gd`) |
| Estados genéricos animados | buffs | `art/own/vfx/` (`own_ring_*`, `own_sparkle_green`) |

## Raven Fantasy Icons
Descartado: licencia desconocida y estilo saturado. Retirado del repo en `licencias-20` (solo local, ver `docs/CREDITOS.md`).
