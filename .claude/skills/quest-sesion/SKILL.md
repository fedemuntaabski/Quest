---
name: quest-sesion
description: Ritual de apertura y cierre de una sesión de QUEST (rama, PR, qué leer por área, tests, capturas, versión, docs de cierre) y la plantilla del próximo /goal. Usar al empezar o cerrar cualquier sesión session/<tema>-<n>, o cuando un /goal diga "Ritual: skill quest-sesion".
---

# Sesión de QUEST

Un /goal trae solo el tema, los pasos y los criterios de cierre; el resto está acá. CLAUDE.md manda sobre esto si se contradicen.

## Apertura

1. `git status`: si hay algo pendiente en la rama de la sesión anterior, commit + push en esa rama (repo público: nada de secretos).
2. PR de la sesión anterior si no tiene: `gh pr create --base <rama base> --head session/<anterior>` (la base es la sesión previa mientras su PR siga abierta; si no, `main`). `gh pr list --state all` para ver.
3. `git switch -c session/<tema>-<n>` desde la anterior. Capturas y archivos de trabajo en `capturas/<tema>-<n>/` (gitignoreada), nunca en C:.
4. Leer el último bloque de `docs/archive/SESSIONS.md` y los docs del área:

| Área | Leer |
|---|---|
| Balance, BalanceSim | `docs/BALANCE.md` (estado actual); historia en `docs/archive/BALANCE_HISTORIA.md` |
| Bucle, puertas, economía, Obras | `docs/BUCLE_JUEGO.md`, `docs/ECONOMIA.md`, `docs/BALANCE.md` |
| Héroes, habilidades, ítems | `docs/PERSONAJES.md` |
| Enemigos, objetivos, jefes | `docs/ENEMY_TARGETING.md` |
| Mapa, salas, render | `docs/ROOMS.md`, `docs/MAP_RENDER.md` |
| Menús, HUD, accesibilidad | `docs/MENUS.md`, `docs/PLAYTEST.md` |
| Arte, audio, licencias | `docs/ASSETS.md`, `docs/CREDITOS.md`, `docs/MISSING_ICONS.md` |
| Co-op | `docs/COOP_PROGRESO.md`, `docs/COOP_PRUEBAS.md` |
| Guardado | `docs/GUARDADO.md` |
| Rendimiento | `docs/RENDIMIENTO.md`, `docs/PROGRESO_INTEGRACION.md` |

## Durante

- **Un test:** `tools/run_tests.sh <filtro>` (p. ej. `balance`). **La suite:** `tools/run_tests.sh` (69 tests, de a 6, ~2 min; la salida termina en `N test(s), M fallo(s)`). `--reindex` tras un `class_name` nuevo. Godot sale de `QUEST_GODOT` (`.claude/settings.json`).
- **Test antes del cambio:** escribir o ajustar el test primero, correrlo y dejar el `FAIL` visible en la salida; después del cambio, el mismo comando con `OK`. Sin ese par no cuenta como probado.
- **Capturas (ventana real, no `--headless`):**
  - `shot_barrido.gd -- capturas/<sesión>/<dir>` (720, 1080, 1080x15) cuando cambia algo de un menú, el HUD, un texto visible o el tamaño de letra. Antes y después.
  - `shot_jefe.gd -- capturas/<sesión>/<dir> ballesta|sin|esquiva|esquiva_ballesta` (`--resolution 1920x1080`) cuando cambia el jefe, las Defensas o lo que supone `BOSS_PLAY` del jefe.
  - `shot_mazmorra.gd` para mapas/puertas; `recorrido_menu.gd` para el flujo de menús con clics reales.
  - Mirar las imágenes (Read) antes de decir que algo se ve bien.
- **Balance:** `tests/tools/sweep.gd -- 200 <tag> '<play json>' '<columnas>'` (uso en `docs/BALANCE.md`). Tabla antes/después en el doc del tema.
- **Versión:** subir `application/config/version` en `project.godot` cuando cambian comandos de `NetCommands`, claves de `RunState` o números que calculan los dos peers (datos de `.tres` de juego, modificadores de ítems, costos, vida, recompensas). Cambios solo de BalanceSim, tests, docs o herramientas: no.
- Commits chicos, en español, con `(<tema>-<n>)` al final del título.

## Cierre

1. `tools/run_tests.sh` verde y la línea final en la respuesta.
2. Bloque `## <tema>-<n> (session/<tema>-<n>)` al final de `docs/archive/SESSIONS.md`: qué cambió, cómo se verificó (comandos y resultado), **qué no se vio en ventana real**.
3. Doc del tema al día (editar en el lugar; en BALANCE.md el «estado actual» ≤ 8 KB y la tabla vieja a `BALANCE_HISTORIA.md`). `docs/PLAYTEST.md` si queda algo por probar a mano.
4. `CHANGELOG.md`: una línea para jugadores (o «sin cambios en el juego»).
5. `CLAUDE.md` solo si cambió algo duradero, editado en su párrafo; `wc -c CLAUDE.md` ≤ 19 KB.
6. Push. Terminar la respuesta con el próximo /goal (plantilla abajo) y actualizar el informe si el dueño lo pidió.

## Plantilla del próximo /goal (3300-4000 caracteres)

```
<tema>-<n>: <título en una línea>.

Por qué: <1-3 frases: qué se vio en la sesión anterior, con el número o la captura que lo muestra>.

Pasos:
1. <paso del área, concreto: archivo, dato o pantalla>
2. ...
(si hay que elegir: "Proponer A/B/C con números; aplicar solo lo que elija el dueño")

Criterios de cierre (mostrar la salida de cada uno):
- tools/run_tests.sh: 69 tests (o más), 0 fallos.
- <test nuevo o ajustado>: FAIL antes del cambio y OK después, los dos en la salida.
- <medida del área: comando + resultado esperado, p. ej. sweep.gd -- 200: Difícil pares piso 5 ≥ X %>
- <captura: ruta en capturas/<tema>-<n>/ y qué tiene que verse>
- wc -c CLAUDE.md ≤ 19 KB.

Ritual: skill quest-sesion.
```

Largo: entre 3300 y 4000 caracteres (medirlo antes de entregarlo). Los pasos van completos: archivos, datos, pantallas, qué test se escribe primero y qué capturas se sacan. El ritual no se repite.

Cada criterio tiene que poder comprobarse leyendo el transcript: el evaluador del Stop hook pide la salida, no la afirmación.
