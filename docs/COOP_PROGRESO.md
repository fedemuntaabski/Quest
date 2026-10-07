# Co-op (session/coop-12): progreso

Plan completo: 7 fases (pedido de la sesión). Estado al cerrar el 2026-10-06.

| Fase | Estado | Commit |
|---|---|---|
| 1. Transporte (Steam + ENet) | hecha | `feat(net): NetworkTransport Steam + ENet y NetSession` |
| 2. Lobby y arranque compartido | hecha | `feat(net): sala co-op y arranque compartido` |
| 3. Comandos validados + snapshots | hecha | `feat(net): comandos validados por el host y snapshots` |
| 4. Control por jugador y color | pendiente | — |
| 5. Pausa por votación / velocidad del host | pendiente | — |
| 6. Desconexión, reconexión, desync | parcial: hash de desync en NetSync; falta reconexión | — |
| 7. HUD (jugadores+ping, avisos, chat, ping de mapa) | pendiente | — |

## Verificado
- Suite completa en headless, gdparse y boot de `Main.tscn`/`Main2d.tscn` tras cada fase.
- `tests/test_net_transport.gd`, `tests/test_net_lobby.gd` y `tests/test_net_commands.gd`.
- Steam real con el cliente abierto: `tests/tools/steam_probe.gd` crea un lobby (id real), lo expone como código y lo cierra.

## Sin verificar todavía
- La prueba de dos procesos (`tests/tools/net_sync_host.gd` + `tests/tools/net_client_probe.gd`) quedó escrita pero **no se corrió**. Necesita la reconexión de la fase 6. Cuando pase, renombrarla a `tests/test_net_sync.gd`.
- Join por Steam con una segunda cuenta, la invitación del overlay y cualquier partida en una ventana real.

## Próximos pasos (diseño ya decidido)
- **Fase 4.**
  - `SelectionManager._is_live` exige `NetSession.owns(id)`.
  - `refresh_ownership()` se llama cuando cambia `hero_owner`.
  - `on_party_spawned` elige el primer héroe propio.
  - Anillo del color del dueño en `Player._draw` (se redibuja con `lobby_changed`).
  - Borde del color del dueño en `HeroPortrait._apply_panel_style`.
- **Fase 6.**
  - `NetSession._away[token]` guarda los héroes de quien se fue: pasan al host, o quedan sin dueño si `NetConfig.orphan_mode` es `DEFENSIVE_AI`.
  - `_rejoin` con el mismo token: `_rpc_join_run(seed, owners, dificultad, piso, party, players)` → `start_gameplay(piso)`, y después `RunState` vía `floor_ready`.
  - Hace falta `current_floor` en NetSession.
  - Host perdido en plena run: Main2d escucha `session_ended("host_lost")` y cierra con el resumen.
- **Fase 5.**
  - `PauseController` online: Space hace `request("pause_vote")`.
  - El host cuenta mayoría o espera el fin de `NetConfig.pause_vote_window_sec`, y reanuda solo a los `max_pause_sec`.
  - X solo funciona en el host. `Engine.time_scale` ya viaja en el snapshot.
  - Esc online no pausa el árbol.
- **Fase 7.**
  - `PlayerList` con ping (RPC ping/pong cada `NetConfig.ping_sec`) y avisos con `player_joined`/`player_left`.
  - Chat con `NetConfig.chat_messages`.
  - Alt+click en una sala manda un ping que se ve en el minimapa y en el mundo.
- **Cierre.** `docs/COOP_PRUEBAS.md` con los pasos manuales de Steam (dos cuentas, AppID 480) y la entrada de CLAUDE.md.

## Notas de diseño
- El único camino de entrada es `ManagerLocator.get_net_commands().request(cmd, args)`. Offline ejecuta directo (mismo código); en un cliente manda un RPC al host.
- `Net.is_authority()` protege cada mutador compartido. Un cliente solo aplica `RunState` (`apply_state`) y los snapshots.
- Lo que el host no replica:
  - proyectiles de héroes a distancia en el cliente (solo se ven el impacto y la vida);
  - cooldown de consumibles en el cliente;
  - héroes perdidos al reconectar (se crean y después el estado los corrige).
