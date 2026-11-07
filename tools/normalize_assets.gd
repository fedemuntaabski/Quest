extends SceneTree

## Genera los íconos placeholder 16x16 de assets/art/ui (docs/MISSING_ICONS.md).
## Reproducible, idempotente:
##   godot --headless --path . --script res://tools/normalize_assets.gd
## Hasta licencias-20 también copiaba las hojas de ítems (licencia desconocida) y
## los FX de unTied Games; eso se quitó: el arte de reemplazo sale de
## tools/build_own_art.gd (ver docs/CREDITOS.md).

const ART := "res://assets/art/"
const CELL := 16

## Íconos que ningún pack cubre (docs/MISSING_ICONS.md). Se generan 16x16 en
## assets/art/ui/placeholder_<nombre>.png con color por categoría y una X para
## que se note a simple vista. Reemplazar por arte real conservando el tamaño.
const PLACEHOLDERS := {
	"building": ["gen_iron", "gen_food", "gen_lore", "defense", "trap"],
	"relic": ["relic"],
	"resource": ["res_iron", "res_food", "res_lore", "res_embers", "res_lock"],
	"room": ["room_start", "room_exit"],
	"status": ["status_slow"],
	"research": ["research_lore_workshop", "research_defense_plans", "research_workshop_tuning", "research_dry_tinder", "research_cartography", "research_workshop_bellows", "research_defense_rifling"],
	"ability": ["ability_warrior_passive", "ability_warrior_active", "ability_mage_passive", "ability_mage_active", "ability_rogue_passive", "ability_rogue_active", "ability_tank_passive", "ability_tank_active"],
}
const PLACEHOLDER_COLORS := {
	"building": Color(0.55, 1.0, 0.1), "relic": Color(0.1, 0.9, 1.0), "resource": Color(0.2, 0.6, 1.0),
	"room": Color(1.0, 0.55, 0.1), "status": Color(1.0, 0.15, 0.15), "research": Color(1.0, 0.1, 0.8),
	"ability": Color(1.0, 0.95, 0.1),
}


func _init() -> void:
	_placeholders()
	quit()


func _placeholders() -> void:
	_ensure_dir(ART + "ui/")
	for category: String in PLACEHOLDERS:
		var color: Color = PLACEHOLDER_COLORS[category]
		for icon_name: String in PLACEHOLDERS[category]:
			var img := Image.create(CELL, CELL, false, Image.FORMAT_RGBA8)
			img.fill(color.darkened(0.45))
			for i in CELL:
				for edge: Vector2i in [Vector2i(i, 0), Vector2i(i, CELL - 1), Vector2i(0, i), Vector2i(CELL - 1, i), Vector2i(i, i), Vector2i(CELL - 1 - i, i)]:
					img.set_pixelv(edge, color)
			img.save_png(ProjectSettings.globalize_path(ART + "ui/placeholder_%s.png" % icon_name))


func _ensure_dir(path: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path))
