extends Resource
class_name DungeonRoomTemplateProfile

const DungeonGraph = preload("res://scripts/world/dungeon/DungeonGraph.gd")

@export var template_id: String = DungeonGraph.TEMPLATE_NORMAL
@export var room_role: String = DungeonGraph.ROOM_ROLE_NORMAL
@export var size_category: String = DungeonGraph.SIZE_CATEGORY_MEDIUM
@export var min_size: Vector2i = Vector2i(10, 8)
@export var max_size: Vector2i = Vector2i(20, 14)
@export var tags: PackedStringArray = []