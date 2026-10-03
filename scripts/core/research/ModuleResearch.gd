extends ResearchEntry
class_name ModuleResearch

## Research that unlocks one module for the whole run (a ResearchEntry with
## UNLOCK_MODULE, so ResearchConfig / ResourceManager / ResearchPanel treat it
## like any other entry). Cost is Ciencia; `prerequisite` is another entry id.

## Tech tier 1-3 (shown in the panel).
@export_range(1, 3) var tier: int = 1


func _init() -> void:
	effect = Effect.UNLOCK_MODULE
