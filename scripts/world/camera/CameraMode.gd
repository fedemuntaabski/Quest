extends Node
class_name CameraMode

## Base class for camera behavior modes (ROOM, CORRIDOR, etc.)
## Encapsulates mode-specific logic: follow speed, bounds calculation, margin application
## Subclasses override update_camera() to implement mode-specific behavior

## Called when mode is activated
func enter() -> void:
	pass

## Called when mode is deactivated
func exit() -> void:
	pass

## Called every frame to update camera position, zoom, and limits
## Returns: true if camera was modified, false if no change
func update_camera(
	player: CharacterBody2D,
	camera: Camera2D,
	dungeon: DungeonGenerator,
	delta: float
) -> bool:
	return false  # Override in subclass
