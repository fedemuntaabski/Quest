extends Resource
class_name MapVisualConfig

## MapVisualConfig: tunables for map presentation — per-room lighting and the
## exit hint. One shared instance (resources/maps/map_visual_config.tres),
## read by RoomManager/RoomLight/ExitIndicator. Changing exit_hint_mode (in
## the Inspector or at runtime) emits `changed`; ExitIndicator listens.

enum ExitHintMode {
	ALWAYS,        ## Marker + arrow from the start, even under fog.
	ON_DISCOVERY,  ## Once the exit room is revealed (or the crystal is carried).
	ON_CRYSTAL,    ## Only while the hero carries the crystal (Nexo).
}

@export_group("Exit hint")
@export var exit_hint_mode: ExitHintMode = ExitHintMode.ON_DISCOVERY:
	set(v):
		if exit_hint_mode != v:
			exit_hint_mode = v
			emit_changed()
@export var exit_color: Color = Color(0.35, 1.0, 0.6, 0.9)
## Marker/arrow color while carrying the crystal (plus a stronger pulse).
@export var exit_crystal_color: Color = Color(1.0, 0.85, 0.2, 1.0)
## Screen-edge inset (px) for the off-screen arrow.
@export var arrow_margin: float = 56.0

@export_group("Dark canvas")
## Session 7: a CanvasModulate (RoomManager) dims the whole world canvas; each
## lit room's RoomLight PointLight2D brings it back up. Not black: revealed dark
## rooms must stay readable (discovered info is never hidden).
@export var dark_canvas_enabled: bool = true
@export var dark_canvas_color: Color = Color(0.5, 0.5, 0.6, 1.0)

@export_group("Lighting")
## Unpowered (dark) revealed room: overlay pulses between these two colors.
@export var dark_overlay_color: Color = Color(0.03, 0.0, 0.05, 0.6)
@export var danger_overlay_color: Color = Color(0.35, 0.02, 0.04, 0.5)
@export var danger_pulse_time: float = 1.4
## Outline on dark rooms the player can afford to energize right now.
@export var affordable_outline_color: Color = Color(1.0, 0.8, 0.3, 0.9)
@export var warm_light_color: Color = Color(1.0, 0.72, 0.38, 1.0)
@export var warm_light_energy: float = 0.9
## Seconds for the dark -> lit tween.
@export var power_transition_time: float = 0.6

@export_group("Tile decor")
## MapTileRenderer: banners replace this share of north-wall face tiles of rooms.
@export_range(0.0, 1.0) var wall_decor_density: float = 0.12
## Chance per tile on a room's outermost floor ring to hold a Kenney prop.
@export_range(0.0, 1.0) var prop_density: float = 0.06
## Chance a room floor tile uses a variant (cracks/stains) instead of plain.
@export_range(0.0, 1.0) var floor_variant_chance: float = 0.25

@export_group("Room types")
## Name / icon / color / banner / decor per RoomType (badge, minimap, discovery
## banner, tile props). Lit or dark doesn't matter.
@export var room_type_visuals: RoomTypeVisualConfig


## Null when the type has no entry (or no config is assigned).
func room_type_visual(type: RoomData.RoomType) -> RoomTypeVisual:
	return room_type_visuals.get_visual(type) if room_type_visuals else null


## The type's badge/minimap marker color; transparent when it has no marker
## (Combat, Start, Exit keep their own hints).
func room_type_color(type: RoomData.RoomType) -> Color:
	var visual := room_type_visual(type)
	return visual.color if visual and visual.show_marker else Color.TRANSPARENT
