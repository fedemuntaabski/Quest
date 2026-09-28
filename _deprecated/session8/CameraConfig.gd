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

@export_group("Zoom")
@export var zoom_min: float = 0.5
@export var zoom_max: float = 2.0
## Multiplier per wheel notch.
@export var zoom_step: float = 1.15
## Exponential approach rate (higher = snappier).
@export var zoom_smoothing: float = 10.0

@export_group("Bounds")
## World px added around the discovered rooms' rectangle.
@export var bounds_margin: float = 160.0
