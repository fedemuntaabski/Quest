class_name NetSync
extends Node

## NetSync (coop-12): built by Main2d while online. Host: sends snapshots of
## heroes/enemies at NetConfig.snapshot_hz (unreliable), the RunState (reliable)
## every full_state_sec and right after discrete changes, a desync hash every
## hash_sec, and one-off events (vfx, hints, invasions, bestiary, floor end).
## Client: interpolates positions between the last two snapshots, mirrors HP,
## creates/frees enemy puppets by `slot` and applies the RunState. It runs no
## game logic of its own.

signal desync_detected(host_hash: int, local_hash: int)
## Client: a full state was applied (tests, reconnection).
signal state_applied

var main2d: Node
var config: NetConfig
var desyncs := 0
var hash_checks := 0
var snapshots_received := 0

var _snap_clock := 0.0
var _state_clock := 0.0
var _hash_clock := 0.0
var _dirty := false
var _tick := 0
## Client interpolation: node -> {from: Vector2, to: Vector2}; all share _snap_t0.
var _interp: Dictionary = {}
var _snap_t0 := 0.0


func setup(p_main2d: Node) -> void:
	main2d = p_main2d
	var net := Net.session()
	config = net.config if net else NetConfig.new()
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("net_sync")
	if Net.is_authority():
		_hook_host_signals()
		if net:
			net.floor_ready.connect(func(peer: int) -> void: send_full_state(true, peer))
	elif net:
		net.report_floor_ready(main2d.floor_manager.floor_index)


## Host: clients that have this floor loaded (RPCs to a missing node would fail).
func _ready_peers() -> Array[int]:
	var out: Array[int] = []
	var net := Net.session()
	if net:
		for peer in net.ready_floor:
			if net.ready_floor[peer] == main2d.floor_manager.floor_index and peer in multiplayer.get_peers():
				out.append(peer)
	return out


## Any node (VfxManager, HUD): relay a one-off event to the clients if we are the online host.
static func broadcast(kind: String, data: Dictionary) -> void:
	if not (Net.is_authority() and Net.is_online()):
		return
	var tree := Engine.get_main_loop() as SceneTree
	var sync := tree.get_first_node_in_group("net_sync") as NetSync if tree else null
	if sync:
		sync.send_event(kind, data)


func _hook_host_signals() -> void:
	var mark := func(_a = null, _b = null, _c = null) -> void: _dirty = true
	main2d.door_turn_system.room_revealed.connect(mark)
	main2d.room_manager.room_power_changed.connect(mark)
	main2d.room_manager.module_built.connect(mark)
	ManagerLocator.get_resource_manager().resource_changed.connect(mark)
	ManagerLocator.get_resource_manager().research_changed.connect(mark)
	ManagerLocator.get_party_inventory().stash_changed.connect(mark)
	ManagerLocator.get_party_inventory().equipment_changed.connect(mark)
	ManagerLocator.get_player_stats().run_upgrades_changed.connect(mark)
	ManagerLocator.get_player_stats().perk_chosen.connect(mark)
	main2d.extraction_manager.phase_changed.connect(mark)
	main2d.extraction_manager.stage_changed.connect(mark)
	main2d.extraction_manager.victory_declared.connect(func() -> void: send_event("victory", {}))
	main2d.enemy_manager.enemies_appeared.connect(func(zones: Array, count: int, source: String) -> void:
		send_event("enemies_appeared", {"zones": zones, "count": count, "source": source}))
	main2d.enemy_manager.enemy_spawned.connect(func(enemy: Enemy) -> void:
		enemy.died.connect(func(e: Enemy) -> void:
			if e.type:
				send_event("kill", {"type": e.type.id})))


func _process(delta: float) -> void:
	if not Net.is_online():
		return
	if Net.is_authority():
		_host_tick(delta)
	else:
		_client_interpolate()


# ─── host ─────────────────────────────────────────────────────

func _host_tick(delta: float) -> void:
	_snap_clock += delta
	_state_clock += delta
	_hash_clock += delta
	if _snap_clock >= 1.0 / maxf(config.snapshot_hz, 1.0):
		_snap_clock = 0.0
		_tick += 1
		var snap := capture_snapshot()
		for peer in _ready_peers():
			_rpc_snapshot.rpc_id(peer, snap)
	if _dirty or _state_clock >= config.full_state_sec:
		var with_hash := _hash_clock >= config.hash_sec
		send_full_state(with_hash)
		if with_hash:
			_hash_clock = 0.0


func send_full_state(with_hash: bool = false, peer: int = 0) -> void:
	_dirty = false
	_state_clock = 0.0
	var d := RunState.capture(main2d)
	var h := RunState.state_hash(d) if with_hash else 0
	for p in ([peer] if peer > 0 else _ready_peers()):
		_rpc_state.rpc_id(p, d, h)


func capture_snapshot() -> Dictionary:
	var heroes := []
	for hero in ManagerLocator.get_heroes():
		heroes.append([hero.stats.hero_id, hero.global_position, hero.current_zone_id,
			hero.stats.current_hp, hero.stats.max_hp, hero.abilities.cooldown_left if hero.abilities else 0.0])
	var enemies := []
	for enemy in main2d.enemy_manager.get_enemies():
		if enemy.is_alive():
			enemies.append([enemy.slot, enemy.type.id if enemy.type else "", enemy.global_position,
				enemy.current_hp, enemy.max_hp, enemy.current_zone_id])
	return {"tick": _tick, "time": Enemy.game_time_msec, "scale": Engine.time_scale,
		"heroes": heroes, "enemies": enemies}


@rpc("any_peer", "reliable")
func _request_full_state() -> void:
	if Net.is_authority():
		send_full_state(true, multiplayer.get_remote_sender_id())


## One-off event to every client (host only; offline it does nothing).
func send_event(kind: String, data: Dictionary) -> void:
	if Net.is_authority() and Net.is_online():
		for peer in _ready_peers():
			_rpc_event.rpc_id(peer, kind, data)


# ─── client ───────────────────────────────────────────────────

@rpc("authority", "unreliable_ordered")
func _rpc_snapshot(s: Dictionary) -> void:
	apply_snapshot(s)


func apply_snapshot(s: Dictionary) -> void:
	snapshots_received += 1
	Enemy.game_time_msec = float(s.get("time", Enemy.game_time_msec))
	Engine.time_scale = float(s.get("scale", 1.0))
	_snap_t0 = Time.get_ticks_msec() / 1000.0
	var heroes := {}
	for hero in ManagerLocator.get_heroes():
		heroes[hero.stats.hero_id] = hero
	for h in s.get("heroes", []):
		var hero: Player = heroes.get(h[0])
		if hero == null:
			continue
		_set_target(hero, h[1])
		if hero.current_zone_id != h[2]:
			hero.current_zone_id = h[2]
			hero.zone_changed.emit(h[2])
		mirror_hp(hero.stats, int(h[3]), int(h[4]))
		if hero.abilities:
			hero.abilities.cooldown_left = float(h[5])
	var em: EnemyManager = main2d.enemy_manager
	var by_slot := {}
	for enemy in em.get_enemies():
		by_slot[enemy.slot] = enemy
	var seen := {}
	for e in s.get("enemies", []):
		seen[e[0]] = true
		var enemy: Enemy = by_slot.get(e[0])
		if enemy == null:
			enemy = em.spawn_puppet(e[0], e[1], e[5], e[2], int(e[4]))
			_register_seen(enemy)
		_set_target(enemy, e[2])
		enemy.current_zone_id = e[5]
		if int(e[3]) < enemy.current_hp:
			enemy.visual.play_hit()
		enemy.current_hp = int(e[3])
		enemy.queue_redraw()
	for slot in by_slot:
		if not seen.has(slot):
			_free_puppet(by_slot[slot])


## HP from the host, through the stat's own signals (portraits, downed look).
static func mirror_hp(stats: CharacterStats, hp: int, max_hp: int) -> void:
	if stats.current_hp == hp and stats.max_hp == max_hp:
		return
	var was_alive := stats.is_alive()
	stats.max_hp = max_hp
	stats.current_hp = hp
	stats.hp_changed.emit(hp, max_hp)
	if was_alive and hp <= 0:
		stats.died.emit()


func _set_target(node: Node2D, pos: Vector2) -> void:
	var entry: Dictionary = _interp.get(node, {})
	if entry.is_empty():
		node.global_position = pos
	_interp[node] = {"from": node.global_position, "to": pos}


func _client_interpolate() -> void:
	var hz := maxf(config.snapshot_hz, 1.0)
	var alpha := clampf((Time.get_ticks_msec() / 1000.0 - _snap_t0) * hz, 0.0, 1.0)
	for node in _interp.keys():
		if not is_instance_valid(node):
			_interp.erase(node)
			continue
		var e: Dictionary = _interp[node]
		node.global_position = (e.from as Vector2).lerp(e.to, alpha)


func _free_puppet(enemy: Enemy) -> void:
	_interp.erase(enemy)
	var vfx := ManagerLocator.get_vfx_manager()
	if vfx:
		vfx.play(&"death_dust", enemy.global_position, vfx.config.dust_color)
	enemy.queue_free()


func _register_seen(enemy: Enemy) -> void:
	var bestiary := ManagerLocator.get_bestiary()
	if bestiary and enemy.type:
		bestiary.register_seen(enemy.type, main2d.floor_manager.floor_index)


@rpc("authority", "reliable")
func _rpc_state(d: Dictionary, host_hash: int) -> void:
	RunState.apply(main2d, d)
	state_applied.emit()
	if host_hash != 0:
		hash_checks += 1
		var local_hash := RunState.state_hash(RunState.capture(main2d))
		if local_hash != host_hash:
			desyncs += 1
			QuestLogger.warn(QuestLogger.Category.NETWORK, "Desync: host hash %d != local %d, resync requested" % [host_hash, local_hash])
			desync_detected.emit(host_hash, local_hash)
			_request_full_state.rpc_id(1)
		else:
			QuestLogger.debug(QuestLogger.Category.NETWORK, "State hash OK (%d)" % host_hash)


@rpc("authority", "reliable")
func _rpc_event(kind: String, data: Dictionary) -> void:
	apply_event(kind, data)


func apply_event(kind: String, data: Dictionary) -> void:
	match kind:
		"fx":
			var vfx := ManagerLocator.get_vfx_manager()
			if vfx:
				vfx.play(StringName(data.id), data.pos, data.color, data.angle, data.to)
		"hint":
			var hud := ManagerLocator.get_hud()
			if hud:
				hud.show_hint(data.title, data.text, data.color)
		"enemies_appeared":
			var zones: Array[String] = []
			zones.assign(data.zones)
			main2d.enemy_manager.enemies_appeared.emit(zones, data.count, data.source)
		"kill":
			var bestiary := ManagerLocator.get_bestiary()
			var type := bestiary.get_type(data.type) if bestiary else null
			if type:
				bestiary.register_kill(type, main2d.floor_manager.floor_index)
			var gs := ManagerLocator.get_game_session()
			if gs:
				gs.add_stat("kills")
		"victory":
			main2d.floor_manager.complete_floor()
			var gsm := ManagerLocator.get_game_state_manager()
			if gsm:
				gsm.request_victory()
		"defeat":
			main2d._on_player_died(true)
