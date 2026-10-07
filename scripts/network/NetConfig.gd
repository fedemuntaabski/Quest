class_name NetConfig
extends Resource

## NetConfig (coop-12): co-op tunables, `resources/net/net_config.tres`.

enum OrphanMode {
	HOST_CONTROL,  ## a disconnected player's heroes go to the host
	DEFENSIVE_AI,  ## they stay ownerless: they hold position and auto-attack
}

@export_group("Players")
@export var player_colors: Array[Color] = [
	Color(0.35, 0.65, 1.0), Color(1.0, 0.55, 0.2), Color(0.45, 0.9, 0.4), Color(0.9, 0.4, 0.85)]
@export var max_players := 4

@export_group("Sync")
## Hero/enemy position snapshots per second (unreliable).
@export var snapshot_hz := 15.0
## Full RunState resend period (reliable), on top of the event-driven ones.
@export var full_state_sec := 1.0
## Desync check period (host sends its state hash).
@export var hash_sec := 5.0
## Client render delay for interpolation.
@export var interp_delay_sec := 0.1
@export var ping_sec := 2.0

@export_group("Commands")
@export var max_cmds_per_sec := 20

@export_group("Robustness")
@export var orphan_mode: OrphanMode = OrphanMode.HOST_CONTROL

@export_group("Tactical pause")
## Seconds a pause vote stays open; unanswered votes do not block it.
@export var pause_vote_window_sec := 5.0
## A co-op tactical pause ends by itself after this many seconds.
@export var max_pause_sec := 30.0

@export_group("Chat")
@export var chat_messages: Array[String] = [
	"¡Ayuda!", "Vamos", "Esperen", "Enemigos aquí", "Necesito recursos", "¡Bien hecho!"]


func color_for(index: int) -> Color:
	return player_colors[index % player_colors.size()] if not player_colors.is_empty() else Color.WHITE
