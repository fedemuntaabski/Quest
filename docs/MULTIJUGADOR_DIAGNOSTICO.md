# Multijugador: diagnóstico, arquitectura propuesta y plan

Sesión `multijugador-11`: auditoría solamente. El multijugador **no** está implementado; se corrigió lo roto en la capa de Steam (commit `fix(steam)`).

## 1. Estado de GodotSteam

| Punto | Estado |
|---|---|
| Versión | GodotSteam **4.22.1** Community Edition (`addons/godotsteam/plugin.cfg`), licencia MIT |
| Instalación | **GDExtension** (`godotsteam.gdextension`, `compatibility_minimum = "4.4"`): compatible con 4.6.2. No es un módulo; el plugin de editor (updater) no está habilitado y no hace falta |
| Binarios | win32/win64/linux32/linux64/linuxarm64/osx/androidarm64 en disco. **`.gitignore:74` (`*.dll`) excluye los de Windows**: un clon nuevo en Windows no trae la extensión |
| `SteamMultiplayerPeer` | incluido en la misma extensión (`ClassDB.class_exists` = true; `create_host`, `create_client`, `get_peer_id_for_steam_id`) |
| `steam_appid.txt` | `480` (Spacewar, app de prueba de Valve). Para publicar hace falta un App ID propio |
| Inicialización | `SteamManager._ready` → `steamInitEx(APP_ID, false)`. Antes tenía los argumentos invertidos y además estaba activo `[steam] initialize_on_startup` (doble init, con warning del propio GodotSteam). **Corregido:** auto-init apagado |
| Callbacks | `run_callbacks()` en `SteamManager._process` (embed off) ✅ |
| Steam cerrado | `steamInitEx` devuelve status 2 ("Cannot create IPC pipe") → `is_steam_available()` false → `NetworkModeSelect` deshabilita Host/Join con "Steam no está disponible. Solo modo sin conexión." ✅ (verificado headless) |
| Extensión ausente | **antes:** todo `Steam.` y `SteamMultiplayerPeer` eran errores de parseo, `SteamManager` (autoload), `MainMenuFlow`, `MainMenu` y `WaitingRoom` no cargaban y el juego no arrancaba ni offline. **Ahora:** todo pasa por `SteamApi` (`scripts/network/SteamApi.gd`: `Engine.get_singleton`, `ClassDB.instantiate`, constantes numéricas) y arranca en offline con un warning (verificado headless renombrando el `.gdextension`) |

### Bugs de red corregidos (`fix(steam)`)
1. `steamInitEx(false, 480)`: la firma 4.22 es `(app_id, embed_callbacks)`. Funcionaba de casualidad gracias a `steam_appid.txt`.
2. `_on_get_auth_session_ticket_response` comparaba con `AUTH_SESSION_RESPONSE_OK` (0), pero `result` es un EResult (`RESULT_OK` = 1). El cliente **nunca** enviaba su ticket, así que `connected_clients` siempre quedaba vacío. Ahora también se descartan tickets viejos.
3. El cliente buscaba el peer id del host antes de conectar. Ahora pide el ticket en `multiplayer.connected_to_server` y lo envía a `rpc_id(1, …)`.
4. Si `beginAuthSession` fallaba (comparado con la enum equivocada), solo se logueaba. Ahora se rechaza al instante.
5. Un peer que nunca enviaba ticket quedaba conectado para siempre. Ahora el timeout de 15 s arranca en `peer_connected` (host).
6. `leave_lobby` no cerraba el peer, y si fallaba `create_host`/`create_client` el lobby de Steam quedaba abierto. Ahora se cierra todo con `_close_peer()` + `leave_lobby()`.
7. Una invitación del overlay (`join_requested`) se aceptaba en plena partida. Ahora se ignora si hay un `RoomManager` vivo.
8. Join sin Steam cerraba el menú y dejaba la pantalla vacía. Ahora vuelve a `NetworkModeSelect`.

## 2. Código de red actual

| Pieza | Funciona | No funciona / falta |
|---|---|---|
| `SteamManager` (autoload) | init, callbacks, avatares, auth (ya corregida) | sin probar con Steam real |
| `SteamLobbyManager` | crear/unirse/salir de lobby (Friends Only, 4), peer host/cliente | no lista miembros. El cliente sigue sin elegir slot de guardado |
| `NetworkModeSelect` | Host/Join deshabilitados sin Steam | — |
| `MainMenuFlow` | Host → lobby → slot → WaitingRoom | Join depende del overlay (en el editor suele no abrir; queda la pantalla del menú de modo) |
| `WaitingRoom` | roster, elección de personaje vía lobby member data, invitar | **Start solo arranca la partida en el host** (`WaitingRoom.gd:177-184`): los clientes no reciben nada. El roster sale de `connected_clients` (solo en el host); en el cliente conviene `getNumLobbyMembers`/`getLobbyMemberByIndex` |
| Gameplay | — | **no existe**: un solo `@rpc` (`SteamManager.submit_auth_ticket`); no hay `MultiplayerSpawner`/`MultiplayerSynchronizer`; `Main.start_gameplay()` es 100 % local |

## 3. Supuestos de "un solo jugador"

Patrón general: un solo grupo de héroes, con el estado en autoloads globales indexados por `hero_id`, sin noción de dueño.

| Área | Evidencia | Riesgo co-op | Esfuerzo |
|---|---|---|---|
| `ManagerLocator.get_player()` | = héroe primario de la selección global (`ManagerLocator.gd:85`). Solo lo usa `NexoController.gd:34,59` | medio | chico (`get_player(peer_id)`) |
| `get_heroes()` / grupo `player` | ~30 usos que significan "todos los héroes del mundo": siguen bien en co-op | bajo | nada |
| Entrada | `HeroInputController` escribe directo en `SelectionManager`. `PlayerActionController._selected_heroes()` mueve la selección global; `_action_in_flight` es una orden a la vez para todo el grupo. RoomZone, Door, Nexo, BuildingSlot, PrisonerCage, AltarShrine y Chest actúan localmente. Teclas en `Main2d._input` | **alto** | **grande**: capa de comandos |
| `SelectionManager` | `selected_ids`/`groups` únicos. Además manejan gameplay (`PlayerStats.active_hero_id`, la habilidad Q, el destino de las órdenes) | medio | medio (propiedad `hero_id → peer_id`) |
| HUD | lee autoloads y reacciona a sus señales: sirve con espejos replicados. Pero sus botones mutan directo (`level_up_hero`, `equip`, `research`, construir) | medio | medio (pasar los botones a pedidos) |
| `PlayerStats` / `PartyInventory` / `GameSession` | estado de la run por héroe. La mochila compartida encaja con co-op | **alto** | medio/grande (replicación) |
| `SaveManager` / `BestiaryService` / récords | metaprogresión por jugador; la run no se guarda | bajo | chico (el host envía eventos de kill/visto y el resumen final) |
| `ResourceManager` | un pool compartido (correcto estilo DotE); los mutadores corren en cualquier lado | medio | chico (solo host + replicar `resource_changed`) |
| RNG | mapa, puertas, cofres, trampas, altar y prisionero con semilla (`run_seed` → `map_seed` → `hash([...])`). **Sin semilla:** `EnemyManager.gd:122,127,144,163,218-223`, `FloorManager.gd:285`, `EnemyPool.gd:26` | bajo con host autoritativo; alto con lockstep | chico (~6 llamadas) |
| `EnemyManager` / IA de `Enemy` | simula local, con `Timer`s; reloj `Enemy.game_time_msec` es `static` | **alto** | **grande** (replicar enemigos) |
| `FloorManager` / `ExtractionManager` / `DoorTurnSystem` | deterministas pero ejecutan efectos y oleadas en cualquier peer | alto | medio (solo host) |
| Nexo | `NexoController` usa `get_player()` local y un diálogo local | medio | chico |
| Pausa táctica / 2x | `PauseController` toca `Engine.time_scale` (global del proceso). Esc, muerte y victoria hacen `get_tree().paused = true` (`GameStateManager.gd:85-89`, `Main.gd`) | **alto** | medio |
| Tiempo | `run_stats.elapsed_sec` con `Time.get_ticks_usec` en `Main2d._process`. El resto de los `get_ticks_msec` son UI/meta | bajo | chico |

## 4. Arquitectura propuesta

**Host autoritativo** sobre `SteamMultiplayerPeer` (el host es peer 1 y simula todo; los clientes envían comandos y dibujan).

- **Capa de comandos:** un nodo `NetCommands` con `@rpc("any_peer", "reliable") func request(cmd: StringName, args: Dictionary)`. El host valida (propiedad del héroe, recursos, `get_block_reason` existentes) y ejecuta la misma API que hoy usa el juego local. Offline, la llamada es directa (la misma ruta, sin red), así hay un solo camino de código.
  - Comandos: `move(hero_ids, zone)`, `open_door(door_id)`, `toggle_power(zone)`, `build(slot, type)`, `demolish`/`repair`, `research(id)`, `level_up`/`heal`/`revive`/`choose_perk(hero)`, `equip`/`unequip`/`consume`, `ability(hero)`, `pickup_nexo(hero)`, `recruit(cage, resource)`, `altar(hero)`, `pause`/`speed`.
- **Snapshot** (unreliable, 10–15 Hz, solo host → clientes): héroes y enemigos (id, posición, HP, estado/caído), `Enemy.game_time_msec`, fase/stage de extracción, HP del Nexo y `Engine.time_scale`. Los clientes interpolan.
- **RPC reliable** (eventos discretos): `run_seed` + piso al empezar (cada cliente genera el mismo mapa: ya es determinista); grupo revelado; puerta abierta; sala encendida; módulo construido/destruido; recursos (delta); investigación; inventario/equipo; nivel/perk; spawn/muerte de enemigo (id estable); recoger/soltar Nexo; victoria/derrota; avisos del HUD (`enemies_appeared`).
- **Control de héroes:** tabla `hero_owner: hero_id → peer_id` en el host. En el lobby cada jugador elige su(s) héroe(s); los reclutados van a quien los liberó (o al que tenga menos). La selección y los grupos de control son locales y **solo** permiten seleccionar héroes propios; ver y curar o reanimar a los de otros está permitido. Si un jugador se va, sus héroes pasan al host (IA quieta) hasta que vuelva.
- **Pausa y velocidad:** las controla el host y se difunden. Cualquiera puede pedir la pausa táctica (Space) o el cambio de velocidad (X) y el host la aplica a todos (estilo DotE co-op), con un aviso "Pausado por X". Esc pasa a ser un overlay **local** que no hace `get_tree().paused`; muerte y victoria siguen las decide el host.
- **Reconexión:** el host guarda `steam_id → hero_ids`. Al volver, el cliente recibe la semilla + piso, regenera el mapa y recibe un snapshot completo (grupos revelados, salas encendidas, módulos, recursos, inventario, investigación, enemigos). Después se le devuelven sus héroes.
- **Metaprogresión:** cada jugador guarda la suya. El host envía `register_seen`/`register_kill` y el resumen de la run.

## 5. Decisiones abiertas (con recomendación)

| Decisión | Recomendación |
|---|---|
| ¿Versionar los DLL de GodotSteam? | **Sí:** des-ignorar `addons/godotsteam/**` en `.gitignore` (~10 MB). Hoy, sin ellos, cualquier clon en Windows queda offline. Alternativa: documentar la descarga |
| ¿Versionar `*.import`? | **Sí** (guía de Godot 4): sin ellos los `uid://` cambian por clon |
| App ID | registrar el propio en Steamworks antes de cualquier prueba pública; 480 solo para desarrollo |
| Pausa táctica online | pausa compartida pedida por cualquiera + aviso. No deshabilitarla: es el núcleo del género |
| RNG de enemigos | con host autoritativo no hace falta. Sembrarlo igual (`hash([map_seed, "enemy", turn])`) cuesta poco y habilita replays/tests |
| Jugadores máximos | 2–4 (= `GameSession.MAX_PARTY` 4); empezar con 2 |
| Héroes por jugador | con 2 jugadores, 1 cada uno + reclutados repartidos |
| Sincronización | RPC propios + snapshot manual antes que `MultiplayerSynchronizer` (los nodos se crean por código y los ids de zona/enemigo ya son estables) |

## 6. Plan por fases

1. **Lobby completo:** roster del cliente por miembros del lobby, Start difundido (RPC `start_run(seed, picks)`), el cliente entra a gameplay, salida/desconexión limpias. Prueba: dos cuentas de Steam ven el mismo mapa.
2. **Capa de comandos offline:** pasar toda entrada y botón del HUD por `NetCommands` sin red (el mismo comportamiento). Agregar `hero_owner`. Prueba: los tests actuales siguen pasando.
3. **Host autoritativo:** los managers solo simulan en el host; en el cliente se desactiva la IA/los timers. Eventos reliable + snapshot de héroes y enemigos con interpolación.
4. **Estado compartido:** recursos, investigación, inventario, niveles, Nexo y extracción replicados; HUD sobre los espejos.
5. **Pausa/velocidad compartidas**, Esc local, avisos.
6. **Reconexión** y traspaso de héroes; endurecer (validación, rate limit de comandos).
7. **Pulido:** latencia (predicción del movimiento propio), pruebas con 2–4 jugadores y App ID propio.

## 7. Qué no se pudo verificar en esta sesión
- Todo lo que necesita Steam abierto: init real, lobbies, auth host↔cliente con los arreglos, overlay de Join/invitación, avatares.
- Conexión entre dos máquinas o cuentas.
- Se verificó headless: arranque con Steam cerrado (status 2) y sin la extensión (renombrando `godotsteam.gdextension`), tests de `tests/` y boot de `Main.tscn`/`Main2d.tscn`.
