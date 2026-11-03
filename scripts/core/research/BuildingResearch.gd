extends ResearchEntry
class_name BuildingResearch

## Research that unlocks one building for the whole run (a ResearchEntry with
## UNLOCK_BUILDING, so ResearchConfig / ResourceManager / ResearchPanel treat it
## like any other entry). Cost is Saber; `prerequisite` is another entry id.

## Tech tier 1-3 (shown in the panel).
@export_range(1, 3) var tier: int = 1


func _init() -> void:
	effect = Effect.UNLOCK_BUILDING
