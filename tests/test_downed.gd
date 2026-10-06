extends SceneTree

## heroes-9: a hero at 0 HP stays downed in its room (no attacks, grey) and the
## run goes on; a living ally in the same room revives it for Comida
## (UpgradeConfig.revive_*), else it is lost when the floor ends
## (GameSession.lost_ids). The run is lost when every hero is down or the Nexo
## breaks. Rest rooms heal over time paying Comida, frozen in the tactical pause.
##   godot --headless --path . --script res://tests/test_downed.gd

const MAIN2D_PATH := "res://scenes/Main2d.tscn"
const HUD_PATH := "res://scenes/hud/HUD.tscn"

var failures: Array[String] = []
var ps: Node
var resources: ResourceManager
var session: Node


func _initialize() -> void:
	ps = root.get_node("PlayerStats")
	resources = root.get_node("ResourceManager") as ResourceManager
	session = root.get_node("GameSession")
	session.clear()
	session.set_selection(["warrior", "mage"] as Array[String])
	ps.reset_run_upgrades()

	var world: Array = await _boot()
	await _check_downed_and_revive(world[0], world[1])
	await _check_rest(world[0])
	_check_floor_end_loss(world[0])
	_check_all_down(world[0])
	await _free_world(world)

	world = await _boot()
	_check_nexo_defeat(world[0])
	await _free_world(world)

	session.clear()
	Engine.time_scale = 1.0
	for failure in failures:
		printerr("FAIL: ", failure)
	print("test_downed: %s (%d failures)" % ["OK" if failures.is_empty() else "FAILED", failures.size()])
	quit(0 if failures.is_empty() else 1)


func _expect(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


func _check_downed_and_revive(main2d: Node, hud: HUDController) -> void:
	var a: Player = main2d.heroes[0]
	var b: Player = main2d.heroes[1]
	var gsm: GameStateManager = main2d.game_state_manager
	resources.reset_resources(0, 0, 0, 0)

	b.stats.take_damage(b.stats.max_hp)
	await process_frame
	_expect(b.is_downed() and gsm.is_active(), "one hero down: the run goes on")
	_expect(not b.hitbox.is_active(), "a downed hero doesn't attack")
	_expect(b.animated_sprite.rotation != 0.0, "a downed hero lies on the floor")
	_expect(not b.can_accept_input(), "a downed hero takes no orders")
	_expect(not root.get_node("SelectionManager").is_selected(b.stats.hero_id), "a downed hero leaves the selection")
	var portrait: HeroPortrait = hud._portraits.get(b.stats.hero_id)
	_expect(portrait != null and portrait.is_downed() and portrait.revive_button.visible, "portrait shows the downed state + Reanimar")

	var cost: int = ps.get_revive_cost(b.stats.hero_id)
	_expect(cost == 15, "floor 1 revive cost 15 (%d)" % cost)
	_expect(ps.get_revive_block_reason(b.stats.hero_id).begins_with("Falta Comida"), "no Comida: '%s'" % ps.get_revive_block_reason(b.stats.hero_id))
	_expect(not ps.revive_hero(b.stats.hero_id), "can't revive without Comida")
	_expect(portrait.revive_button.disabled, "Reanimar disabled without Comida")

	# The only ally walks away: nobody can touch it.
	resources.add_resource("food", 40)
	var other := _other_zone(main2d, a.current_zone_id)
	var home := a.current_zone_id
	a.set_zone(other, main2d.room_manager.get_center(other), main2d.floor_layer)
	_expect(ps.get_revive_block_reason(b.stats.hero_id) != "", "needs an ally in its room")
	a.set_zone(home, main2d.room_manager.get_center(home), main2d.floor_layer)
	_expect(ps.get_revive_block_reason(b.stats.hero_id) == "", "ally back + Comida: can revive")

	# Left click on the downed body = revive.
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = main2d.get_canvas_transform() * b.to_global(b.animated_sprite.body_center())
	main2d.hero_input._unhandled_input(click)
	_expect(b.stats.is_alive(), "left click on the downed hero revives it")
	_expect(resources.get_resource("food") == 40 - cost, "revive paid %d Comida (%d left)" % [cost, resources.get_resource("food")])
	_expect(b.stats.current_hp == roundi(b.stats.max_hp * 0.3), "revived at 30 %% HP (%d/%d)" % [b.stats.current_hp, b.stats.max_hp])
	_expect(b.hitbox.is_active() and b.animated_sprite.rotation == 0.0, "revived hero fights and stands again")
	await process_frame
	_expect(not portrait.is_downed() and not portrait.revive_button.visible, "portrait back to normal")
	_expect(portrait.is_low_blinking(), "30 % HP is below the low threshold: the bar blinks")
	b.stats.heal(b.stats.max_hp)
	_expect(not portrait.is_low_blinking(), "full HP stops the blink")


func _check_rest(main2d: Node) -> void:
	var a: Player = main2d.heroes[0]
	var fm: FloorManager = main2d.floor_manager
	var rm: RoomManager = main2d.room_manager
	rm.zones[a.current_zone_id]["room_type"] = RoomData.RoomType.REST  # pretend the start room is a Rest room
	resources.reset_resources(0, 2, 0, 0)
	a.stats.take_damage(10)
	var hp := a.stats.current_hp
	var healed := fm.rest_tick()
	_expect(healed > 0 and a.stats.current_hp == hp + 2, "rest tick heals 2 (%d -> %d)" % [hp, a.stats.current_hp])
	_expect(resources.get_resource("food") < 2, "rest tick costs Comida (%d)" % resources.get_resource("food"))
	resources.reset_resources(0, 0, 0, 0)
	hp = a.stats.current_hp
	fm.rest_tick()
	_expect(a.stats.current_hp == hp, "no Comida, no healing")

	# Game time: frozen in the tactical pause.
	resources.add_resource("food", 10)
	Engine.time_scale = 0.0
	await process_frame
	fm._rest_clock = 0.0
	for i in 20:
		await process_frame
	_expect(a.stats.current_hp == hp and fm._rest_clock == 0.0, "rest is frozen at time_scale 0")
	Engine.time_scale = 1.0
	rm.zones[a.current_zone_id]["room_type"] = RoomData.RoomType.START
	a.stats.heal(a.stats.max_hp)


func _check_floor_end_loss(main2d: Node) -> void:
	var b: Player = main2d.heroes[1]
	b.stats.take_damage(b.stats.max_hp)
	main2d.floor_manager.complete_floor()
	_expect(session.lost_ids.has(b.stats.hero_id), "downed at floor end -> lost")
	var next: Array[String] = session.resolve_party(session.get_party_ids())
	_expect(not next.has(b.stats.hero_id) and next.size() == 1, "the lost hero isn't spawned next floor: %s" % [next])
	_expect(session.get_recruit_candidates(next).find(b.stats.hero_id) == -1, "a lost hero never comes back as a prisoner")


func _check_all_down(main2d: Node) -> void:
	var a: Player = main2d.heroes[0]
	a.stats.take_damage(a.stats.max_hp)
	_expect(main2d.game_state_manager.current_state == GameStateManager.State.DEAD, "every hero down -> defeat")


func _check_nexo_defeat(main2d: Node) -> void:
	var nexo: Nexo = main2d.nexo
	nexo.take_damage(nexo.max_hp * 2)
	_expect(main2d.game_state_manager.current_state == GameStateManager.State.DEAD, "Nexo destroyed -> defeat with heroes alive")


func _other_zone(main2d: Node, zone_id: String) -> String:
	for id: String in main2d.room_manager.get_zone_ids():
		if id != zone_id:
			return id
	return zone_id


func _boot() -> Array:
	var main2d := (load(MAIN2D_PATH) as PackedScene).instantiate()
	main2d.force_fallback_layout = true
	root.add_child(main2d)
	await process_frame
	var hud := (load(HUD_PATH) as PackedScene).instantiate() as HUDController
	root.add_child(hud)
	await process_frame
	var camera: GameCamera = main2d.camera
	camera.config = camera.config.duplicate()
	camera.config.edge_scroll_enabled = false
	return [main2d, hud]


func _free_world(world: Array) -> void:
	paused = false
	Engine.time_scale = 1.0
	for node: Node in world:
		node.queue_free()
	await process_frame
	await process_frame
