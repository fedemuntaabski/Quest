extends Node

signal gold_changed(new_amount: int)

var _gold: int = 0

func _ready() -> void:
	add_to_group("currency_manager")

func get_gold() -> int:
	return _gold

func add_gold(amount: int, position: Vector2 = Vector2.ZERO) -> void:
	if amount <= 0:
		return
	
	_gold += amount
	gold_changed.emit(_gold)
	
	# Optional: You can add visual effects here (floating text, particle effects, etc.)
	# For now, just print for debugging
	if position != Vector2.ZERO:
		print("Added %d gold at position %s" % [amount, position])
	else:
		print("Added %d gold" % amount)

func set_gold(amount: int) -> void:
	_gold = max(0, amount)
	gold_changed.emit(_gold)

func reset() -> void:
	_gold = 0
	gold_changed.emit(_gold)
