extends Resource
class_name ResearchConfig

## ResearchConfig: the run's research tree (Ciencia sink, session 10).
## Everything tunable lives in resources/research/research_config.tres.

@export var entries: Array[ResearchEntry] = []


func get_entry(id: String) -> ResearchEntry:
	for entry in entries:
		if entry.id == id:
			return entry
	return null


## The entry that unlocks `module`, or null if the module is never locked.
func get_unlock_entry(module: Module.ModuleType) -> ResearchEntry:
	for entry in entries:
		if entry.effect == ResearchEntry.Effect.UNLOCK_MODULE and entry.module == module:
			return entry
	return null
