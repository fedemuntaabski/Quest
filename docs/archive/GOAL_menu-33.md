# Goal sesión menu-33 — overhaul estético del menú

Overhaul estético del menú principal y su recorrido (sesión menu-33). SOLO estética: sin cambiar flujo, lógica, red, RunState ni nada fuera de los menús.

Inicio: leer CLAUDE.md, docs/CREDITOS.md, docs/PLAYTEST.md. Commitear y pushear lo pendiente en session/mazmorra-32 y crear session/menu-33. Capturas y archivos de trabajo en capturas/menu-33/.

Alcance: MainMenu y todo lo que abre MainMenuFlow (slots, continuar, NetworkModeSelect, HeroSelectMenu + CharacterCardOption, OptionsMenu y sus pestañas, CreditsPanel, BestiaryPanel, ExitConfirmDialog, WaitingRoom). PauseMenu solo si comparte estilos. IntroScreen no.

Assets: portada "Cripta gótica con altar de cristal dorado.png" → assets/ui (fondo de MainMenu); seleccion_heroes.png / opciones.png / sala_espera.png si están (el dueño generó las dos primeras con ChatGPT; la sala de espera no). Si falta alguno, tinte frío oscuro + viñeta. Borrar fondos viejos sin referencias; CREDITOS (tabla + allowlist) "propia, generada con ChatGPT". Fuentes Almendra SC / EB Garamond.

Dirección visual: botones en columna a la izquierda, título arriba a la izquierda, altar a la derecha; placas con borde dorado envejecido, hover/foco con brillo de brasa + marcador lateral en lugar del bounce; efectos baratos en tiempo real (brasas, parpadeo, pulso de la gema, viñeta, parallax, entrada escalonada, transiciones); subpantallas con un mismo marco de esquinas doradas; estilos centralizados en UiStyles, sin overrides duplicados en .tscn; paleta dorado / piedra azul-verdosa / rojo estandarte.

Restricciones: Accessibility.font; 720p, 1080p y ×1.5 sin cortes; ManagerLocator; QuestLogger; mantener nodos y API usados por tests; vocabulario medieval; no subir version; mismo audio.

Verificación: suite completa en verde; shot_barrido ampliado, capturas revisadas + antes/después; recorrido en ventana real; separar lo visto solo en capturas.

Cierre: commits chicos; SESSIONS, CHANGELOG, CREDITOS, PLAYTEST; CLAUDE.md solo lo duradero (≤20 KB); push; /goal de la próxima sesión.
