extends Node2D
class_name Player

## Player: test-scene actor. Owns a CharacterStats component and a grid cell
## position. Moves freely — no turn/AP gating.

## Emitted by set_zone() (spawn and every arrival). Minimap listens.
signal zone_changed(zone_id: String)

@onready var stats: CharacterStats = $Stats
@onready var animated_sprite: CharacterVisual = $AnimatedSprite2D
@onready var hurtbox: HurtboxComponent = $Hurtbox
@onready var hitbox: HitboxComponent = $Hitbox

var character_data: CharacterData = null
var current_zone_id: String = ""
var is_carrying_nexo: bool = false
## Sprite-only shift so heroes sharing a zone don't overlap (PartyConfig);
## position, zone logic and hit/hurtboxes stay on the zone center.
var sprite_offset: Vector2 = Vector2.ZERO

## grid_pos is the cell under the hero's world position — debug/logging only.
## Movement, door access and reachability all key off current_zone_id.
var grid_pos: Vector2i = Vector2i.ZERO

var _last_hp: int = -1


func configure(data: CharacterData) -> void:
	# Called before add_child(); @onready vars aren't valid yet, so just stash
	# the reference — actual visual application happens in _ready().
	character_data = data


func _ready() -> void:
	add_to_group("player")
	# Hitbox follows CharacterStats (base from CharacterData + in-run upgrades),
	# so wire it before register() re-applies upgrades.
	stats.attack_changed.connect(hitbox.configure)
	animated_sprite.position += sprite_offset
	if character_data:
		stats.hero_id = character_data.character_id
		stats.character_name = character_data.display_name
		stats.base_hp = character_data.base_hp
		stats.set_base_attack(character_data.attack_damage, character_data.attack_interval)
		_apply_character_visuals(character_data)
	var player_stats := ManagerLocator.get_player_stats()
	if player_stats:
		player_stats.register(stats)
	hurtbox.hurt.connect(_on_hurt)
	_last_hp = stats.current_hp
	stats.hp_changed.connect(_on_hp_changed)


## HP dropping = a hit: blink white (heals and level-ups only raise HP).
func _on_hp_changed(current_hp: int, _max_hp: int) -> void:
	if _last_hp >= 0 and current_hp < _last_hp:
		animated_sprite.play_hit()
	_last_hp = current_hp


func _on_hurt(amount: int) -> void:
	if not stats.is_alive():
		return
	stats.take_damage(amount)
	QuestLogger.info(QuestLogger.Category.COMBAT, "Hero took %d damage (%d/%d HP)." % [amount, stats.current_hp, stats.max_hp])


func _apply_character_visuals(data: CharacterData) -> void:
	if data.sprite_frames == null or animated_sprite == null:
		return
	animated_sprite.setup(data.sprite_frames)
	# Hurtbox follows the drawn body (its shape resource is shared by every
	# Player instance, so duplicate). The attack Hitbox (AoE) is independent.
	var shape := hurtbox.get_node("CollisionShape2D") as CollisionShape2D
	var circle := shape.shape.duplicate() as CircleShape2D
	circle.radius = animated_sprite.fit_radius()
	shape.shape = circle
	shape.position = animated_sprite.body_center() - animated_sprite.position


func set_grid_position(cell: Vector2i, tilemap: TileMapLayer) -> void:
	grid_pos = cell
	global_position = GridUtils.cell_to_world(tilemap, cell)


func set_zone(zone_id: String, center: Vector2, tilemap: TileMapLayer) -> void:
	current_zone_id = zone_id
	global_position = center
	grid_pos = GridUtils.world_to_cell(tilemap, center)
	zone_changed.emit(zone_id)


func can_accept_input() -> bool:
	return stats != null and stats.is_alive()


func pick_up_nexo() -> void:
	is_carrying_nexo = true
