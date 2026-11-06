extends SceneTree

## The ExitIndicator edge arrow never sits on the HUD's BottomBar (resources,
## build buttons, an open BuildingMenu): exit far below the screen -> the arrow
## stays above the bar's top.
##   godot --headless --path . --script res://tests/test_exit_arrow.gd

const MAIN2D_PATH := "res://scenes/Main2d.tscn"
const HUD_PATH := "res://scenes/hud/HUD.tscn"

var failures: Array[String] = []


func _initialize() -> void:
	_check_above()
	await _check_live()
	for failure in failures:
		printerr("FAIL: ", failure)
	print("test_exit_arrow: %s (%d failures)" % ["OK" if failures.is_empty() else "FAILED", failures.size()])
	quit(0 if failures.is_empty() else 1)


func _check_above() -> void:
	var rect := Rect2(0, 0, 100, 100)
	_expect(ExitIndicator.above(rect, 80.0) == Rect2(0, 0, 100, 80), "above(80) should cut the rect at 80")
	_expect(ExitIndicator.above(rect, INF) == rect, "above(INF) should keep the rect")
	_expect(ExitIndicator.above(rect, -5.0) == rect, "above() over the rect should keep it")


func _check_live() -> void:
	var main2d := (load(MAIN2D_PATH) as PackedScene).instantiate()
	root.add_child(main2d)
	await process_frame
	var hud := (load(HUD_PATH) as PackedScene).instantiate() as HUDController
	root.add_child(hud)
	await process_frame
	await process_frame

	var indicator := root.get_tree().get_first_node_in_group("exit_indicator") as ExitIndicator
	var config: MapVisualConfig = main2d.room_manager.visual_config
	var old_mode := config.exit_hint_mode
	config.exit_hint_mode = MapVisualConfig.ExitHintMode.ALWAYS
	_expect(indicator.is_hint_visible(), "hint should be visible in ALWAYS mode")

	var viewport := indicator.get_viewport()
	var size := viewport.get_visible_rect().size
	var to_world := viewport.get_canvas_transform().affine_inverse()
	for target in [Vector2(size.x / 2.0, size.y + 3000.0), Vector2(size.x * 0.3, size.y + 3000.0)]:
		indicator._marker.global_position = to_world * target
		for open_menu in [false, true]:
			if open_menu:
				hud.building_menu.open_category(0)
			else:
				hud.building_menu.close_menu()
			await process_frame
			var top := hud.get_bottom_bar_top()
			_expect(top < size.y, "BottomBar top %s should be on screen (menu %s)" % [top, open_menu])
			indicator._process(0.0)
			var arrow: Polygon2D = indicator._arrow
			_expect(arrow.visible, "arrow should show for an exit below the screen")
			_expect(arrow.position.y < top, "arrow y %s should be above the BottomBar top %s (target %s, menu %s)" % [arrow.position.y, top, target, open_menu])
	# Without the cut the same arrow would land on the bar: the check above is not vacuous.
	var full := viewport.get_visible_rect().grow(-config.arrow_margin)
	_expect(ExitIndicator.edge_point(full, Vector2(size.x / 2.0, size.y + 3000.0)).y >= hud.get_bottom_bar_top(), "uncut edge point should overlap the bar")

	config.exit_hint_mode = old_mode
	hud.queue_free()
	main2d.queue_free()
	await process_frame


func _expect(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
