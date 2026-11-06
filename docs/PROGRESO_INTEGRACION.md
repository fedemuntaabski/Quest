# Cierre de session/primera-partida-16

Sin cambios de balance ni contenido.

- **Reescritura del editor commiteada** (`chore`): uids, orden de propiedades, defaults omitidos, líneas `= null` fuera de `map_visual_config.tres`. Ningún valor cambió. Rama subida a `origin`.
- **Flecha de salida**: `ExitIndicator.above()` recorta el rectángulo de borde en `HUDController.get_bottom_bar_top()` (tope de la BottomBar visible, con BuildingMenu abierto o cerrado). Test: `tests/test_exit_arrow.gd`.
- **Arte de la Reliquia**: gema roja de `assets/art/items/cave_gems.png` (`Pickup.RELIC_REGION`), elegida entre gema, evangeliario y cráneo. Licencia desconocida: reemplazar antes de publicar (`docs/ASSETS.md`).

## Crash al cerrar (OK*): es de Godot 4.6.2

`signal 11` después de la última línea del test, intermitente. Decisión: se documenta, no se parchea.

| Prueba | Crashes |
|---|---|
| `test_map_flow` tal cual | 3/16, 11/20, 8/20, 5/20 (editor cerrado) |
| Proyecto Godot vacío, `quit()` | 0/60 |
| Vacío + 13 autoloads triviales | 0/60 |
| Quest, sólo autoloads (sin `Main2d`) | 4/30, 7/40, 3/40 |
| Quest sin ningún autoload | 0/40 |
| Sin Steam (`steamInitEx` salteado) / sin GodotSteam / sin file logging | 2/20, 4/20, 3/40 |
| Todos los nodos liberados a mano antes de `quit()` | 3/60 |
| Bajo un debugger (Win32 Debug API) | 0/40 |
| Vaciar las static vars con objetos (en `_exit_tree`, `PREDELETE` o antes de `quit()`) | 6/20, 6/20, 3/20 |
| El script del test **nombra** `InputBindings`, `CharacterDatabase` o `VfxEffect` (sin hacer nada) | 0/30 cada una |

Lectura: el crash ocurre en el desmontaje del motor, después de todo nuestro código y aun sin nodos vivos; desaparece bajo debugger (carrera de tiempos) y depende sólo de qué objetos `GDScript` siguen referenciados al salir, no de ningún dato ni lógica nuestra. No usamos hilos ni código nativo. El patrón que lo esquiva (referenciar clases desde el script principal) no es un arreglo, así que no se aplicó. `tests/run_all.gd` ya distingue OK* (aserciones pasadas, crash al salir) de FAIL. Si Godot sale con una versión nueva, medir de nuevo con el mismo bucle.

---

# Session calidad-13 (rama `session/calidad-13`)

Pedido: estabilidad y comodidad sin sistemas nuevos (7 bloques). Cerrada en `session/estabilizar-14`.

## Estado por bloque

| # | Bloque | Estado | Dónde |
|---|---|---|---|
| 1 | Rendimiento | **Hecho** | `docs/RENDIMIENTO.md`, `tests/tools/bench_floor5.gd`, `docs/perf/*.csv`. El cuello de botella eran los logs INFO por golpe/muerte: p99 37 → 7,6 ms en ventana |
| 2 | Pruebas automáticas | **Hecho** | Hecho: `tests/test_smoke_scenes.gd` (menú, Opciones con 5 pestañas, ranuras, selección, piso, pausa + ayuda, derrota/reintento, victoria, vuelta al menú, consola limpia vía `tests/support/ErrorProbe.gd`) |
| 3 | Guardado | **Hecho** | `SafeConfig` (tmp + rename, `.bak`, `.corrupt`), `SaveManager.SAVE_VERSION` 2 + `migrate()`, `save_corrupted` → diálogo en ranuras, settings atómico. `tests/test_save.gd` |
| 4 | Controles | **Hecho** (falta prueba manual) | `InputBindings`, pestaña Controles en Opciones (`settings.cfg [input]`), `VirtualCursor` (stick der. + A/B/X), LB/RB/LT/RT y Shift+Tab ciclan héroes, Back = menú de pausa, `ControlsHelp` (H, pausa, Opciones), B/V/R/T/H como acciones. `tests/test_input_bindings.gd` |
| 5 | Accesibilidad | **Hecho** (falta prueba manual) | `Accessibility` (estáticos) + pestaña Accesibilidad: texto 80–150 % (`Accessibility.font()` + escalado de .tscn al instanciar), modo daltónico (Okabe-Ito + glifos ▲/! en barras, formas ●■▲◆★ en rarezas), reducir destellos (+ temblor a 0), subtítulos de avisos sonoros. `tests/test_accessibility.gd` |
| 6 | Errores y registro | **Hecho** | Hecho: conexiones duplicadas en `Enemy.configure`; audio faltante, Steam ausente y "no save to delete" pasan a INFO; timestamp en `QuestLogger`; botón "Abrir carpeta de registros" |
| 7 | Balance | **Hecho** | `PlayerScaling` (`resources/floors/player_scaling.tres`): oleada ×1/1/1,5/2, tope +0/0/4/8, Reliquia ×1/1/1,15/1,3, amenaza ×1,05 con 2 jugadores. `BalanceSim.scaling_rows()` (5 pisos × 2 dificultades × 1–4 jugadores, paridad 1,00–1,18), `docs/balance/calidad13_scaling.csv`, `test_balance._check_scaling` |

## Pendiente

Lo que quedó pendiente al cortar se cerró en `session/estabilizar-14`: runner único `tests/run_all.gd`, `tests/test_full_run.gd` (el fallo en pisos 3 y 5 era del test, que declaraba victoria con el jefe vivo), rotación de logs en `project.godot`, sección de escalado en `BALANCE.md` y `CLAUDE.md`.

## Requiere prueba manual

- **Mando físico**:
  - cursor virtual, deadzone, velocidad;
  - A/B/X sobre salas, puertas y retratos;
  - gatillos para ciclar héroes;
  - foco en el menú de pausa (Back);
  - navegación por los menús con la cruceta.
- **Remapeo**: capturar tecla y botón, conflictos, Esc para cancelar, descartar sin guardar.
- **Legibilidad**:
  - texto al 150 % en HUD, popups y Opciones (hay layouts que pueden desbordar);
  - modo daltónico a la vista;
  - reducir destellos durante una invasión y con la Reliquia bajo ataque;
  - subtítulos.
- **Diálogo de guardado dañado** en la pantalla de ranuras (corromper a mano `user://slot_1.cfg`).
- **Co-op real de 4** con `PlayerScaling`: oleadas más grandes y tope de 22–24 enemigos.

---

# Progreso de la integración (rama `session/impl-6`)

Implementación de `docs/PROPUESTA_INTEGRACION.md` en el orden de la tabla 5.2: 0 → 3A → 3B → 4 → 1 → 2A → 2B, más la auditoría de Investigación. Estado al cierre: **todas las fases hechas**; lo único pendiente es lo que exige abrir el juego (sección 3).

Verificación de cierre (headless, Godot 4.6.2): `tools/run_tests.sh` → 26 tests, 0 fallos (`test_enemy_roles.gd` y `test_raider_timing.gd` sin editar); `Main2d.tscn --quit-after 90` sin `SCRIPT ERROR`; `gdparse` sobre los `.gd` tocados sin errores.

## 1. Estado por fase

| Fase | Estado | Commits (resumen) | Notas |
|---|---|---|---|
| 0 Red de seguridad | **Hecha** | `91f9abb` runner `tools/run_tests.ps1/.sh`; `f36da54` test_hud_ui/overlays sin falsos verdes | Un comando, exit ≠ 0 si falla alguno |
| 3A TargetSelector | **Hecha** | `afd41dd`, `88826a9` | Refactor sin cambio de comportamiento; BalanceSim idéntico antes/después (`docs/balance/impl6_before_*` vs. después, `Get-FileHash`). `Enemy` expone `killed_by_damage` |
| 3B Perfiles de objetivo | **Hecha** | `501791d`, `54d06fd` | 5 perfiles (asedio, cazador, saboteador, rompe-torres, asesino) en `resources/enemies/profiles/`; HP visible de obras; `ENEMY_TARGETING.md` y `BALANCE.md` actualizados; BalanceSim idéntico (+ columna `towers`) |
| 4 Bestiario | **Hecha** | `6e36a73`, `ea52d19`, `822bfd9`, `055937f`, `9c360dc` | `BestiaryService` (autoload), sección `[bestiary]` por slot; "visto" = primer spawn, 1 kill, 3 kills; una kill cuenta solo por daño de héroe/defensa (nunca por `queue_free` al cambiar de piso). Campos muertos de `SaveManager` limpiados en la misma fase |
| 1 Perks de héroe | **Hecha** | `a39e692`, `ae2d937`, `87572eb`, `c0ae89e` | 16 `HeroPerk`, 1 de 2 en niveles 3 y 5, sección "Mejoras de clase", punto dorado en el retrato |
| 6.1 Tope de vida | **Hecha** | `8e04334` | `PLAYER_MAX_HP` 60 → 120; BalanceSim idéntico (nota en `BALANCE.md`) |
| 2A Inventario (datos + stats + cofres) | **Hecha** | `4988c7c`, `6fc4d7a`, `bba8d4d`, `e0fbfd1`, `a251a92` | `PartyInventory` (autoload), `ItemStack`, `InventoryComponent`, tercera capa base → nivel → equipo en `PlayerStats`, `Chest`, `LootSpawner` por `loot_chance`, botín de fin de piso |
| 2B UI de equipo | **Hecha** | `998b41e`, `b505f37`, `3027ced`, `b70d95e`, `a95144b` | `EquipmentSection` en `CharacterPopup` (reemplaza "Hallazgos"), atajo de consumible en `HeroPortrait`, contador "Mochila n/20" |
| Auditoría de Investigación | **Hecha** (análisis + 2 arreglos) | `0e15501`, `f7fadca` | `docs/INVESTIGACION_AUDITORIA.md`: ningún bug ROTO; aplicados I-01 (aviso "Investigado: X") e I-07 (comentario). El resto queda abierto a propósito (sin rediseño) |

## 2. Decisiones de la sección 6 y cómo quedaron

Tope 120 (6.1) · slots arma 1 / armadura 1 / reliquia 1 / consumible 2 y mochila de 20 (6.2) · el equipo persiste entre pisos y se resetea en cada run (`Main._begin_new_run` → `clear_found_items()` → `PartyInventory.reset()`) (6.3) · sin stats nuevos: solo `hp`, `attack_damage`, `attack_interval`, `attack_range` (6.4) · perks 1 de 2 (6.5) · umbrales del bestiario (6.6/6.7) · bestiario por slot, solo en la pausa (6.8/6.11) · consumibles bloqueados con `Engine.time_scale` 0 (6.9) · clic, sin drag & drop (6.12) · sin enemigos con arte fuera de estética (6.10) · texto en español inline (6.14).

Cofres (pedido aparte): `RoomTypeRule.loot_chance` (Botín 1.0, Élite 0.7, Descanso 0.1, Taller 0.15) y `FloorConfig.default_loot_chance` 0.08 para el resto; Inicio y Salida nunca; botín de fin de piso `floor_end_loot_chance` 1.0 (directo a la mochila). El cofre (`Chest.gd`, sprites Kenney cerrado/abierto, caja dibujada en código si falta la hoja) se abre al entrar un héroe, muestra el ítem con marco/color de rareza y lo manda a `PartyInventory`; con la mochila llena queda cerrado y avisa ("Mochila llena" + aviso del HUD).

Desviaciones menores respecto a la propuesta:
- **Sin toast "Obtenido: X"** al recibir un ítem: el cofre ya muestra "nombre (rareza)" y el botín de fin de piso ya usa `show_hint`; un tercer aviso era redundante. El HUD solo actualiza el contador de mochila.
- `PlayerStats.found_items`/`add_found_item`/`clear_found_items`/`found_items_changed` **siguen existiendo** como alias de `PartyInventory` (los usan `Main._begin_new_run` y `test_items.gd`); se retiran cuando alguien migre esos dos llamadores.
- `Pickup.Kind.CHEST` queda solo para `test_items.gd`; los cofres de sala son `Chest` (ya no `Pickup`).
- Las pociones usan multiplicadores por fuente en `CharacterStats` (`set_attack_mult_source`/`set_interval_mult_source`) para no pisar las habilidades de héroe; se añadió `SPEED_BUFF_TIMED`.
- El atajo de consumible del retrato es un botón por consumible equipado (clic = usar), sin tecla.

## 3. Lo que NO se pudo verificar sin ejecutar el juego

Todo lo anterior se probó headless (los tests ven el estado y las señales, no el layout). Falta mirar en una ventana real:
- Que el popup del héroe, ahora con "Mejoras de clase" + "Equipo" + mochila de 20 celdas, **entre en pantalla** (sin scroll; a 1280×720 puede quedar alto).
- Aspecto del cofre en la sala (tamaño, posición `CHEST_OFFSET`, animación del ítem al abrir, texto flotante, que el marco de rareza se lea) y el caso "mochila llena".
- Aspecto y tamaño de los botones de consumible bajo el retrato, el contador "Mochila n/20" en la barra inferior y los tooltips con comparación.
- Que el bestiario en la pausa se vea bien y que Esc/Volver y `Engine.time_scale` se comporten (cubierto por tests, no visualmente).
- Balance con equipo: BalanceSim **no** simula equipo ni perks; un héroe con armadura de +30 y arma legendaria no se midió. Las armaduras con tope 120 son las más sensibles.
- Con Steam multijugador: el inventario es local (sin replicación), igual que la investigación (I-13).
- Licencias ⚠ de las hojas de ítems (auditoría de assets §7): el inventario vuelve visibles esos iconos; resolver antes de publicar.

## 4. Checklist de pruebas manuales en el editor (F5 por `Main.tscn`)

Equipo
1. Nueva partida, abrir un cofre (sala Botín): el cofre pasa de cerrado a abierto, el ítem flota con marco del color de su rareza y aparece "nombre (rareza)"; el contador pasa a "Mochila 1/20".
2. Clic derecho en un retrato → "Equipo": clic en el ítem de la mochila lo equipa; la vida/daño/intervalo de la ficha cambian; el tooltip muestra "Frente a X: …".
3. Clic en el slot ocupado lo desequipa. Un ítem restringido (p. ej. túnica del Mago/Pícaro en el Guerrero) muestra la razón en rojo.
4. Subir de nivel con equipo puesto: el bonus del equipo se mantiene.
5. Llenar la mochila (20) y entrar en otra sala con cofre: queda cerrado + aviso. Desequipar con la mochila llena: "Mochila llena".
6. Consumible: equipar una poción, "Usar" desde la ficha y el botón del retrato; en pausa táctica (Espacio) aparece "No se puede usar en pausa táctica"; el cooldown atenúa el botón.
7. Cambiar de piso: el equipo y la mochila persisten; Retry/nueva partida los vacía.
8. Final de piso: aparece el aviso "Botín del piso" (o "perdido" si la mochila está llena).

Resto de la integración
9. Perks: al llegar a nivel 3 el retrato muestra el punto dorado; elegir 1 de 2 cambia el stat/habilidad indicado.
10. Bestiario (pausa): una ficha se desbloquea al primer spawn (nombre/sprite), 1 kill (stats), 3 kills (todo); reiniciar el juego conserva el progreso; slots independientes.
11. Enemigos: asesinos van a por héroes, rompe-torres a por defensas, saboteadores a obras; una obra dañado muestra su vida.
12. Investigación: abrir "Investigar", comprar "Instrumental arcano" → aviso "Investigado: …", la tarjeta del Gen. Saber se desbloquea.

## 5. Pendiente / abierto (no bloquea)

- Auditoría de Investigación: I-02..I-06 (orientación del primer gasto, números de tarjetas sin bonus, "+N" del HUD sin Mago/Élite, atajo/aviso de comprable, rebuild del panel) e I-08..I-13 (balance de Saber y multijugador). Requieren decisión de diseño.
- Retirar el alias `found_items` de `PlayerStats` (ver sección 2).
- Armadura plana como stat nuevo (6.4) y arte de armadura sobre el sprite del héroe: fuera de alcance.
- Drag & drop del inventario (6.12) y bestiario también en el menú principal (6.11): fuera de alcance.
- Session bucle-7 (puertas, luz, extracción, pausa 1x/2x): cambios, tablas y lista de lo no verificado en `docs/BUCLE_JUEGO.md`; números en `docs/BALANCE.md` "Bucle".
