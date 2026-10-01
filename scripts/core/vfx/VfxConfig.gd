extends Resource
class_name VfxConfig

## VfxConfig: tunables of the VfxManager (resources/vfx/vfx_config.tres).
## `effects` maps an effect id to {scene, sheet, tint, duration, scale}:
##  - scene: one of the 7 scenes in assets/vfx (slash_arc, projectile_trail, impact_sparks,
##    heal_glow, buff_aura, death_dust, damage_flash);
##  - sheet: sprite sheet name in assets/art/vfx/index.json ("" = particles only);
##  - tint: multiply the sheet by the palette color (only for white sheets);
##  - duration: seconds the whole effect lives (the sheet is sped up/slowed to fit);
##  - scale: extra multiplier on top of ArtConfig.ART_SCALE.

## Simultaneous effects; a new one is dropped while this many are playing.
@export var max_active: int = 40
@export_group("Screen shake")
## A hit counts as "strong" at this fraction of the target's max HP (or more).
@export var shake_threshold_pct: float = 0.3
## ...and at least this much damage, so chip damage on tiny enemies never shakes.
@export var shake_min_damage: int = 5
## World px at SettingsManager.screen_shake_intensity = 1; kept tiny on purpose.
@export var shake_strength: float = 3.0
@export var shake_duration: float = 0.15
@export_group("Palette")
@export var enemy_hit_color: Color = Color(0.85, 0.2, 0.2, 1)
@export var damage_color: Color = Color(1, 0.3, 0.25, 1)
@export var dust_color: Color = Color(0.55, 0.45, 0.35, 1)
@export var build_color: Color = Color(0.95, 0.78, 0.35, 1)
@export_group("")
@export var effects: Dictionary = {}


func get_effect(id: StringName) -> Dictionary:
	return effects.get(id, {})
