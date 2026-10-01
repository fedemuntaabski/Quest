extends SceneTree

## Room type display (session fix-3): every RoomType except COMBAT has an entry in
## resources/maps/room_type_visual_config.tres with a name and color; Rest/Loot/
## Elite/Generator (the generated types) also have icon, banner and props. The tile plan stays
## deterministic and special props only land in rooms of their own type.
##   godot --headless --path . --script res://tests/test_room_type_visuals.gd

const FLOOR_CONFIG_PATH := "res://resources/floors/default_floor_config.tres"
const VISUAL_PATH := "res://resources/maps/map_visual_config.tres"
const IMPLEMENTED := [RoomData.RoomType.REST, RoomData.RoomType.LOOT, RoomData.RoomType.ELITE, RoomData.RoomType.GENERATOR]

var failures: Array[String] = []


func _initialize() -> void:
	var config := load(FLOOR_CONFIG_PATH) as FloorConfig
	var visual := load(VISUAL_PATH) as MapVisualConfig
	_check_entries(visual, config)
	_check_generation(config)
	_check_plan(visual, config)
	for failure in failures:
		printerr("FAIL: ", failure)
	print("test_room_type_visuals: %s (%d failures)" % ["OK" if failures.is_empty() else "FAILED", failures.size()])
	quit(0 if failures.is_empty() else 1)


func _check_entries(visual: MapVisualConfig, config: FloorConfig) -> void:
	if visual.room_type_visuals == null:
		failures.append("map_visual_config.tres has no room_type_visuals")
		return
	for type in RoomData.RoomType.values():
		var name: String = RoomData.RoomType.find_key(type)
		var entry := visual.room_type_visual(type)
		if type == RoomData.RoomType.COMBAT:
			if entry != null:
				failures.append("COMBAT must stay plain (no entry)")
			continue
		if entry == null:
			failures.append("%s: no RoomTypeVisual entry" % name)
			continue
		if entry.type != type or entry.display_name == "" or entry.color.a <= 0.0:
			failures.append("%s: entry needs matching type, display_name and opaque color" % name)
		var has_rule := config.get_room_type_rule(type) != null
		if type in IMPLEMENTED:
			if not has_rule:
				failures.append("%s: implemented type lost its RoomTypeRule" % name)
			if not (entry.show_marker and entry.icon and entry.banner_text != "" and not entry.decor_props.is_empty() and entry.decor_count > 0):
				failures.append("%s: needs marker, icon, banner and decor" % name)
			if visual.room_type_color(type) != entry.color:
				failures.append("%s: room_type_color() != entry color" % name)
	# Start/Exit keep their own hints: no badge/minimap marker, and the exit only
	# announces itself once discovered (banner), never before.
	for type in [RoomData.RoomType.START, RoomData.RoomType.EXIT]:
		if visual.room_type_color(type).a != 0.0:
			failures.append("%s must have no badge/minimap marker" % RoomData.RoomType.find_key(type))
	if visual.room_type_visual(RoomData.RoomType.EXIT).banner_text == "":
		failures.append("EXIT: no discovery banner")
	if visual.room_type_visual(RoomData.RoomType.START).banner_text != "":
		failures.append("START: banner would show at run start")


## Every implemented type must come out of the generator.
func _check_generation(config: FloorConfig) -> void:
	var seen: Dictionary = {}
	for s in 1000:
		var floor_index := 1 + s % 5
		var layout := MapGenerator.generate_floor(s, config, floor_index)
		for room in layout.rooms:
			seen[room.get_room_type()] = true
	for type in IMPLEMENTED:
		if not seen.has(type):
			failures.append("%s never generated in 1000 maps" % RoomData.RoomType.find_key(type))


## Same layout + config -> same plan; special props only in rooms of their type.
func _check_plan(visual: MapVisualConfig, config: FloorConfig) -> void:
	var special_props := 0
	for s in 40:
		var layout := MapGenerator.generate_floor(s, config, 1 + s % 5)
		var plan := MapTileRenderer.build_plan(layout, visual)
		if plan != MapTileRenderer.build_plan(layout, visual):
			failures.append("seed %d: plan not deterministic" % s)
		for room in layout.rooms:
			var entry := visual.room_type_visual(room.get_room_type())
			var allowed: Array[Vector2i] = []
			for coords in DungeonTiles.PROPS:
				allowed.append(coords)
			if entry:
				allowed.append_array(entry.decor_props)
			var decor: Dictionary = plan["zones"][room.id]["decor"]
			var own := 0
			for tile in decor:
				var v: Vector4i = decor[tile]
				var coords := Vector2i(v.y, v.z)
				if not allowed.has(coords):
					failures.append("seed %d '%s': prop %s not from the generic set or its own type" % [s, room.id, coords])
				if entry and entry.decor_props.has(coords) and not DungeonTiles.PROPS.has(coords):
					own += 1
			if entry and not entry.decor_props.is_empty() and entry.decor_count > 0:
				special_props += own
				if own == 0:
					failures.append("seed %d '%s' (%s): no type props planned" % [s, room.id, RoomData.RoomType.find_key(room.get_room_type())])
	if special_props == 0:
		failures.append("no special-room props planned in 40 maps")
	# Generic props of a plan must not depend on the type config.
	var bare := MapVisualConfig.new()
	var layout := MapGenerator.generate_floor(3, config, 3)
	var with_types := MapTileRenderer.build_plan(layout, visual)
	var without := MapTileRenderer.build_plan(layout, bare)
	for room in layout.rooms:
		var a: Dictionary = with_types["zones"][room.id]["decor"]
		var b: Dictionary = without["zones"][room.id]["decor"]
		for tile in b:
			if not a.has(tile) and room.get_room_type() == RoomData.RoomType.COMBAT:
				failures.append("generic prop %s of '%s' vanished when type props were configured" % [tile, room.id])
