extends SceneTree

## Bakes the sprite/enemy data resources from the tables below:
##   resources/sprite_frames/{hero,enemy,tc}_*.tres   SpriteFrames
##   resources/enemies/*.tres                   EnemyType
##   resources/floors/enemy_pool_f1..f5.tres    EnemyPool
## and links hero sprite_frames + FloorConfig.enemy_pools. Run once, then tune
## the .tres by hand (re-running overwrites them: hp/damage mult + pools here were
## synced with the balance-4 values, but the role/base-stat/Nexus fields are NOT baked):
##   godot --headless --path . --script res://tools/build_characters.gd

const HEROES := {  # character_id -> 0x72 hero prefix (assets/art/characters)
	"warrior": "knight_m",
	"mage": "wizzard_m",
	"rogue": "elf_m",
	"tank": "dwarf_m",
}
const TC_SHEET := "res://assets/art/characters/tiny_creatures_packed.png"
const IDLE_FPS := 6.0
const RUN_FPS := 10.0

## id, name, art ("0x72:<prefix>" animated | "tc:<x>,<y>" static), behavior
## (0 Swarm, 1 Sapper, 2 Hunter), hp_mult, damage_mult, speed_mult, visual_scale
const TYPES := [
	["goblin", "Goblin", "0x72:goblin", 0, 1.0, 1.0, 1.0, 1.0],
	["skelet", "Esqueleto", "0x72:skelet", 0, 1.0, 1.0, 0.9, 1.0],
	["tiny_zombie", "Zombi menor", "0x72:tiny_zombie", 1, 0.8, 1.0, 0.9, 1.0],
	["imp", "Diablillo", "0x72:imp", 0, 0.88, 1.04, 1.3, 1.0],
	["masked_orc", "Orco enmascarado", "0x72:masked_orc", 0, 1.3, 1.08, 0.9, 1.0],
	["tc_eyeball", "Ojo flotante", "tc:5,0", 2, 1.0, 1.0, 1.0, 1.0],
	["orc_warrior", "Orco guerrero", "0x72:orc_warrior", 0, 1.36, 1.12, 0.95, 1.0],
	["orc_shaman", "Orco chamán", "0x72:orc_shaman", 2, 1.0, 1.2, 1.0, 1.0],
	["tc_wolf", "Lobo", "tc:3,2", 0, 1.12, 1.08, 1.4, 1.0],
	["tc_fire_skull", "Calavera ígnea", "tc:3,0", 1, 1.0, 1.16, 1.0, 1.0],
	["chort", "Chort", "0x72:chort", 0, 1.48, 1.16, 1.1, 1.0],
	["wogol", "Wogol", "0x72:wogol", 2, 1.3, 1.2, 1.0, 1.0],
	["big_zombie", "Zombi gigante", "0x72:big_zombie", 1, 2.2, 1.2, 0.7, 1.0],
	["tc_ogre", "Ogro verde", "tc:2,4", 1, 1.72, 1.24, 0.8, 1.2],
	["tc_red_imp", "Demonio rojo", "tc:8,3", 0, 1.12, 1.2, 1.3, 1.0],
	["ogre", "Ogro", "0x72:ogre", 1, 2.5, 1.32, 0.75, 1.0],
	["big_demon", "Gran demonio", "0x72:big_demon", 2, 2.2, 1.4, 0.9, 1.0],
	["necromancer", "Nigromante", "0x72:necromancer", 2, 1.48, 1.4, 1.0, 1.0],
	["tc_dragon", "Dragón", "tc:3,3", 2, 1.9, 1.4, 1.1, 1.3],
	["tc_demon", "Demonio mayor", "tc:3,12", 0, 1.6, 1.32, 1.1, 1.2],
]
## Floor 1..5 rosters: [type id, weight]. Weak types drop out, tougher/odder ones join.
const POOLS := [
	[["goblin", 5], ["skelet", 4], ["tiny_zombie", 2]],
	[["goblin", 3], ["skelet", 2], ["tiny_zombie", 2], ["imp", 3], ["masked_orc", 3], ["tc_eyeball", 1]],
	[["skelet", 2], ["imp", 2], ["masked_orc", 3], ["orc_warrior", 3], ["orc_shaman", 2], ["tc_wolf", 3], ["tc_fire_skull", 2]],
	[["masked_orc", 3], ["orc_warrior", 3], ["chort", 3], ["wogol", 1], ["big_zombie", 1], ["tc_ogre", 1], ["tc_red_imp", 3], ["tc_wolf", 3]],
	[["chort", 3], ["orc_warrior", 2], ["ogre", 2], ["big_demon", 1], ["necromancer", 1], ["tc_dragon", 1], ["tc_demon", 3], ["tc_ogre", 2]],
]


func _init() -> void:
	for character_id in HEROES:
		_bake_hero(character_id, HEROES[character_id])
	var types: Dictionary = {}
	for row in TYPES:
		types[row[0]] = _bake_type(row)
	var pools: Array[EnemyPool] = []
	for i in POOLS.size():
		var pool := EnemyPool.new()
		var weights := PackedFloat32Array()
		for entry in POOLS[i]:
			pool.types.append(types[entry[0]])
			weights.append(float(entry[1]))
		pool.weights = weights
		_save(pool, "res://resources/floors/enemy_pool_f%d.tres" % (i + 1))
		pools.append(load("res://resources/floors/enemy_pool_f%d.tres" % (i + 1)))
	var config := load("res://resources/floors/default_floor_config.tres") as FloorConfig
	config.enemy_pools = pools
	_save(config, "res://resources/floors/default_floor_config.tres")
	quit()


func _frames_from(dir: String, prefix: String, animations: Dictionary) -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	for anim in animations:
		var pattern: String = animations[anim][0]
		var paths := _sequence("res://assets/art/%s/%s" % [dir, pattern % prefix])
		if paths.is_empty():
			continue
		frames.add_animation(anim)
		frames.set_animation_speed(anim, animations[anim][1])
		frames.set_animation_loop(anim, animations[anim][2])
		for path in paths:
			frames.add_frame(anim, load(path))
	return frames


## `<base>_f0.png`, `_f1.png`... until one is missing.
func _sequence(base_pattern: String) -> Array[String]:
	var paths: Array[String] = []
	var i := 0
	while ResourceLoader.exists(base_pattern + "_f%d.png" % i):
		paths.append(base_pattern + "_f%d.png" % i)
		i += 1
	return paths


func _bake_hero(character_id: String, prefix: String) -> void:
	var frames := _frames_from("characters", prefix, {
		"idle": ["%s_idle_anim", IDLE_FPS, true],
		"run": ["%s_run_anim", RUN_FPS, true],
		"hit": ["%s_hit_anim", 1.0, false],
	})
	var path := "res://resources/sprite_frames/hero_%s.tres" % prefix
	_save(frames, path)
	var data := load("res://resources/characters/%s.tres" % _character_file(character_id)) as CharacterData
	data.sprite_frames = load(path)
	_save(data, "res://resources/characters/%s.tres" % _character_file(character_id))


func _character_file(character_id: String) -> String:
	return character_id  # warrior/mage/rogue/tank.tres


func _bake_type(row: Array) -> EnemyType:
	var art: String = row[2]
	var frames: SpriteFrames
	var path := "res://resources/sprite_frames/%s_%s.tres" % ["tc" if art.begins_with("tc:") else "enemy", row[0].trim_prefix("tc_")]
	if art.begins_with("tc:"):
		frames = _tc_frames(art.trim_prefix("tc:"))
	else:
		var prefix := art.trim_prefix("0x72:")
		frames = _frames_from("enemies", prefix, {
			"idle": ["%s_idle_anim", IDLE_FPS, true],
			"run": ["%s_run_anim", RUN_FPS, true],
		})
		if not frames.has_animation("idle"):  # single-animation monsters: reuse for both
			frames = _frames_from("enemies", prefix, {"idle": ["%s_anim", IDLE_FPS, true], "run": ["%s_anim", RUN_FPS, true]})
	_save(frames, path)
	var enemy := EnemyType.new()
	enemy.id = row[0]
	enemy.display_name = row[1]
	enemy.behavior = row[3]
	enemy.sprite_frames = load(path)
	enemy.hp_mult = row[4]
	enemy.damage_mult = row[5]
	enemy.speed_mult = row[6]
	enemy.visual_scale = row[7]
	var enemy_path := "res://resources/enemies/%s.tres" % row[0]
	_save(enemy, enemy_path)
	return load(enemy_path)


## Tiny Creatures are single static sprites: one-frame "idle" (CharacterVisual bounces it).
func _tc_frames(xy: String) -> SpriteFrames:
	var parts := xy.split(",")
	var atlas := AtlasTexture.new()
	atlas.atlas = load(TC_SHEET)
	atlas.region = Rect2(int(parts[0]) * 16, int(parts[1]) * 16, 16, 16)
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	frames.add_animation("idle")
	frames.set_animation_speed("idle", IDLE_FPS)
	frames.add_frame("idle", atlas)
	return frames


func _save(resource: Resource, path: String) -> void:
	var err := ResourceSaver.save(resource, path)
	if err != OK:
		printerr("save failed: ", path, " ", error_string(err))
