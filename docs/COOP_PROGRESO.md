# Co-op (session/coop-12): progreso

Plan completo: 7 fases (pedido de la sesión). Estado al cerrar el 2026-10-07: las 7 fases hechas.

| Fase | Estado | Commit |
|---|---|---|
| 1. Transporte (Steam + ENet) | hecha | `feat(net): NetworkTransport Steam + ENet y NetSession` |
| 2. Lobby y arranque compartido | hecha | `feat(net): sala co-op y arranque compartido` |
| 3. Comandos validados + snapshots | hecha | `feat(net): comandos validados por el host y snapshots` |
| 4. Control por jugador y color | hecha | `feat(net): control por jugador y color de dueño` |
| 5. Pausa por votación / velocidad del host | hecha | `feat(net): pausa táctica por votación y velocidad del host` |
| 6. Desconexión, reconexión, desync | hecha | `feat(net): desconexión, reconexión y host perdido` |
| 7. HUD (jugadores+ping, avisos, chat, ping de mapa) | hecha | `feat(net): HUD co-op (jugadores con ping, avisos, chat, ping de mapa)` |

## Verificado
- Suite completa en headless, gdparse y boot de `Main.tscn`/`Main2d.tscn` tras cada fase.
- `tests/test_net_transport.gd`, `tests/test_net_lobby.gd`, `tests/test_net_commands.gd`, `test_net_ownership`, `test_net_pause`, `test_net_robustness`, `test_net_hud`.
- `tests/test_net_sync.gd`: dos procesos headless sobre ENet local (lanza `tests/tools/net_client_probe.gd`, log del cliente en `user://net_probe_client.log`): misma semilla, snapshots, puerta abierta por el host vista en el cliente, movimiento del cliente ejecutado por el host, rechazo de héroe ajeno, hash sin desync, reconexión con el mismo token.
- Steam real con el cliente abierto: `tests/tools/steam_probe.gd` crea un lobby (id real), lo expone como código y lo cierra.

## Sin verificar todavía
- Join por Steam con una segunda cuenta, la invitación del overlay y cualquier partida en una ventana real.

## Pruebas manuales
Ver `docs/COOP_PRUEBAS.md` (ENet en una PC, Steam con dos cuentas / AppID 480, lo no verificado, logs clave).

## Notas de diseño
- El único camino de entrada es `ManagerLocator.get_net_commands().request(cmd, args)`. Offline ejecuta directo (mismo código); en un cliente manda un RPC al host.
- `Net.is_authority()` protege cada mutador compartido. Un cliente solo aplica `RunState` (`apply_state`) y los snapshots.
- Lo que el host no replica:
  - proyectiles de héroes a distancia en el cliente (solo se ven el impacto y la vida);
  - cooldown de consumibles en el cliente;
  - héroes perdidos al reconectar (se crean y después el estado los corrige).
