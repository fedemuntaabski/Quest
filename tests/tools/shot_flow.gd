extends SceneTree

## Visual check of the run flow (needs a real window, NOT --headless), through the
## real Main orchestrator: menu, floor, hero sheet with a hint up, Esc menu, downed
## hero, victory and death screens. Saves <out_dir>/flow_*.png.
##   godot --path . --resolution 1920x1080 --script res://tests/tools/shot_flow.gd -- <out_dir>

const SLOT := 93

var _dir: String
var _main: Main


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	_dir = args[0] if args.size() > 0 else "user://"
	await process_frame
	_main = (load("res://scenes/Main.tscn") as PackedScene).instantiate() as Main
	root.add_child(_main)
	await _wait(3.0)  # past the first fade, slow on a cold start
	await _shot("menu")
	var select := HeroSelectMenu.new()
	select.set_anchors_preset(Control.PRESET_FULL_RECT)
	var over_menu := CanvasLayer.new()
	over_menu.layer = 150
	root.add_child(over_menu)
	over_menu.add_child(select)
	select.open()
	await _wait(0.8)
	await _shot("hero_select")
	over_menu.queue_free()
	await _wait(0.2)

	root.get_node("SaveManager").load_game(SLOT)
	root.get_node("GameSession").set_selection(["warrior", "mage"] as Array[String])
	await _main.start_gameplay()
	await _wait(1.0)
	var main2d := _world()
	await _shot("floor")

	var hud: HUDController = ManagerLocator.get_hud()
	hud.building_menu.open_category(0)
	await _wait(0.4)
	await _shot("build")
	hud.building_menu.open_category(hud.building_menu.RESEARCH_TAB)
	await _wait(0.4)
	await _shot("research")
	hud.building_menu.close_menu()
	await _wait(0.2)
	hud.show_hint("Sala de Descanso", "Una pista larga que antes tapaba el encabezado de la ficha de héroe.", QuestPalette.GOLD_LIGHT)
	var hero: Player = main2d.heroes[0]
	hud.character_popup.open_for(hero.stats, hero.character_data)
	await _wait(0.3)
	await _shot("sheet_hint")
	hud.character_popup.close()
	await _wait(0.2)

	root.push_input(_action(&"ui_cancel"))
	await _wait(0.5)
	await _shot("pause")
	root.push_input(_action(&"ui_cancel"))
	await _wait(0.5)

	main2d.heroes[1].stats.take_damage(100000)
	await _wait(0.5)
	await _shot("downed")

	main2d.extraction_manager.declare_victory()
	await _wait(2.4)
	await _shot("victory")

	paused = false
	await _main.reload_gameplay()
	await _wait(0.5)
	_world()._on_player_died()
	await _wait(2.4)
	await _shot("death")

	root.get_node("SaveManager").delete_save(SLOT)
	quit()


func _world() -> Node:
	return _main.world_container.get_child(_main.world_container.get_child_count() - 1)


func _action(action: StringName) -> InputEventAction:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	return event


func _wait(sec: float) -> void:
	await create_timer(sec, true, false, true).timeout


func _shot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	var path := "%s/flow_%s.png" % [_dir, shot_name]
	root.get_texture().get_image().save_png(path)
	print("saved ", path)
