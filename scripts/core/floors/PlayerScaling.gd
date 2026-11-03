extends Resource
class_name PlayerScaling

## PlayerScaling (calidad-13): enemy multipliers by number of human players
## (resources/floors/player_scaling.tres). Index = players - 1 (1..4); more
## players than entries reuse the last one. Stacks with the floor curve and the
## difficulty in FloorManager. Solo and 2 players field the same 2 heroes;
## 3 and 4 players field 3 and 4 (NetSession.heroes_per_player), which is what
## the hp/threat/cap rows pay for. Tuned with BalanceSim.scaling_rows().

const DEFAULT_PATH := "res://resources/floors/player_scaling.tres"

## Enemies per invasion / extraction wave (rounded). The main lever: with more
## heroes each one faces wave / party enemies, so the wave grows with the party.
@export var wave_mult: PackedFloat32Array = [1.0, 1.0, 1.0, 1.0]
@export var hp_mult: PackedFloat32Array = [1.0, 1.0, 1.0, 1.0]
@export var damage_mult: PackedFloat32Array = [1.0, 1.0, 1.0, 1.0]
@export var threat_mult: PackedFloat32Array = [1.0, 1.0, 1.0, 1.0]
@export var extra_max_enemies: PackedInt32Array = [0, 0, 0, 0]
@export var relic_hp_mult: PackedFloat32Array = [1.0, 1.0, 1.0, 1.0]


static func get_default() -> PlayerScaling:
	return load(DEFAULT_PATH) as PlayerScaling


## Human players in this run: the co-op session's players online, else 1.
static func current_players() -> int:
	var session := Net.session()
	return clampi(session.players.size(), 1, 4) if session and session.is_online() else 1


## `count` enemies scaled for `players` (at least `count`, never fewer).
func wave(count: int, players: int) -> int:
	return maxi(count, roundi(count * _pick(wave_mult, players, 1.0)))


func hp(players: int) -> float:
	return _pick(hp_mult, players, 1.0)


func damage(players: int) -> float:
	return _pick(damage_mult, players, 1.0)


func threat(players: int) -> float:
	return _pick(threat_mult, players, 1.0)


func relic_hp(players: int) -> float:
	return _pick(relic_hp_mult, players, 1.0)


func extra_enemies(players: int) -> int:
	return 0 if extra_max_enemies.is_empty() else extra_max_enemies[clampi(players - 1, 0, extra_max_enemies.size() - 1)]


static func _pick(values: PackedFloat32Array, players: int, fallback: float) -> float:
	return fallback if values.is_empty() else values[clampi(players - 1, 0, values.size() - 1)]
