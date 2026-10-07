# Co-op (session/coop-12): pruebas

Co-op de 2 a 4 jugadores con host autoritativo. Este documento dice qué está
probado automáticamente, cómo probar a mano lo que falta (sobre todo Steam real)
y qué logs mirar.

## 1. Pruebas automáticas (headless)

`powershell -File tools/run_tests.ps1 -Filter net` (o la suite completa):

| Test | Qué cubre |
|---|---|
| `test_net_transport` | ENet host/join en un proceso, códigos `ip:puerto`, cierre limpio |
| `test_net_lobby` | sala: elección sin repetir, cupo por jugador, listo, inicio con semilla compartida |
| `test_net_commands` | validación en el host de cada comando (dueño del héroe, costos, args mal formados, límite de órdenes, el cliente no muta nada) |
| `test_net_ownership` | selección solo de héroes propios, anillo/borde del color del dueño, héroe sin dueño en gris |
| `test_net_pause` | pausa por votación (mayoría, ventana, retirar voto, tope de pausa), velocidad solo del host, el cliente refleja `time_scale`, Esc online no pausa |
| `test_net_robustness` | orfandad (HOST_CONTROL / DEFENSIVE_AI), recuerdo por token, reset de sesión, fin de run al perder al host |
| `test_net_hud` | lista de jugadores con ping, avisos de unión/salida, chat predefinido, tecla T, ping de mapa |
| `test_net_sync` | **dos procesos Godot** por ENet local (ver abajo) |

`test_net_sync` lanza `tests/tools/net_client_probe.gd` como segundo proceso
headless. Comprueba: misma semilla y mapa, snapshots, una puerta abierta por el
host vista en el cliente, un movimiento pedido por el cliente y ejecutado por el
host, el rechazo de mover un héroe ajeno, una medición de ping, un hash de estado
sin desincronización y la **reconexión** (el cliente se va, sus héroes pasan al
host, vuelve con el mismo token y recupera héroes y salas descubiertas).
Log del cliente: `%APPDATA%\Godot\app_userdata\Quest\net_probe_client.log`.

Steam real (con el cliente de Steam abierto): `godot --headless --path . --script res://tests/tools/steam_probe.gd`
crea un lobby Friends Only, lo muestra como código y lo cierra.

## 2. Pruebas manuales

### 2.1 Dos instancias en la misma PC (ENet, sin Steam)

Cada instancia necesita su propio token de reconexión y nombre
(comparten `user://`):

```
godot --path . -- --net=enet --net-name=Ana --net-token=ana
godot --path . -- --net=enet --net-name=Beto --net-token=beto
```

1. Ana: Iniciar Partida → **Host**. La sala muestra el código `127.0.0.1:7777`.
2. Beto: Iniciar Partida → escribir `127.0.0.1:7777` → **Unirse**.
3. En la sala: cada uno elige 1 héroe (no se puede repetir), ambos "Listo"; Ana inicia.
4. Verificar en la partida:
   - mismo mapa en ambas ventanas; cada uno ve su anillo de color y solo puede seleccionar sus héroes;
   - Beto abre una puerta → Ana ve la sala nueva y el polvo sube igual en ambos;
   - construir/investigar desde cualquiera descuenta de los recursos compartidos;
   - Espacio en una ventana muestra "PAUSA? 1/2"; al votar la otra (o a los 5 s) se pausa en las dos; se levanta sola a los 30 s;
   - X en Beto muestra "Solo el anfitrión cambia la velocidad"; X en Ana pone 2x en ambos;
   - T abre el chat; un mensaje aparece en las dos ventanas con el color del jugador;
   - Alt + clic izquierdo en una sala descubierta: anillo en el mundo y en el minimapa de ambos;
   - lista de jugadores arriba a la izquierda con el ping de Beto.
5. Cerrar la ventana de Beto: Ana ve "Beto salió de la partida" y controla su héroe.
   Volver a abrirla con el mismo `--net-token=beto` y unirse otra vez: entra a la partida en curso
   (mismo piso, salas descubiertas, recupera su héroe).
6. Cerrar la ventana de Ana: Beto ve la pantalla de fin "El anfitrión abandonó la partida" con el resumen y solo "Volver al menú".

### 2.2 Steam real (dos cuentas o AppID 480 de prueba)

El proyecto usa el AppID 480 (Spacewar) mientras no haya uno propio. Hace falta
**dos PCs** (o dos máquinas virtuales), cada una con su cuenta de Steam abierta;
las cuentas deben ser amigas para la invitación Friends Only.

1. PC A: Iniciar Partida → **Host**. Se crea un lobby Friends Only; el código es el id del lobby.
2. PC B: dos caminos:
   - **Invitación**: en A, botón Invitar (overlay de Steam, Shift+Tab) → B acepta desde el overlay/chat de Steam;
   - **Código**: B escribe el id del lobby → Unirse.
3. Verificar en el log de A "Client authenticated peer_id=… steam_id=…" (validación del ticket de Steam
   obligatoria, 15 s de timeout) antes de que B aparezca en la sala.
4. Repetir los puntos 3–6 de 2.1. Para la reconexión con Steam el token es el SteamID (no hace falta `--net-token`).
5. Con 3–4 jugadores: el cupo de héroes por jugador baja a 1 y la votación de pausa pide mayoría (2 de 3, 3 de 4).

## 3. No verificado

- Nada de Steam con dos cuentas: lobby real con otro jugador, invitación por overlay, autenticación del ticket, reconexión por SteamID, latencia real.
- Ninguna partida co-op en una ventana real (todo lo de 2.1 es manual): sensación de la interpolación, legibilidad de anillos/bordes de color, posición del chat y la lista de jugadores, ping de mapa visible sobre salas oscuras.
- 3 y 4 jugadores conectados a la vez (los tests usan 2 procesos; 3-4 solo como datos en un proceso).
- DEFENSIVE_AI en una partida real (solo el cambio de dueño está probado).
- Cambio de piso con un cliente reconectado a mitad de piso, y reconexión durante la fase de extracción.
- Lo que el host no replica (por diseño): proyectiles de héroes a distancia en el cliente (se ven el impacto y la vida), cooldown de consumibles en el cliente.

## 4. Logs clave (`QuestLogger`, categoría NETWORK)

| Log | Dónde | Significa |
|---|---|---|
| `Hosting (enet\|steam) code=…` | host | sesión abierta, código para unirse |
| `Connected to host as peer N` | cliente | conexión establecida |
| `Client authenticated peer_id=…` / `Rejecting client … reason=…` | host, Steam | resultado del ticket de Steam |
| `Player N joined the lobby: X` | host | entró a la sala |
| `start_run seed=S floor=F party=[…]` | todos | arranque compartido (la semilla debe coincidir) |
| `Peer N loaded floor F` | host | el cliente cargó el piso; empieza a recibir estado |
| `cmd X from N … -> ok\|motivo` | host (DEBUG) | comando validado o rechazado |
| `Desync: host hash A != local B, resync requested` / `State hash OK` | cliente | chequeo periódico de desincronización (si falla pide el estado completo) |
| `Tactical pause on\|off` | host | resultado de la votación |
| `Heroes […] of peer N -> host\|defensive AI` | host | un jugador se cayó en plena run |
| `Player N rejoined the run: …` / `Rejoining run seed=…` | host / cliente | reconexión |
| `Peer N refused: run in progress` | host | alguien sin token de esta run intentó entrar |
| `Host lost: the run ends` | cliente | el host se fue |
| `Session closed (motivo)` | todos | cierre de la sesión |
