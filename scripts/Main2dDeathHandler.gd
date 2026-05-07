extends RefCounted
class_name Main2dDeathHandler

var owner: Node = null
var death_overlay: CanvasLayer = null
var death_gold_label: Label = null

func setup(p_owner: Node, p_death_overlay: CanvasLayer, p_death_gold_label: Label) -> void:
	owner = p_owner
	death_overlay = p_death_overlay
	death_gold_label = p_death_gold_label

func handle_player_died(enemies_killed: int, rooms_cleared: int) -> void:
	if owner == null:
		return

	var gold_reward := enemies_killed * 10 + rooms_cleared * 50

	if death_gold_label:
		death_gold_label.text = "Oro ganado: %d" % gold_reward

	var save_mgr = owner.get_node_or_null("/root/SaveManager")
	if save_mgr:
		save_mgr.gold += gold_reward
		save_mgr.save_game()

	if death_overlay:
		death_overlay.visible = true
		death_overlay.modulate.a = 0.0

		var t := owner.create_tween()
		t.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		t.tween_property(death_overlay, "modulate:a", 1.0, 2.0)
