extends Node
class_name InventoryComponent

## InventoryComponent: one hero's consumables at runtime (child of Player, like
## HeroAbilities). What is equipped lives in PartyInventory; this applies the
## effect of the consumable the player uses (heal, timed buffs), enforces the
## per-item cooldown on game time and refuses while the tactical pause is on.
## Buffs go through CharacterStats' named multiplier sources, so reverting a
## potion never undoes a hero ability and vice versa.

signal consumable_cooldown_changed(item_id: String, left: float)
signal consumable_used(item: ItemData)

const BUFF_SOURCE := &"potion"

var hero: Player
## item id -> seconds left (game time).
var _cooldowns: Dictionary = {}


func setup(p_hero: Player) -> void:
	hero = p_hero


func _process(delta: float) -> void:
	for item_id: String in _cooldowns.keys():
		var left := maxf(float(_cooldowns[item_id]) - delta, 0.0)
		if left <= 0.0:
			_cooldowns.erase(item_id)
		else:
			_cooldowns[item_id] = left
		consumable_cooldown_changed.emit(item_id, left)


func cooldown_left(item: ItemData) -> float:
	return float(_cooldowns.get(item.id, 0.0))


## "" if the consumable at `index` can be used now, else why not.
func get_block_reason(index: int) -> String:
	var inventory := ManagerLocator.get_party_inventory()
	if inventory == null or hero == null:
		return "Sin inventario"
	var list := inventory.get_equipped(hero.stats.hero_id, ItemData.Slot.CONSUMABLE)
	if index < 0 or index >= list.size():
		return "No hay consumible"
	var item := list[index]
	if not hero.stats.is_alive():
		return "El héroe ha caído"
	if Engine.time_scale <= 0.0:
		return "No se puede usar en pausa táctica"
	var state := ManagerLocator.get_game_state_manager()
	if state != null and not state.is_active():
		return "No disponible ahora"
	if cooldown_left(item) > 0.0:
		return "En enfriamiento (%d s)" % ceili(cooldown_left(item))
	if item.consumable_effect == ItemData.ConsumableEffect.HEAL_HP and hero.stats.current_hp >= hero.stats.max_hp:
		return "Vida completa"
	return ""


## Uses the consumable at `index`. False (nothing spent) when blocked.
func use(index: int) -> bool:
	var reason := get_block_reason(index)
	if reason != "":
		_say(reason, QuestPalette.UI_TEXT_BLOCKED)
		return false
	var inventory := ManagerLocator.get_party_inventory()
	var item := inventory.consume(hero.stats.hero_id, index)
	if item == null:
		return false
	_apply(item)
	if item.use_cooldown > 0.0:
		_cooldowns[item.id] = item.use_cooldown
		consumable_cooldown_changed.emit(item.id, item.use_cooldown)
	_say(item.display_name, item.color())
	var vfx := ManagerLocator.get_vfx_manager()
	if vfx:
		vfx.play(&"heal_glow" if item.consumable_effect == ItemData.ConsumableEffect.HEAL_HP else &"buff_aura", hero.global_position, hero.vfx_color())
	consumable_used.emit(item)
	QuestLogger.info(QuestLogger.Category.COMBAT, "%s used '%s'." % [hero.stats.hero_id, item.id])
	return true


func _apply(item: ItemData) -> void:
	match item.consumable_effect:
		ItemData.ConsumableEffect.HEAL_HP:
			hero.stats.heal(roundi(item.effect_value))
		ItemData.ConsumableEffect.ATTACK_BUFF_TIMED:
			_buff(item, "potion_damage", func() -> void: hero.stats.set_attack_mult_source(BUFF_SOURCE, 1.0 + item.effect_value), func() -> void: hero.stats.set_attack_mult_source(BUFF_SOURCE, 1.0))
		ItemData.ConsumableEffect.SPEED_BUFF_TIMED:
			_buff(item, "potion_speed", func() -> void: hero.stats.set_interval_mult_source(BUFF_SOURCE, 1.0 - item.effect_value), func() -> void: hero.stats.set_interval_mult_source(BUFF_SOURCE, 1.0))


## Timed effect; a newer use of the same kind supersedes the revert of the older one.
func _buff(item: ItemData, key: String, apply: Callable, revert: Callable) -> void:
	apply.call()
	var token := Time.get_ticks_usec()
	hero.stats.set_meta(key, token)
	await get_tree().create_timer(item.effect_duration).timeout
	if is_instance_valid(hero) and hero.stats.get_meta(key, 0) == token:
		revert.call()


func _say(text: String, color: Color) -> void:
	var text_mgr := ManagerLocator.get_floating_text_manager() as FloatingTextManager
	if text_mgr and hero:
		text_mgr.spawn_text(hero.global_position + Vector2(0.0, -48.0), text, color)
