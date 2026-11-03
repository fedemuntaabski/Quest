# QUEST

Roguelite táctico 2D de mazmorras en Godot 4.6 (solo GDScript), inspirado en *Dungeon of the Endless*. Offline o co-op de 2 a 4 jugadores (Steam, o ENet para desarrollo local).

## Cómo se juega
Elegís 2 de 4 héroes y bajás 5 pisos generados por semilla. Cada puerta abierta es un turno: paga Brasas y un recurso, y puede traer enemigos. Encender salas con Brasas evita que aparezcan enemigos en ellas y habilita construir obras. En cada piso hay que descubrir la salida, recoger la Reliquia en la sala inicial y llevarlo hasta la salida mientras llegan oleadas; en los pisos 3 y 5 hay que matar antes al jefe. Se pierde si caen todos los héroes o se destruye la Reliquia.

## Controles
Se pueden cambiar en Opciones → Controles. Gamepad con cursor virtual.

| Acción | Tecla |
|---|---|
| Seleccionar / interactuar (puertas, Reliquia, jaulas, reanimar) | Clic izquierdo (Ctrl = agregar a la selección) |
| Mover | Clic derecho |
| Encender o apagar sala | Clic central (arrastrar = mover cámara) |
| Pausa táctica / velocidad 2x | Espacio / X |
| Menú de pausa | Esc |
| Habilidad / ciclar héroes | Q / Tab |
| Elegir héroe / grupos | F1–F4 / Ctrl+1..3 y 1..3 |
| Construir / investigar | B, V / R |
| Cámara | WASD, flechas, borde de pantalla, rueda; C recentra |
| Ayuda | H |

## Ejecutar
```bash
godot --path . --editor   # abrir en el editor
godot --path .            # jugar (escena principal: scenes/Main.tscn)
```

## Tests
```bash
tools/run_tests.sh [filtro]                   # Git Bash
lightshell -File tools/run_tests.ps1 [-Filter x]
godot --headless --path . --script res://tests/run_all.gd   # directo
```
Exit code = cantidad de fallos. `OK*` = aserciones bien, pero el motor crasheó al cerrar. Ruta de Godot en `QUEST_GODOT`.

## Documentación
- `CLAUDE.md`: arquitectura y notas por sesión.
- `docs/PLAYTEST.md`: guía para jugar una run y qué mirar.
- `docs/BALANCE.md`, `docs/ECONOMIA.md`, `docs/BUCLE_JUEGO.md`, `docs/ROOMS.md`, `docs/PERSONAJES.md`, `docs/ENEMY_TARGETING.md`: diseño y números.
- `docs/COOP_PRUEBAS.md`: pruebas manuales de co-op.
- `CREDITS.md`, `docs/CREDITOS.md`: arte y licencias.
