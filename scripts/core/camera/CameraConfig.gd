extends Resource
class_name CameraConfig

## CameraConfig: tunables for GameCamera (DotE-style free camera). One shared
## instance (resources/camera/camera_config.tres), exported on Player.tscn's
## Camera2D.

@export_group("Pan")
## World px/s at zoom 1 (divided by zoom, so it feels the same zoomed in/out).
@export var pan_speed: float = 700.0
@export var edge_scroll_enabled: bool = true
## Screen px from the window edge that start edge scrolling.
@export var edge_scroll_margin: float = 16.0
## Middle-button drag pans the camera once the mouse moved this many screen px
## (a shorter press stays a middle click: light/unlight the room).
@export var drag_threshold_px: float = 6.0

@export_group("Zoom")
## Zoom applied on the first frame (clamped to min/max).
@export var default_zoom: float = 1.5
@export var zoom_min: float = 0.5
@export var zoom_max: float = 2.0
## Multiplier per wheel notch.
@export var zoom_step: float = 1.15
## Exponential approach rate (higher = snappier).
@export var zoom_smoothing: float = 10.0

@export_group("Bounds")
## World px added around the discovered rooms' rectangle.
@export var bounds_margin: float = 160.0
