extends Resource
class_name DungeonRoomTemplateCatalog

const DungeonGraph = preload("res://scripts/world/dungeon/DungeonGraph.gd")
const DungeonRoomTemplateProfile = preload("res://scripts/world/dungeon/DungeonRoomTemplateProfile.gd")

@export var profiles: Array[DungeonRoomTemplateProfile] = []


func get_profile_by_template_id(template_id: String) -> DungeonRoomTemplateProfile:
	for profile in profiles:
		if profile and profile.template_id == template_id:
			return profile
	return null


func get_profile_by_size_category(size_category: String, room_role: String = "") -> DungeonRoomTemplateProfile:
	for profile in profiles:
		if profile == null:
			continue
		if profile.size_category != size_category:
			continue
		if room_role != "" and profile.room_role != room_role:
			continue
		return profile

	for profile in profiles:
		if profile and profile.size_category == size_category:
			return profile

	return null


func get_profile_for_room(room_id: int, room_count: int, enable_tutorial: bool, enable_boss: bool, preferred_size_category: String = "") -> DungeonRoomTemplateProfile:
	if room_id == 0 and enable_tutorial:
		return _resolve_special_profile(DungeonGraph.TEMPLATE_TUTORIAL, DungeonGraph.ROOM_ROLE_TUTORIAL, DungeonGraph.SIZE_CATEGORY_MEDIUM)

	if enable_boss and room_count > 1 and room_id == room_count - 1:
		return _resolve_special_profile(DungeonGraph.TEMPLATE_BOSS, DungeonGraph.ROOM_ROLE_BOSS, DungeonGraph.SIZE_CATEGORY_LARGE)

	if preferred_size_category != "":
		var preferred := get_profile_by_size_category(preferred_size_category, DungeonGraph.ROOM_ROLE_NORMAL)
		if preferred != null:
			return preferred

	return get_profile_by_size_category(DungeonGraph.SIZE_CATEGORY_MEDIUM, DungeonGraph.ROOM_ROLE_NORMAL)


func _resolve_special_profile(template_id: String, room_role: String, fallback_size_category: String) -> DungeonRoomTemplateProfile:
	var by_template := get_profile_by_template_id(template_id)
	if by_template != null:
		return by_template

	var by_role := get_profile_by_size_category(fallback_size_category, room_role)
	if by_role != null:
		return by_role

	return get_profile_by_size_category(fallback_size_category)