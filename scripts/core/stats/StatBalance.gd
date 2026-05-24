extends RefCounted
class_name StatBalance

# Centralized balance math for player-facing stats.
# Keep gameplay formulas here so combat, upgrades, and UI stay aligned.

const PLAYER_BASE_HP: int = 20
const PLAYER_MAX_HP: int = 40
const MAX_UPGRADE_LEVEL: int = 10
const BASE_UPGRADE_COST: int = 50
const UPGRADE_COST_STEP: int = 25

const DEX_DODGE_MIN: float = 0.025
const DEX_DODGE_MAX: float = 0.18
const DEX_DODGE_CURVE: float = 8.0

const DEX_DAMAGE_LINEAR_PORTION: float = 0.6
const DEX_DAMAGE_ROOT_PORTION: float = 0.4

static func clamp_player_hp(max_hp: int, current_hp: int) -> Dictionary:
	var clamped_max := clampi(max_hp, PLAYER_BASE_HP, PLAYER_MAX_HP)
	var clamped_current := clampi(current_hp, 0, clamped_max)
	return {
		"max_hp": clamped_max,
		"current_hp": clamped_current,
	}

static func apply_hp_delta(max_hp: int, current_hp: int, value: int) -> Dictionary:
	var next_max := clampi(max_hp + value, 1, PLAYER_MAX_HP)
	var next_current := clampi(current_hp + value, 0, next_max)
	return {
		"max_hp": next_max,
		"current_hp": next_current,
	}

static func get_upgrade_cost(level: int) -> int:
	return BASE_UPGRADE_COST + (max(level, 0) * UPGRADE_COST_STEP)

static func get_dexterity_dodge_chance(dex: int) -> float:
	# Soft-cap dexterity so it stays useful without becoming an all-purpose defense stat.
	if dex <= 0:
		return DEX_DODGE_MIN
	var scaled := float(dex) / (float(dex) + DEX_DODGE_CURVE)
	return clampf(DEX_DODGE_MIN + (scaled * (DEX_DODGE_MAX - DEX_DODGE_MIN)), DEX_DODGE_MIN, DEX_DODGE_MAX)

static func get_scaled_stat_bonus(stat_key: String, stat_value: int, damage_scaling: float) -> int:
	var normalized_key := stat_key.to_lower()
	var effective_value := float(stat_value)
	if normalized_key == "dexterity":
		# Dex keeps a smaller linear piece plus a diminishing-returns tail.
		effective_value = (float(stat_value) * DEX_DAMAGE_LINEAR_PORTION) + (sqrt(maxf(float(stat_value), 0.0)) * DEX_DAMAGE_ROOT_PORTION)
	return int(round(effective_value * damage_scaling))