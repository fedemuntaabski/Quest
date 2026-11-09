class_name Accessibility
extends RefCounted

## Accessibility (calidad-13): the live accessibility flags, as statics so any
## script (and `--script` tests, where autoload names are not identifiers) reads
## them without a lookup. SettingsManager owns, persists and sets them.

## Multiplies every UI font size (UiStyles.font()). 0.8 .. 1.5.
static var text_scale: float = 1.0
## Health bars/rarities use the colorblind palette and add shapes.
static var colorblind: bool = false
## No full-screen flashes, blinking borders/bars/rings or white hit flashes.
static var reduce_flashes: bool = false
## Important sounds also show a caption line in the HUD.
static var sound_captions: bool = false


## visual-24: no UI text below this base size (13 px and less got ~7 px at 1280x720).
const MIN_TEXT_PX := 14


## Font size `px` (at least MIN_TEXT_PX) scaled by text_scale.
static func font(px: int) -> int:
	return glyph(maxi(px, MIN_TEXT_PX))


## Font size `px` scaled by text_scale, without the minimum: corner glyphs on icons
## (hotkey letter, rarity shape) and world-space labels.
static func glyph(px: int) -> int:
	return maxi(6, roundi(px * text_scale))
