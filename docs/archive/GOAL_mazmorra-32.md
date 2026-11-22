# Goal sesión mazmorra-32 — terminar mazmorra-31: mecánicas de tipos, arte propio, iluminación

Abrí session/mazmorra-32 desde session/mazmorra-31 (commit + push de lo pendiente antes). Primero integrá a main: si session/mazmorra-31 no está en main, mergeala (avance directo si se puede) y dejá la suite verde. Tema: terminar lo que mazmorra-31 dejó (bloque mazmorra-31 de docs/archive/SESSIONS.md y docs/archive/GOAL_mazmorra-31.md): arte propio, iluminación y las mecánicas de tipos de sala.

Fases (capturas y pregunta al cerrar cada una):
1. Mecánicas de tipos: sala Prisionero vacía con el grupo lleno o sin candidatos (dejarla / no generarla / que la celda dé otra cosa); tipos nuevos o a quitar. Balance con BalanceSim.
2. Decoración propia en LibreSprite: dungeon_decor.png a .ase, retoque de pozo/alfombra/losas/escombros, antorchas y braseros animados, estanterías, cadenas, huesos, telarañas, grietas, charcos, altar en pixel art, props por tipo. CREDITOS, tilesets con uid, test_licencias.
3. Iluminación: luz que parpadea (PointLight2D, color del tipo), sombras con LightOccluder2D, encendido suave, bajar LIT_FILL_COLOR; 2-3 variantes; bench (4 héroes + oleada, GL Compatibility), avisar si pasa 1 ms.

Reglas y criterio de terminado: ver el bloque mazmorra-32 de docs/archive/SESSIONS.md.
