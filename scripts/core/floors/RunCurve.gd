extends Resource
class_name RunCurve

## RunCurve (progresion-10): the single Resource that defines the run's floors
## and their difficulty curve (resources/floors/run_curve.tres). Index = floor - 1;
## floors past the end reuse the last one.

@export var floors: Array[FloorTheme] = []


func theme(floor_index: int) -> FloorTheme:
	if floors.is_empty():
		return null
	return floors[clampi(floor_index - 1, 0, floors.size() - 1)]
