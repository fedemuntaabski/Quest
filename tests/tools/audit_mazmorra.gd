extends SceneTree

## mazmorra-31 phase 1 audit (headless, read-only): over N seeds x floors 1-5,
## room type counts, room sizes and how much of each room the tile plan decorates.
##   godot --headless --path . --script res://tests/tools/audit_mazmorra.gd -- [seeds]

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var seeds := int(args[0]) if args.size() > 0 else 100
	var config := load("res://resources/floors/default_floor_config.tres") as FloorConfig
	var visual := load("res://resources/maps/map_visual_config.tres") as MapVisualConfig
	for f in range(1, 6):
		var types := {}
		var sizes := {}
		var rooms := 0
		var floor_tiles := 0
		var decor_tiles := 0
		var plain := 0
		var maps_with := {}
		for s in seeds:
			var layout := MapGenerator.generate_floor(hash([s, f]), config, f)
			var plan := MapTileRenderer.build_plan(layout, visual)
			var seen := {}
			for room in layout.rooms:
				rooms += 1
				var t: String = RoomData.RoomType.keys()[room.get_room_type()]
				types[t] = int(types.get(t, 0)) + 1
				seen[t] = true
				var k := "%dx%d" % [room.size.x, room.size.y]
				sizes[k] = int(sizes.get(k, 0)) + 1
				var z: Dictionary = plan["zones"][room.id]
				floor_tiles += z["floor"].size()
				decor_tiles += z["decor"].size()
				for tile in z["floor"]:
					if Vector2i(z["floor"][tile].y, z["floor"][tile].z) == DungeonTiles.FLOOR_PLAIN:
						plain += 1
			for t in seen:
				maps_with[t] = int(maps_with.get(t, 0)) + 1
		print("piso %d: %.1f salas/mapa; tipos %s; mapas con tipo %s; tamaños %s; decor %.1f%% del suelo de sala; suelo liso %.0f%%" % [
			f, float(rooms) / seeds, types, maps_with, sizes, 100.0 * decor_tiles / floor_tiles, 100.0 * plain / floor_tiles])
	quit()
