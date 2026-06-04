extends Node2D
class_name FloatingTextManager

@export var float_distance: float = 18.0
@export var float_time: float = 0.6
@export var heal_float_time: float = 1.05
@export var heal_float_distance: float = 22.0

const FloatingTextScene := preload("res://scenes/FloatingText.tscn")

var _bound_stats: CharacterStats = null


func _ready() -> void:
	add_to_group("floating_text_manager")
	call_deferred("_try_bind_player_stats")


# =========================================================
# 🎯 SIMPLE SPAWN (WORLD POSITION)
# =========================================================
func spawn_text(world_pos: Vector2, text: String, color: Color, crit: bool = false, intensity: float = 1.0) -> void:
	var ft := _create_text()

	if ft == null:
		return

	ft.float_distance = float_distance
	ft.float_time = float_time
	ft.global_position = world_pos

	add_child(ft)

	ft.setup(text, color, crit, intensity)


func bind_character_stats(stats: CharacterStats) -> void:
	if _bound_stats == stats:
		return
	if _bound_stats and _bound_stats.potion_used.is_connected(_on_potion_used):
		_bound_stats.potion_used.disconnect(_on_potion_used)

	_bound_stats = stats
	if _bound_stats and not _bound_stats.potion_used.is_connected(_on_potion_used):
		_bound_stats.potion_used.connect(_on_potion_used)


func _try_bind_player_stats() -> void:
	var ps := ManagerLocator.get_player_stats()
	if ps == null or ps.stats == null:
		return
	bind_character_stats(ps.stats)


func _on_potion_used(heal_amount: int, _remaining: int) -> void:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	spawn_text_from_host(player, "+%d" % heal_amount, QuestPalette.COMBAT_TEXT_HEAL, false, Vector2(-12, -28), 1.0, true)


# =========================================================
# 🎯 HOST BASED SPAWN (ENEMIES / PLAYERS)
# =========================================================
func spawn_text_from_host(
	host: Node2D,
	text: String,
	color: Color,
	crit: bool = false,
	local_offset: Vector2 = Vector2(-12, -28),
	intensity: float = 1.0,
	healing: bool = false
) -> void:

	if host == null:
		return

	var ft := _create_text()

	if ft == null:
		return

	var random_offset := Vector2(
		randf_range(-6 if not healing else -4, 6 if not healing else 4),
		randf_range(-3 if not healing else -2, 3 if not healing else 2)
	)

	if healing:
		ft.float_distance = heal_float_distance
		ft.float_time = heal_float_time
		ft.heal_float_time = heal_float_time
		ft.heal_float_distance = heal_float_distance
	else:
		ft.float_distance = float_distance
		ft.float_time = float_time

	ft.global_position = host.global_position + local_offset + random_offset

	add_child(ft)

	ft.setup(text, color, crit, intensity, healing)


# =========================================================
# 🧠 INTERNAL CREATION
# =========================================================
func _create_text() -> FloatingText:
	var instance := FloatingTextScene.instantiate()

	if instance is FloatingText:
		return instance

	return null