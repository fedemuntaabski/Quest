# Menús: estilo visual (menu-33)

Cómo se ven el menú principal y todo su recorrido (ranuras, continuar, modo de red, héroes, Opciones, Créditos, sala de espera, pausa, diálogos). La navegación no cambió: `MainMenuFlow` sigue igual; esto es solo la capa visual.

## Piezas

| Pieza | Archivo | Qué hace |
|---|---|---|
| Paleta | `QuestPalette` (`CRYPT_*`, `RELIC_GOLD*`, `AGED_GOLD`, `EMBER`, `BANNER_RED*`) | piedra azul-verdosa de las ilustraciones, dorado de la gema, rojo de estandarte para peligro |
| Placa (botón) | `UiStyles.style_plaque_button(btn, danger, font_px, marker)` | piedra oscura, borde izquierdo más grueso, dorado envejecido (rojo si `danger`); hover = piedra cálida + resplandor de brasa (sombra); foco = anillo dorado pálido por encima del estado. Fuente EB Garamond vía `Accessibility.font`. |
| Marcador | `MenuButtonDecor` (hijo **interno** del botón, no sale en `get_children()`) | rombo dorado a la izquierda que se enciende en llama con hover/foco + subrayado que se extiende; parpadeo en tiempo real, fijo con `Accessibility.reduce_flashes` |
| Botón sin marcador | `UiStyles.style_menu_button` | la misma placa sin marcador ni fuente: pausa, pantallas de fin, diálogos |
| Marco | `UiStyles.style_menu_frame(panel)` + `MenuFrameDecor` | panel casi negro con borde dorado fino, filete interior, esquinas en L con rombo y muesca arriba al centro. Dibuja sobre el rect del panel aunque el `PanelContainer` lo ubique dentro de los márgenes. |
| Título | `UiStyles.style_menu_title(label, px)` + `add_ornament_after` / `MenuOrnament` | Almendra SC dorado pálido con halo de brasa; regla dorada con rombo debajo |
| Campos, sliders, pestañas | `style_menu_field`, `style_menu_slider`, `style_menu_tabs`, `style_menu_controls(root)` | pozos oscuros con borde dorado; `style_menu_controls` recorre una página (Opciones) |
| Cartas de héroe | `UiStyles.build_card_style("normal"/"hot"/"picked"/"taken")` | selección de héroes y sala de espera |
| Diálogos Godot | `UiStyles.style_menu_dialog(dialog)` | "Partida en curso", guardado dañado, versión distinta |
| Fuente base | `UiStyles.menu_font_theme()` | Theme con solo `default_font` (sin tamaño, el escalado de texto sigue andando) para Opciones y sala de espera |
| Fondo animado | `MenuBackdrop` (`scripts/ui/menus/`) | ilustración ajustada como *cover*, parallax leve contra el mouse (`parallax_px`), resplandores aditivos que parpadean en `flames` (x, y en la imagen 0..1, z = radio / alto), pulso lento en `gem`, brasas que suben, viñeta y `tint` opcional. Tiempo real; solo lee la posición del mouse. |
| Transiciones | `MenuTransitionFX.play_panel_in/out`, `play_stagger_in` | panel: escala 0,97→1 + fundido mientras se dibujan las esquinas; columna: entrada escalonada desde la izquierda |

**Regla del RNG:** `CPUParticles2D` toma del RNG global al arrancar. Opciones vive escondido dentro de la pausa y los tests generan pisos con `seed()` → `randi()`: `MenuBackdrop` crea las brasas recién la primera vez que se ve (y con semilla fija si el motor la ofrece). `test_menu_estetica` lo comprueba.

## Pantallas

| Pantalla | Fondo (`MenuBackdrop`) | Notas |
|---|---|---|
| Menú principal | `menu_cripta.png`, llamas en la antorcha y los dos braseros, gema del altar | título QUEST arriba a la izquierda, lema, columna de placas a la izquierda sobre una sombra en degradé (`LeftShade`), Salir en rojo, versión abajo a la derecha, perfil de Steam arriba a la derecha. Con una subpantalla abierta el título se desvanece y la sombra baja. |
| Ranuras, modo de red, Créditos | la cripta del menú (Créditos con tinte oscuro) | marco + título + ornamento; borrar ranura = placa roja sin marcador |
| Selección de héroes | `menu_armeria.png`, dos braseros | cartas de piedra (doradas al elegir), vista previa enmarcada |
| Opciones | `menu_estudio.png`, velas y farol | pestañas en placa, páginas en pozo; también dentro de la pausa |
| Sala de espera | `Lobby Multijugador.png` con tinte frío y viñeta | falta una ilustración del mismo estilo (ver `PLAYTEST.md`) |

## Verificación

- `tests/test_menu_estetica.gd`: placas y marcadores en el menú y subpantallas, marcos, mapeo *cover* del fondo, tamaño de fuente, marcador fuera de `get_children()`, foco enciende/apaga el marcador, RNG intacto.
- `tests/tools/shot_barrido.gd` (capturas 720p / 1080p / texto ×1,5; espera en tiempo real porque guardar un PNG de 1080p puede tardar casi un segundo).
- `tests/tools/recorrido_menu.gd`: ventana real, clics y teclas de verdad por todo el menú hasta Salir (respalda y restaura `user://slot_*`).
