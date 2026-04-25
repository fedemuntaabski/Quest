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

var base_hp: int = 10
var base_str: int = 0
var base_mag: int = 0
var base_dex: int = 0

var active_upgrades: Array = []

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
	
	# Apply loaded base stats
	stats.max_hp = base_hp
	stats.current_hp = base_hp
	stats.strength_modifier = base_str
	stats.magic_modifier = base_mag
	stats.dexterity_modifier = base_dex
	
	# Apply all active upgrades
	for upg in active_upgrades:
		_apply_stat_change(upg.get("stat_affected", ""), upg.get("value_change", 0))
	
	print("PlayerStats: registered stats for '%s' (Loaded %d upgrades)" % [stats.character_name, active_upgrades.size()])
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

	_apply_stat_change(stat, delta)
	active_upgrades.append(upgrade)

	print("PlayerStats: applied '%s' → %s %+d" % [name_str, stat, delta])
	stats_changed.emit(stats)

func _apply_stat_change(stat: String, delta: int) -> void:
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
			push_warning("PlayerStats._apply_stat_change(): unknown stat '%s'" % stat)
	stats_changed.emit(stats)
