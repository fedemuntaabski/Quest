class_name HazardSpawner
extends Node2D

## HazardSpawner (progresion-10): the floor's own trap (FloorTheme.trap_*). When a
## group is revealed each of its corridors rolls trap_chance (seeded per floor +
## corridor); a trap is a faint mark on the corridor that hurts the FIRST living
## hero who enters it (trap_damage x the floor's damage multiplier), then breaks.
## Built by Main2d like LootSpawner.

signal triggered(zone_id: String, hero: Player, damage: int)

const MARK_RADIUS := 10.0

## zone_id -> mark Node2D (armed traps only).
var traps: Dictionary = {}

var _room_manager: RoomManager
var _floor_manager: FloorManager
var _theme: FloorTheme
var _watched: Array[Player] = []


func setup(room_manager: RoomManager, door_turn_system: DoorTurnSystem, floor_manager: FloorManager) -> void:
	_room_manager = room_manager
	_floor_manager = floor_manager
	_theme = floor_manager.theme() if floor_manager else null
	door_turn_system.room_revealed.connect(_on_room_revealed)
	for hero in ManagerLocator.get_heroes():
		watch_hero(hero)


func watch_hero(hero: Player) -> void:
	if not _watched.has(hero):
		_watched.append(hero)
		hero.zone_changed.connect(_on_hero_zone_changed.bind(hero))


func _on_room_revealed(group_id: String, _cells: Array[Vector2i]) -> void:
	if _theme == null or _theme.trap_chance <= 0.0 or _theme.trap_damage <= 0:
		return
	for zone_id in _room_manager.get_group_zone_ids(group_id):
		if _room_manager.get_zone_kind(zone_id) != "corridor" or traps.has(zone_id):
			continue
		var rng := RandomNumberGenerator.new()
		rng.seed = hash([_floor_manager.map_seed, zone_id, "hazard"])
		if rng.randf() < _theme.trap_chance:
			arm(zone_id)


func arm(zone_id: String) -> void:
	var mark := Node2D.new()
	mark.name = "Trap_%s" % zone_id
	mark.position = _room_manager.get_center(zone_id)
	mark.z_index = 1
	var color := _theme.trap_color if _theme else Color.WHITE
	mark.draw.connect(func() -> void:
		mark.draw_circle(Vector2.ZERO, MARK_RADIUS, Color(color, 0.25))
		mark.draw_arc(Vector2.ZERO, MARK_RADIUS, 0.0, TAU, 16, Color(color, 0.7), 2.0))
	add_child(mark)
	traps[zone_id] = mark


func _on_hero_zone_changed(zone_id: String, hero: Player) -> void:
	var mark: Node2D = traps.get(zone_id)
	if mark == null or not hero.stats.is_alive():
		return
	traps.erase(zone_id)
	mark.queue_free()
	var mult := _floor_manager.enemy_damage_multiplier() if _floor_manager else 1.0
	var damage := maxi(1, roundi(_theme.trap_damage * mult))
	hero.stats.take_damage(damage)
	var text_mgr := ManagerLocator.get_floating_text_manager() as FloatingTextManager
	if text_mgr:
		text_mgr.spawn_text(hero.global_position + Vector2(0, -48), "¡%s! -%d" % [_theme.trap_name, damage], _theme.trap_color)
	var vfx := ManagerLocator.get_vfx_manager()
	if vfx:
		vfx.play(&"hit_sparks", hero.global_position, _theme.trap_color)
	triggered.emit(zone_id, hero, damage)
