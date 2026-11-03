extends Resource
class_name ResearchConfig

## ResearchConfig: the run's research tree (Saber sink, session 10).
## Everything tunable lives in resources/research/research_config.tres.

@export var entries: Array[ResearchEntry] = []


func get_entry(id: String) -> ResearchEntry:
	for entry in entries:
		if entry.id == id:
			return entry
	return null


## The entry that unlocks `building`, or null if the building is never locked.
func get_unlock_entry(building: Building.BuildingType) -> ResearchEntry:
	for entry in entries:
		if entry.effect == ResearchEntry.Effect.UNLOCK_BUILDING and entry.building == building:
			return entry
	return null
