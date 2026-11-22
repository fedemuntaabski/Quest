# Goal sesión menu-34 — integrar menu-33 y pulir el menú

Sesión menu-34: integrar menu-33 y pulir el menú con lo que se vea en movimiento. SOLO menús; nada de gameplay, red ni RunState.

Inicio: leer CLAUDE.md, docs/MENUS.md, el bloque menu-33 de docs/archive/SESSIONS.md y la sección "Menú nuevo (menu-33)" de docs/PLAYTEST.md. Commitear y pushear lo pendiente en session/menu-33. Integrar a main: si session/menu-33 no está en main, mergearla (avance directo si se puede), suite verde, push de main. Abrir session/menu-34 desde ahí. Capturas en capturas/menu-34/.

Fase 1 — feedback del dueño: preguntarle qué vio en la lista de PLAYTEST (parpadeo de llamas y gema, brasas, parallax, marcador de los botones, aparición de paneles, foco con teclado) y ajustar números en MenuBackdrop / MenuButtonDecor / MenuTransitionFX según lo que diga. Si algo no le gusta, ofrecer 2 variantes con captura antes de elegir.

Fase 2 — sala de espera: si existe sala_espera.png en la raíz (mismo estilo que menu_cripta.png), pasarla a assets/ui/, usarla en WaitingRoom (sacar el tinte), fila en docs/CREDITOS.md (tabla + allowlist, "propia, generada con ChatGPT"), borrar Lobby Multijugador.png si queda sin referencias; test_licencias verde. Si no existe, dejarlo como está y avisar.

Fase 3 — detalles que quedaron: botón "Controles" de la pausa en mayúsculas como el resto si no rompe tests; revisar con tools/run_tests.sh que el HUD y las pantallas de fin (comparten style_menu_button) se ven bien en las capturas f1_* / victory / death de shot_barrido.

Restricciones: las de CLAUDE.md (Accessibility.font, ManagerLocator, QuestLogger, vocabulario medieval, nada que dibuje del RNG global escondido). No subir version.

Verificación: tools/run_tests.sh completo en verde; shot_barrido (720, 1080, 1080x15) y tests/tools/recorrido_menu.gd sin FAIL; capturas antes/después de lo que cambie. Decir qué se vio solo en capturas.

Cierre: commits chicos; bloque en docs/archive/SESSIONS.md, línea en CHANGELOG.md, docs/MENUS.md y PLAYTEST.md al día; CLAUDE.md solo lo duradero (≤20 KB, hoy ~20,4 KB: recortar si se agrega algo). Push. Terminar con el /goal de la siguiente sesión, que apunte a los docs.
