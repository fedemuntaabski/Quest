extends Resource
class_name EnemyPool

## EnemyPool: weighted list of EnemyTypes for one floor. `weights[i]` belongs
## to `types[i]` (missing entries count as 1).

@export var types: Array[EnemyType] = []
@export var weights: PackedFloat32Array = PackedFloat32Array()


func weight_of(index: int) -> float:
	return maxf(weights[index], 0.0) if index < weights.size() else 1.0


## Weighted pick; null only when the pool is empty or every weight is 0.
func roll(rng: RandomNumberGenerator = null) -> EnemyType:
	var total := 0.0
	for i in types.size():
		total += weight_of(i)
	if total <= 0.0:
		return null
	var pick := (rng.randf() if rng else randf()) * total
	for i in types.size():
		pick -= weight_of(i)
		if pick < 0.0:
			return types[i]
	return types[types.size() - 1]
