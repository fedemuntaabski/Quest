class_name QuestLogger
extends RefCounted

## Centralized logging utility for QUEST.
## Provides categorized, level-filtered logging to replace raw print() calls.

enum Category {
	GENERAL,
	COMBAT,
	CARDS,
	MAP,
	STATE,
	ACTIONS,
	SAVE,
	UI,
	CAMERA
}

enum Level {
	DEBUG = 0,
	INFO = 1,
	WARN = 2,
	ERROR = 3
}

static var enabled_categories: Dictionary = {
	Category.GENERAL: true,
	Category.COMBAT: true,
	Category.CARDS: true,
	Category.MAP: true,
	Category.STATE: true,
	Category.ACTIONS: false, # Heartbeats silenced by default
	Category.SAVE: true,
	Category.UI: true,
	Category.CAMERA: true,
}

static var min_level: int = Level.INFO

static func set_category_enabled(cat: Category, enabled: bool) -> void:
	enabled_categories[cat] = enabled

static func set_min_level(level: int) -> void:
	min_level = level

static func is_enabled(cat: Category, level: int) -> bool:
	if level < min_level:
		return false
	return enabled_categories.get(cat, true)

static func _category_name(cat: Category) -> String:
	match cat:
		Category.GENERAL: return "GENERAL"
		Category.COMBAT: return "COMBAT"
		Category.CARDS: return "CARDS"
		Category.MAP: return "MAP"
		Category.STATE: return "STATE"
		Category.ACTIONS: return "ACTIONS"
		Category.SAVE: return "SAVE"
		Category.UI: return "UI"
		Category.CAMERA: return "CAMERA"
		_: return "UNKNOWN"

static func _level_name(level: int) -> String:
	match level:
		Level.DEBUG: return "DEBUG"
		Level.INFO: return "INFO"
		Level.WARN: return "WARN"
		Level.ERROR: return "ERROR"
		_: return "LOG"

static func log_msg(cat: Category, level: int, msg: String) -> void:
	if not is_enabled(cat, level):
		return
	var formatted := "[QUEST][%s][%s] %s" % [_category_name(cat), _level_name(level), msg]
	match level:
		Level.ERROR:
			push_error(formatted)
		Level.WARN:
			push_warning(formatted)
		_:
			print(formatted)

static func debug(cat: Category, msg: String) -> void:
	log_msg(cat, Level.DEBUG, msg)

static func info(cat: Category, msg: String) -> void:
	log_msg(cat, Level.INFO, msg)

static func warn(cat: Category, msg: String) -> void:
	log_msg(cat, Level.WARN, msg)

static func error(cat: Category, msg: String) -> void:
	log_msg(cat, Level.ERROR, msg)
