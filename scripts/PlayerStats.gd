extends Node

## PlayerStats — Autoload singleton
##
## Holds a live reference to the player's CharacterStats child node
## and broadcasts changes to all listeners (HUD, UpgradeMenu, etc.).
##
## Usage:
##   PlayerStats.register(player_stats_node)   ← call from PlayerMovement._ready()
##   PlayerStats.apply_upgrade(upgrade_dict)   ← call from UpgradeMenu
##   PlayerStats.stats_changed.connect(...)    ← subscribe from HUDController

signal stats_changed(stats: CharacterStats)

## The live CharacterStats node that belongs to the player.
var stats: CharacterStats = null

# ─────────────────────────────────────────────────────────────────────────────
func _ready() -> void:
	print("PlayerStats singleton initialised.")

# ─────────────────────────────────────────────────────────────────────────────
## Register the player's CharacterStats node.
## Called once from PlayerMovement (or Main2d) after the player is spawned.
func register(player_stats: CharacterStats) -> void:
	if player_stats == null:
		push_error("PlayerStats.register(): received null CharacterStats")
		return
	stats = player_stats
	print("PlayerStats: registered stats for '%s'" % stats.character_name)
	stats_changed.emit(stats)

# ─────────────────────────────────────────────────────────────────────────────
## Apply an upgrade dictionary produced by UpgradeMenu.
## upgrade = { card_name, stat_affected, value_change, rarity, … }
func apply_upgrade(upgrade: Dictionary) -> void:
	if stats == null:
		push_error("PlayerStats.apply_upgrade(): no stats registered")
		return

	var stat: String  = upgrade.get("stat_affected", "")
	var delta: int    = upgrade.get("value_change", 0)
	var name_str: String = upgrade.get("card_name", "???")

	match stat:
		"strength":
			stats.strength_modifier += delta
		"magic":
			stats.magic_modifier += delta
		"dexterity":
			stats.dexterity_modifier += delta
		"hp":
			stats.max_hp   = maxi(1, stats.max_hp   + delta)
			stats.current_hp = mini(stats.current_hp + delta, stats.max_hp)
		_:
			push_warning("PlayerStats.apply_upgrade(): unknown stat '%s'" % stat)

	print("PlayerStats: applied '%s' → %s %+d" % [name_str, stat, delta])
	stats_changed.emit(stats)
