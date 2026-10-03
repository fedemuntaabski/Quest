extends RefCounted
class_name ResearchState

## Research done this run: ids only. Owned by ResourceManager (same lifetime as
## the resources: survives floors, wiped by Main._begin_new_run).

var researched: Dictionary = {}


func has(id: String) -> bool:
	return researched.has(id)


func add(id: String) -> void:
	researched[id] = true


func reset() -> void:
	researched.clear()
