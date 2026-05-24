extends Node

signal gold_changed(amount: int)

var _save_dirty: bool = false
var _save_timer: Timer = null

# CurrencyManager: thin facade around `SaveManager.gold`.
# Responsibilities:
# - Provide debounced persistence when gold changes and emit `gold_changed`.
# - Spawn floating text feedback via `FloatingTextManager` when appropriate.

func _ready() -> void:
	add_to_group("currency_manager")

	# Debounced save timer to avoid synchronous disk writes on every gold change
	if not has_node("SaveTimer"):
		var t := Timer.new()
		t.name = "SaveTimer"
		t.wait_time = 1.0
		t.one_shot = true
		add_child(t)
		t.timeout.connect(Callable(self, "_on_save_timer_timeout"))

	_save_timer = get_node("SaveTimer") as Timer

func get_gold() -> int:
	var save_mgr := ManagerLocator.get_save_manager()
	return save_mgr.gold if save_mgr else 0

func add_gold(amount: int, world_pos: Vector2 = Vector2.ZERO) -> void:
	var save_mgr := ManagerLocator.get_save_manager()
	if save_mgr == null:
		return
	_commit_gold(save_mgr, save_mgr.gold + max(amount, 0))
	if world_pos != Vector2.ZERO:
		_spawn_gold_text(amount, world_pos)

func spend_gold(amount: int) -> bool:
	var save_mgr := ManagerLocator.get_save_manager()
	if save_mgr == null:
		return false
	if save_mgr.gold < amount:
		return false
	_commit_gold(save_mgr, save_mgr.gold - amount)
	return true

func set_gold(amount: int) -> void:
	var save_mgr := ManagerLocator.get_save_manager()
	if save_mgr == null:
		return
	_commit_gold(save_mgr, amount)

func reset() -> void:
	set_gold(0)

func _commit_gold(save_mgr: Node, amount: int) -> void:
	# Update runtime value and notify listeners immediately.
	save_mgr.gold = max(0, amount)
	gold_changed.emit(save_mgr.gold)

	# Mark dirty and schedule a debounced save to persist to disk.
	_save_dirty = true
	if _save_timer:
		_save_timer.start()

func _spawn_gold_text(amount: int, world_pos: Vector2) -> void:
	if amount <= 0:
		return
	var text_mgr := ManagerLocator.get_floating_text_manager() as FloatingTextManager
	if text_mgr:
		text_mgr.spawn_text(world_pos, "+%d g" % amount, QuestPalette.CURRENCY_GOLD_POPUP)

func _on_save_timer_timeout() -> void:
	if not _save_dirty:
		return
	var save_mgr := ManagerLocator.get_save_manager()
	if save_mgr:
		save_mgr.save_game()
		_save_dirty = false

func flush_save() -> void:
	# Immediately persist pending gold changes.
	if not _save_dirty:
		return
	if _save_timer:
		_save_timer.stop()
	var save_mgr := ManagerLocator.get_save_manager()
	if save_mgr:
		save_mgr.save_game()
	_save_dirty = false
