extends SceneTree

## ItemData/ItemCatalog (resources/items): ids únicos, íconos dentro de su hoja y
## no vacíos, modificadores solo con stats existentes, sorteo determinista,
## Pickup con ítem y mochila de la sección "Equipo" del CharacterPopup.

var _failures := 0


func _initialize() -> void:
	var catalog := ItemCatalog.get_default()
	_expect(catalog != null and catalog.items.size() >= 12, "catálogo cargado con >= 12 ítems")
	var ids := {}
	var slots := {}
	for item in catalog.items:
		_expect(not ids.has(item.id) and item.id != "", "id único: %s" % item.id)
		ids[item.id] = true
		slots[item.slot] = true
		_expect(item.display_name != "", "%s con nombre" % item.id)
		_check_icon(item)
		_expect(item.description != "", "%s con descripción" % item.id)
		for key: String in item.modifiers:
			_expect(key in ItemData.MODIFIER_KEYS, "%s: stat válida '%s'" % [item.id, key])
		if item.is_consumable():
			_expect(item.modifiers.is_empty() and item.consumable_effect != ItemData.ConsumableEffect.NONE and item.effect_value > 0.0, "%s: consumible con efecto" % item.id)
			_expect(item.describe_effect() != "" and item.stackable and item.max_stack > 1, "%s: describe su efecto y apila" % item.id)
		else:
			_expect(not item.modifiers.is_empty() and item.describe_modifiers() != "", "%s con modificadores" % item.id)
			_expect(item.consumable_effect == ItemData.ConsumableEffect.NONE, "%s: un equipo no tiene efecto de consumible" % item.id)
		_expect(item.describe_stats() != "", "%s describe lo que hace" % item.id)
	_expect(slots.size() == ItemData.Slot.size(), "hay ítems de cada ranura")

	var a := RandomNumberGenerator.new()
	var b := RandomNumberGenerator.new()
	a.seed = 7
	b.seed = 7
	_expect(catalog.pick(a).id == catalog.pick(b).id, "pick determinista con la misma semilla")

	var pickup := (load("res://scenes/world/Pickup.tscn") as PackedScene).instantiate() as Pickup
	pickup.item = catalog.items[0]
	root.add_child(pickup)
	await process_frame
	_expect(pickup.sprite.texture == catalog.items[0].icon, "Pickup muestra el ícono del ítem")
	pickup.kind = Pickup.Kind.CHEST
	_expect(pickup.sprite.get_child_count() == 1, "cofre con ítem: ícono flotante encima")
	pickup.queue_free()

	await _check_popup(catalog)
	print("test_items: %d fallos" % _failures)
	quit(1 if _failures else 0)


func _check_icon(item: ItemData) -> void:
	var atlas := item.icon as AtlasTexture
	_expect(atlas != null, "%s: ícono AtlasTexture" % item.id)
	if atlas == null:
		return
	var img := atlas.atlas.get_image()
	_expect(Rect2i(Vector2i.ZERO, img.get_size()).encloses(Rect2i(atlas.region)) and atlas.region.size == Vector2(16, 16), "%s: región 16x16 dentro de la hoja" % item.id)
	var used := false
	for y in 16:
		for x in 16:
			used = used or img.get_pixel(int(atlas.region.position.x) + x, int(atlas.region.position.y) + y).a > 0.0
	_expect(used, "%s: ícono no vacío" % item.id)


func _check_popup(catalog: ItemCatalog) -> void:
	var ps: Node = root.get_node("PlayerStats")
	ps.clear_found_items()
	var popup := CharacterPopup.new()
	root.add_child(popup)
	await process_frame
	var stats := CharacterStats.new()
	stats.hero_id = "warrior"
	root.add_child(stats)
	popup.open_for(stats, null)
	_expect(popup._equipment._stash_grid.get_child_count() == 0, "popup sin hallazgos al inicio")
	ps.add_found_item(catalog.items[3])
	_expect(popup._equipment._stash_grid.get_child_count() == 1, "la mochila del popup lista el ítem hallado")
	ps.clear_found_items()
	_expect(popup._equipment._stash_grid.get_child_count() == 0, "clear_found_items vacía la mochila")
	popup.queue_free()
	stats.queue_free()


func _expect(ok: bool, what: String) -> void:
	if not ok:
		_failures += 1
		printerr("FAIL: " + what)
