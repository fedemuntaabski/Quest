extends Resource
class_name EnemyPool

## EnemyPool: weighted list of EnemyTypes for one floor. `weights[i]` belongs
## to `types[i]` (missing entries count as 1).

@export var types: Array[EnemyType] = []
@export var weights: PackedFloat32Array = PackedFloat32Array()


func weight_of(index: int) -> float:
	return maxf(weights[index], 0.0) if index < weights.size() else 1.0


## Weighted pick, optionally only types with `role` (EnemyType.Role, -1 = any);
## null only when nothing matches or every weight is 0.
func roll(rng: RandomNumberGenerator = null, role: int = -1) -> EnemyType:
	var total := 0.0
	var last: EnemyType = null
	for i in types.size():
		if role < 0 or types[i].role == role:
			total += weight_of(i)
			last = types[i]
	if total <= 0.0:
		return null
	var pick := (rng.randf() if rng else randf()) * total
	for i in types.size():
		if role >= 0 and types[i].role != role:
			continue
		pick -= weight_of(i)
		if pick < 0.0:
			return types[i]
	return last
