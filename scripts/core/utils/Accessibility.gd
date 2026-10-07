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


## Font size `px` scaled by text_scale.
static func font(px: int) -> int:
	return maxi(6, roundi(px * text_scale))
