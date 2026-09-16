# Auditoría técnica — Integración Steam / GodotSteam

**Proyecto:** QUEST (Godot 4.6, GDScript)
**Alcance:** `scripts/network/SteamManager.gd`, `scripts/network/SteamLobbyManager.gd`, consumidores UI (`MainMenu.gd`, `MainMenuFlow.gd`, `NetworkModeSelect.gd`, `WaitingRoom.gd`), configuración de autoload en `project.godot`.
**Método:** lectura completa de ambos scripts principales línea por línea + grep exhaustivo de `Steam\.` en todo el árbol `scripts/` y `scenes/`.

---

## 1. Estructura general y singleton de Steam

- **Autoload:** `project.godot:28` → `SteamManager="*res://scripts/network/SteamManager.gd"`. Es el único autoload relacionado con Steam. `SteamLobbyManager` **no** es autoload: se instancia como hijo de `SteamManager` en runtime (`SteamManager.gd:39-41`).
- **Inicialización** (`SteamManager.gd:24-30`):
  ```gdscript
  func _ready() -> void:
      var init_result: Dictionary = Steam.steamInitEx(false, APP_ID)
      _steam_initialized = init_result.get("status", 1) == 0
      if not _steam_initialized:
          QuestLogger.warn(...)
          return
  ```
  Solo se usa `Steam.steamInitEx()`. **`Steam.isSteamRunning()` no se llama en ningún punto del código.** Si la inicialización falla, se corta temprano y `lobby_manager` queda `null` (nunca se instancia), lo cual gatea correctamente todo el resto del sistema.
- **AppID:** `SteamManager.gd:3` → `const APP_ID: int = 480`. **Este es el AppID público de prueba "Spacewar" de Valve**, no un AppID real registrado del estudio. Si el juego se va a distribuir, esto es bloqueante: sin AppID propio no hay validación de propiedad/entitlement real, ni tickets de auth verificables contra la app correcta.
- **Pump de callbacks:** `SteamManager.gd:47-49`, único lugar donde se llama `Steam.run_callbacks()`, dentro de `_process()`, gateado por `_steam_initialized`.
- **Tipado débil:** `SteamManager.gd` no declara `class_name`. `ManagerLocator.get_steam_manager()` (`ManagerLocator.gd:38-39`) retorna tipo `Node` genérico; todo el código que lo consume llama métodos específicos de Steam sobre una referencia sin tipar, confiando en duck-typing de GDScript.

### Señales de Steam conectadas

| Señal | Ubicación | Handler |
|---|---|---|
| `Steam.get_auth_session_ticket_response` | `SteamManager.gd:34` | `_on_get_auth_session_ticket_response` |
| `Steam.validate_auth_ticket_response` | `SteamManager.gd:35` | `_on_validate_auth_ticket_response` |
| `Steam.avatar_loaded` | `SteamManager.gd:36` | `_on_loaded_avatar` |
| `Steam.persona_state_change` | `SteamManager.gd:37` | `_on_persona_state_change` |
| `Steam.lobby_created` | `SteamLobbyManager.gd:12` | `_on_lobby_created` |
| `Steam.lobby_joined` | `SteamLobbyManager.gd:13` | `_on_lobby_joined` |
| `Steam.join_requested` | `SteamLobbyManager.gd:14` | `_on_join_requested` |

Además, señales de multiplayer de Godot (no Steam, pero parte del mismo flujo): `multiplayer.peer_connected`/`peer_disconnected` (`SteamManager.gd:43-44`).

**Ausentes:** `Steam.lobby_match_list` (no hay browser de lobbies — unión solo vía overlay de amigos/invitación), `Steam.p2p_session_request`/`p2p_session_connect_fail` (no se usa P2P manual, ver sección 4), `Steam.lobby_chat_update` (el host no recibe evento a nivel Steam-lobby cuando un miembro se va; depende exclusivamente de `multiplayer.peer_disconnected`).

Ninguna de estas conexiones usa guard `is_connected()` (a diferencia del código UI, que sí lo hace consistentemente). Bajo riesgo porque `_ready()` de ambos nodos corre una sola vez por proceso, pero es una inconsistencia de estilo frente al resto del código.

---

## 2. Sistema de autenticación

### Estructura de los diccionarios de clientes

- **`connected_clients: Dictionary[int, Dictionary]`** (`SteamManager.gd:9`) — clave `peer_id`. Valor: `{"steam_id": int, "authenticated_at": int}`. Se escribe solo en `SteamManager.gd:134` (auth exitosa), se borra solo en `SteamManager.gd:177` (desconexión).
- **`pending_clients: Dictionary[int, Dictionary]`** (`SteamManager.gd:10`) — clave `peer_id`, pero con **dos formas incompatibles** según el rol del proceso:
  - Lado cliente (pidiendo su propio ticket): `{"ticket_buffer": PackedByteArray, "requested_at": int}` — escrito en `SteamManager.gd:86`.
  - Lado host (validando ticket ajeno): `{"steam_id": int, "ticket": PackedByteArray, "requested_at": int}` — escrito en `SteamManager.gd:102`.

  Hoy no colisiona porque un mismo proceso es host *o* cliente, nunca ambos contra el mismo dict a la vez. Pero es un diseño frágil: cualquier código futuro que asuma una sola forma (p. ej. `pending_clients[x].get("steam_id", 0)` desde el lado cliente) devuelve `0` silenciosamente en vez de fallar visiblemente.

### Flujo de solicitud y validación de tickets

**Lado cliente — pedir su propio ticket** (`SteamLobbyManager.gd:89-90`, dentro de `_on_lobby_joined`):
```gdscript
var host_peer_id: int = peer.get_peer_id_for_steam_id(host_steam_id)
ManagerLocator.get_steam_manager().get_auth_ticket_for_peer(host_peer_id)
```
`get_auth_ticket_for_peer` (`SteamManager.gd:82-86`):
```gdscript
func get_auth_ticket_for_peer(peer_id: int) -> void:
    var ticket_info: Dictionary = Steam.getAuthSessionTicket()
    _local_auth_ticket = ticket_info.get("id", -1)
    _local_auth_ticket_peer = peer_id
    pending_clients[peer_id] = {"ticket_buffer": ..., "requested_at": ...}
```
Cuando llega la respuesta (`_on_get_auth_session_ticket_response`, `SteamManager.gd:114-121`), se reenvía el ticket al host vía RPC:
```gdscript
submit_auth_ticket.rpc_id(_local_auth_ticket_peer, ticket_buffer)
```

**Lado host — recibir y validar** (`SteamManager.gd:95-104`):
```gdscript
@rpc("any_peer", "reliable")
func submit_auth_ticket(ticket_bytes: PackedByteArray) -> void:
    var peer_id: int = multiplayer.get_remote_sender_id()
    var steam_id: int = get_steam_id_for_peer_id(peer_id)
    if steam_id == 0:
        QuestLogger.warn(...)
        return
    pending_clients[peer_id] = {"steam_id": steam_id, "ticket": ticket_bytes, "requested_at": ...}
    validate_auth_session(ticket_bytes, steam_id)
    _start_auth_timeout(peer_id)
```
`steam_id` se resuelve del lado del transporte (`SteamMultiplayerPeer.get_steam_id_for_peer_id`), **no** del payload del RPC — el cliente no puede mentir sobre su propio SteamID en esta capa.

`validate_auth_session` (`SteamManager.gd:89-92`) llama `Steam.beginAuthSession(ticket_data, ticket_data.size(), steam_id)`.

### Manejo de callbacks

- `_on_get_auth_session_ticket_response` (`SteamManager.gd:114-121`): en error solo loguea y retorna — **nunca limpia `pending_clients[_local_auth_ticket_peer]`**, dejando al cliente en estado pendiente permanente.
- `_on_validate_auth_ticket_response` (`SteamManager.gd:124-139`): busca el `peer_id` recorriendo `pending_clients` por `steam_id` (scan lineal, aceptable para lobbies de ≤4). Si `auth_session_response == OK`, mueve a `connected_clients` y emite `client_authenticated`; si no, llama `_reject_client`.

### Timeout

`AUTH_TIMEOUT_SECONDS = 15.0` (`SteamManager.gd:4`), aplicado solo del lado host (`_start_auth_timeout`, `SteamManager.gd:107-111`):
```gdscript
func _start_auth_timeout(peer_id: int) -> void:
    await get_tree().create_timer(AUTH_TIMEOUT_SECONDS).timeout
    if pending_clients.has(peer_id):
        _reject_client(peer_id, pending_clients[peer_id].get("steam_id", 0), "timeout")
```
**El timeout es asimétrico**: el lado cliente que llama `get_auth_ticket_for_peer` no programa ningún timeout propio. Si `Steam.getAuthSessionTicket()` nunca dispara su callback, el cliente queda esperando indefinidamente sin feedback de error hacia la UI.

---

## 3. Lobbies y matchmaking

Todo en `SteamLobbyManager.gd`:

- **`create_lobby(lobby_type, max_members=4)`** (líneas 17-25): valida `steam_mgr != null` y `is_steam_available()` antes de llamar `Steam.createLobby(...)`; si falla, emite `lobby_failed("steam_unavailable")`.
- **`join_lobby(lobby_id)`** (líneas 28-31): si ya hay lobby activo, llama `leave_lobby()` primero (reentrancia correcta), luego `Steam.joinLobby(lobby_id)`.
- **`leave_lobby()`** (líneas 34-40): `Steam.leaveLobby(...)`, resetea `current_lobby_id`, desconecta el `multiplayer_peer`. **No toca directamente `connected_clients`/`pending_clients` de `SteamManager`** — depende de que `multiplayer.peer_disconnected` se dispare para cada peer durante el desmontaje.
- **`_on_lobby_created`** (líneas 43-62): chequea `connect_result != 1` (magic number de Steam, sin constante nombrada). Setea `setLobbyData` para `name`/`game_version`. Crea `SteamMultiplayerPeer`, `peer.create_host(0)`, conecta `multiplayer.multiplayer_peer`, emite `lobby_ready(lobby_id, true)`.
- **`_on_lobby_joined`** (líneas 65-93): chequea `response != CHAT_ROOM_ENTER_RESPONSE_SUCCESS`. Caso especial: el host también recibe su propio `lobby_joined` (comentado en el código, líneas 74-77) y retorna temprano. El cliente real crea `peer.create_client(host_steam_id, 0)`, resuelve `host_peer_id` y dispara el flujo de auth (`get_auth_ticket_for_peer`) antes de emitir `lobby_ready(lobby_id, false)`.
- **`_on_join_requested`** (líneas 95-97): invitación desde overlay de Steam → `join_lobby(lobby_id)`.

No existe browser de lobbies (`lobby_match_list` no usado). La unión es exclusivamente vía overlay de amigos (`Steam.activateGameOverlay("Friends")`, `MainMenuFlow.gd`) o diálogo de invitación (`Steam.activateGameOverlayInviteDialog`, `WaitingRoom.gd`).

---

## 4. Red y comunicación P2P / Network Messages

**Confirmado por grep exhaustivo (`Steam\.` en todo `scripts/` y `scenes/`): no existe una sola llamada a `sendP2PPacket`, `readP2PPacket`, `sendMessageToUser`, `receiveMessagesOnChannel`, `compress` ni `decompress_dynamic` en el proyecto.**

Toda la comunicación de gameplay usa la API `multiplayer` de alto nivel de Godot (`@rpc`, `multiplayer.peer_connected/disconnected`), montada sobre `SteamMultiplayerPeer` (clase de GodotSteam) que internamente envuelve el networking P2P de Steam. Es una arquitectura sólida y estándar, pero implica que la capa de transporte (compresión, canales, reliability) es completamente opaca al código del proyecto — no hay configuración explícita visible más allá de los defaults de `create_host`/`create_client`.

El único "mensaje" enviado manualmente relacionado con Steam es el propio ticket de auth, transportado por RPC de Godot (`submit_auth_ticket.rpc_id(...)`, `SteamManager.gd:121`), no por API P2P nativa de Steam.

---

## 5. Sistema de avatares y perfil

**`get_user_avatar`** (`SteamManager.gd:62-72`):
```gdscript
func get_user_avatar(steam_id: int = 0, size: int = Steam.AVATAR_MEDIUM) -> void:
    var target_id: int = steam_id if steam_id != 0 else Steam.getSteamID()
    if avatar_cache.has(target_id):
        avatar_loaded_ready.emit(target_id, avatar_cache[target_id])
        return
    if _pending_avatar_requests.has(target_id):
        return
    _pending_avatar_requests[target_id] = true
    if target_id != Steam.getSteamID():
        Steam.requestUserInformation(target_id, false)
    Steam.getPlayerAvatar(size, target_id)
```
Cache-check → dedupe de requests en vuelo → `requestUserInformation` (solo para usuarios remotos) → `getPlayerAvatar`.

**`_on_persona_state_change`** (líneas 75-79): solo reacciona si el `steam_id` está en `_pending_avatar_requests`, y solo re-pide avatar si el flag incluye `PERSONA_CHANGE_AVATAR`. Los cambios de nombre no se cachean en ningún lado — se leen en vivo con `Steam.getPersonaName()`/`getFriendPersonaName()` en cada render de UI.

**`_on_loaded_avatar`** (líneas 152-162):
```gdscript
_pending_avatar_requests.erase(user_id)
var img := Image.create_from_data(avatar_size, avatar_size, false, Image.FORMAT_RGBA8, avatar_buffer)
if img == null:
    QuestLogger.warn(...)
    return
if avatar_size > 128:
    img.resize(128, 128, Image.INTERPOLATE_LANCZOS)
var tex := ImageTexture.create_from_image(img)
avatar_cache[user_id] = tex
avatar_loaded_ready.emit(user_id, tex)
```
Se resuelve y cachea en `avatar_cache: Dictionary[int, ImageTexture]` (clave `steam_id`). Consumido en `MainMenu.gd` (perfil local) y `WaitingRoom.gd` (roster de sala, matcheado por `steam_id` en metadata de fila).

---

## 6. Desconexión y limpieza (cleanup / teardown)

**`_reject_client`** (`SteamManager.gd:142-149`):
```gdscript
func _reject_client(peer_id: int, steam_id: int, reason: String) -> void:
    QuestLogger.warn(...)
    if steam_id != 0:
        Steam.endAuthSession(steam_id)
    pending_clients.erase(peer_id)
    client_rejected.emit(peer_id, steam_id, reason)
    if multiplayer.multiplayer_peer != null and peer_id in multiplayer.get_peers():
        multiplayer.multiplayer_peer.disconnect_peer(peer_id, true)
```
Buen manejo defensivo: chequea null y membresía antes de `disconnect_peer`, cierra la sesión Steam antes de soltar el peer.

**`_on_peer_disconnected`** (`SteamManager.gd:169-178`):
```gdscript
func _on_peer_disconnected(peer_id: int) -> void:
    QuestLogger.info(...)
    if peer_id == _local_auth_ticket_peer and _local_auth_ticket != -1:
        Steam.cancelAuthTicket(_local_auth_ticket)
        _local_auth_ticket = -1
        _local_auth_ticket_peer = -1
    if connected_clients.has(peer_id):
        Steam.endAuthSession(connected_clients[peer_id].get("steam_id", 0))
        connected_clients.erase(peer_id)
    pending_clients.erase(peer_id)
```
Cancela el ticket local propio si corresponde, cierra sesión Steam para peers ya autenticados. **La última línea borra `pending_clients` sin llamar `Steam.endAuthSession` para ese caso** — ver hallazgo #1 abajo.

`leave_lobby()` (sección 3) no limpia estos dicts directamente; depende en cascada de `peer_disconnected`.

---

## 7. Diagnóstico, errores y puntos de mejora

Ordenado de mayor a menor severidad relativa.

1. **Fuga de sesión Steam en desconexión durante autenticación pendiente** — `SteamManager.gd:169-178`. Cuando un peer llama `submit_auth_ticket`, el host ya abrió sesión con `Steam.beginAuthSession` (`SteamManager.gd:90`). Si ese peer se desconecta **antes** de resolver (`connected_clients` nunca llega a tener la entrada), `_on_peer_disconnected` borra `pending_clients` pero **nunca llama `Steam.endAuthSession`** para esa sesión. Viola el contrato begin/end de Steamworks; en ciclos repetidos de connect/disconnect puede agotar la tabla de sesiones de auth del proceso. **Fix sugerido:** en `_on_peer_disconnected`, antes de `pending_clients.erase(peer_id)`, si la entrada tiene `steam_id`, llamar `Steam.endAuthSession(steam_id)`.

2. **Peer "fantasma" cuando no se resuelve `steam_id`** — `SteamManager.gd:96-101`. Si `get_steam_id_for_peer_id(peer_id) == 0`, la función retorna sin agregar el peer a `pending_clients`, sin programar timeout y sin desconectarlo. Ese peer queda conectado a nivel transporte pero invisible para toda la lógica de auth, indefinidamente. **Fix sugerido:** desconectar el peer inmediatamente en ese branch.

3. **Timeout asimétrico** — solo el host tiene los 15s de `_start_auth_timeout` (`SteamManager.gd:107-111`). El lado cliente (`get_auth_ticket_for_peer`, línea 82-86) no tiene timeout propio; si `Steam.getAuthSessionTicket()` no responde, el cliente queda esperando sin error visible en UI.

4. **Ticket local sobrescrito sin cancelar** — `SteamManager.gd:82-86`. Una segunda llamada a `get_auth_ticket_for_peer` antes de que resuelva la primera pisa `_local_auth_ticket`/`_local_auth_ticket_peer`/`pending_clients[peer_id]` sin llamar `Steam.cancelAuthTicket` sobre el ticket reemplazado — fuga de ticket.

5. **Race de reutilización de `peer_id` en el timeout** — `_start_auth_timeout` (líneas 107-111) solo chequea `pending_clients.has(peer_id)` tras 15s. Si ese `peer_id` se reasigna a una conexión distinta antes de que dispare el timer, se rechaza por error a un peer legítimo nuevo.

6. **`_pending_avatar_requests` puede quedar trabado para siempre** — `SteamManager.gd:15,67-68`. Si `Steam.avatar_loaded` nunca dispara para un `steam_id` dado, ese ID queda marcado "pendiente" permanentemente y `get_user_avatar` nunca vuelve a reintentarlo en toda la vida del proceso. Sin timeout ni reintento.

7. **`avatar_cache` sin límite ni expiración** — `SteamManager.gd:14`, poblado en línea 161, nunca se borra en ningún punto del código. Crece indefinidamente durante toda la vida del proceso (autoload persistente) por cada SteamID distinto visto en cualquier sesión/lobby. Severidad baja (texturas 128×128) pero es crecimiento no acotado real.

8. **Null-check probablemente inefectivo tras `Image.create_from_data`** — `SteamManager.gd:154-155`. `Image.create_from_data()` en Godot 4 no retorna `null` ante datos malformados (emite error de motor y devuelve una `Image` vacía). El `if img == null:` casi seguro nunca se cumple, por lo que un `avatar_buffer` corrupto o de tamaño incorrecto no queda realmente filtrado — puede seguir hasta `resize()`/`create_from_image()` sobre una imagen inválida. **Fix sugerido:** validar `avatar_buffer.size() == avatar_size*avatar_size*4` antes de `create_from_data`, o chequear `img.is_empty()` en vez de `== null`.

9. **Falta null-check en `SteamLobbyManager.gd:90`** — `ManagerLocator.get_steam_manager().get_auth_ticket_for_peer(host_peer_id)` se llama sin verificar que `get_steam_manager()` no sea `null`, a diferencia de todos los demás call sites del proyecto.

10. **Forma dual de `pending_clients`** — mismo diccionario usado con dos shapes distintas según el proceso sea host o cliente (ver sección 2). No rompe nada en la topología actual (estrictamente estrella), pero es frágil ante cualquier cambio futuro de topología.

11. **Sin verificación de membresía del lobby antes de autenticar (defensa en profundidad)** — el host valida cualquier peer que llegue por `SteamMultiplayerPeer` y presente un ticket válido, pero nunca cruza contra `Steam.getNumLobbyMembers`/`getLobbyMemberByIndex` para confirmar que ese `steam_id` es efectivamente miembro del lobby actual. Un usuario Steam con ticket válido que obtenga el SteamID del host por otra vía podría intentar autenticarse sin pasar por la invitación de lobby. Recomendado como capa adicional, no como fix crítico (la validación de ticket por sí sola ya impide suplantación de identidad).

12. **`APP_ID = 480`** (`SteamManager.gd:3`) — AppID de prueba de Valve. Bloqueante para release si el juego se va a distribuir: reemplazar por AppID real registrado en Steamworks.

13. **`SteamManager` sin `class_name`** — tipado débil vía `ManagerLocator.get_steam_manager() -> Node`; todo el código downstream llama métodos Steam-específicos sobre una referencia `Node` sin cast. Agregar `class_name SteamManager` mejoraría autocompletado y detección de errores en tiempo de edición.

14. **Inconsistencia `is_instance_valid()` vs `!= null`** — `MainMenuFlow._leave_network_session` es el único lugar que usa `is_instance_valid()` para chequear `steam_mgr`/`lobby_manager`; el resto del código (`WaitingRoom.gd`, `NetworkModeSelect.gd`, `SteamLobbyManager.gd`) usa `!= null`/truthiness simple. Bajo riesgo hoy (son autoload/hijo con ciclo de vida estable), pero vale estandarizar.

15. **`leave_lobby()` no limpia `connected_clients`/`pending_clients` directamente** (`SteamLobbyManager.gd:34-40`) — depende enteramente de que `multiplayer.peer_disconnected` se dispare para cada peer durante el desmontaje. Si un peer se destruye abruptamente en vez de desconectarse con gracia, podrían quedar entradas stale para la siguiente sesión hosteada/unida.

---

### Resumen ejecutivo

El flujo de autenticación (ticket → RPC → `beginAuthSession` → validación) está bien encadenado y el `steam_id` del lado host siempre se resuelve desde el transporte, no del payload del cliente — correcto contra suplantación básica. Los puntos más importantes a corregir antes de un release:

- **Bloqueante:** `APP_ID` de prueba (#12).
- **Alta prioridad:** fuga de sesión Steam en desconexión pendiente (#1), peer fantasma sin `steam_id` resuelto (#2).
- **Media prioridad:** timeout asimétrico (#3), ticket local sin cancelar en sobrescritura (#4), null-check inefectivo de avatar (#8).
- **Baja prioridad / cleanup:** el resto (crecimiento no acotado de caches, inconsistencias de estilo, defensa en profundidad de membresía de lobby).
