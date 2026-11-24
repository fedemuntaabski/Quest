class_name QuestLogger
extends RefCounted

## Centralized logging utility for QUEST.
## Provides categorized, level-filtered logging to replace raw print() calls.

enum Category {
	GENERAL,
	COMBAT,
	MAP,
	STATE,
	ACTIONS,
	SAVE,
	UI,
	CAMERA,
	NETWORK,
	DOOR,
	ROOM,
	BUILDING,
	RELIC,
	ENEMY
}

enum Level {
	DEBUG = 0,
	INFO = 1,
	WARN = 2,
	ERROR = 3
}

const MIN_LEVEL := Level.INFO  # DEBUG is for hot paths: never printed


static func is_enabled(cat: Category, level: int) -> bool:
	return level >= MIN_LEVEL and cat != Category.ACTIONS  # ACTIONS = heartbeats, silenced


static func log_msg(cat: Category, level: int, msg: String) -> void:
	if not is_enabled(cat, level):
		return
	# calidad-13: timestamp so user://logs/quest*.log (Godot file logging, rotated) is readable in reports
	var formatted := "%s [QUEST][%s][%s] %s" % [Time.get_time_string_from_system(), Category.keys()[cat], Level.keys()[level], msg]
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
