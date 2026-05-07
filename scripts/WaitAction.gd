extends BaseAction
class_name WaitAction

func execute() -> void:
	if duration <= 0.0:
		finish()
		return

	if owner == null:
		finish()
		return

	var tree := owner.get_tree()
	if tree == null:
		finish()
		return

	await tree.create_timer(duration).timeout
	finish()
