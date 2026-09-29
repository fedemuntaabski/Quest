extends Resource
class_name RoomTypeVisualConfig

## RoomTypeVisualConfig: one RoomTypeVisual per RoomData.RoomType that has a
## display. Shared instance: resources/maps/room_type_visual_config.tres, held by
## MapVisualConfig.room_type_visuals.

@export var entries: Array[RoomTypeVisual] = []


## Null for a type without an entry (Combat is plain on purpose).
func get_visual(type: RoomData.RoomType) -> RoomTypeVisual:
	for entry in entries:
		if entry and entry.type == type:
			return entry
	return null
