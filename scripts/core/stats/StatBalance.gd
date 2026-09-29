extends RefCounted
class_name StatBalance

# Centralized balance math for player-facing stats.
# Keep gameplay formulas here so combat, upgrades, and UI stay aligned.

const PLAYER_BASE_HP: int = 20
# 60 (was 40): leaves room for in-run hero levels on top of the base HP.
const PLAYER_MAX_HP: int = 60

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
