extends BaseAction
class_name AttackAction

var combat_component: CombatComponent
var validation_reason: String = ""
var validation_snapshot: Dictionary = {}

func _init(p_combat_component: CombatComponent, p_target: Node, p_snapshot: Dictionary = {}):
	combat_component = p_combat_component
	var actor_owner_local := combat_component.actor_owner if combat_component else null
	super._init(actor_owner_local, p_target)
	validation_snapshot = p_snapshot.duplicate(true) if p_snapshot else {}
	consume_turn = true

func can_execute() -> bool:
	if combat_component == null:
		validation_reason = "no_combat_component"
		return false
	if validation_snapshot.size() > 0 and combat_component.map_manager and combat_component.map_manager.occupancy_manager:
		var current_ver := combat_component.map_manager.occupancy_manager.get_version()
		var snap_ver := int(validation_snapshot.get("occ_version", -1))
		if snap_ver != -1 and snap_ver != current_ver:
			validation_reason = "stale_snapshot"
			return false
	validation_reason = ""
	return bool(CombatValidation.validate_target(combat_component, target, combat_component.map_manager, combat_component.attack_range, true).get("valid", false))

func execute() -> void:
	if combat_component:
		var owner_actor = combat_component.actor_owner
		
		# 1. 🌟 COMPORTAMIENTO SI EL ATACANTE ES EL JUGADOR
		if owner_actor is PlayerMovement and owner_actor.sprite:
			# 🎯 MODIFICA ESTE NÚMERO para calibrar el desfase exclusivo de la animación de ataque:
			var AJUSTE_OFFSET_ATAQUE: int = 8 
			
			# Validamos la dirección X respecto al objetivo para girar el sprite correctamente
			if "grid_pos" in target:
				var dir_x = target.grid_pos.x - owner_actor.grid_pos.x
				if dir_x != 0:
					if dir_x < 0:
						owner_actor.sprite.scale.x = -abs(owner_actor.sprite.scale.x)
						owner_actor.sprite.offset.x = AJUSTE_OFFSET_ATAQUE
					else:
						owner_actor.sprite.scale.x = abs(owner_actor.sprite.scale.x)
						owner_actor.sprite.offset.x = 0
			
			# Llamamos a la función del Player para congelar el Idle/Run y atacar
			owner_actor.play_attack_animation()
			
		# 2. 🌟 COMPORTAMIENTO SI EL ATACANTE ES UN ENEMIGO
		elif owner_actor is Enemy and owner_actor.has_method("play_attack_animation"):
			# Orientamos dinámicamente al enemigo hacia el jugador antes de golpear
			if "grid_pos" in target and "grid_pos" in owner_actor:
				var dir_x = target.grid_pos.x - owner_actor.grid_pos.x
				if owner_actor.sprite and dir_x != 0:
					if dir_x < 0:
						owner_actor.sprite.scale.x = -abs(owner_actor.sprite.scale.x)
						if owner_actor.enemy_data:
							owner_actor.sprite.offset.x = owner_actor.enemy_data.extra_stats.get("offset_izq_idle", 4)
					else:
						owner_actor.sprite.scale.x = abs(owner_actor.sprite.scale.x)
						owner_actor.sprite.offset.x = 0
						
			owner_actor.play_attack_animation()

		# Ejecución nativa del ataque y daño
		var result = combat_component.attack(target)
		
		# 3. 🛡️ PROTECCIÓN DE RENDER: Evita que el cambio de turno pise la animación instantáneamente
		if owner_actor and owner_actor.is_inside_tree():
			await owner_actor.get_tree().create_timer(0.15).timeout

	finish()

func get_execution_state_token() -> Dictionary:
	var token: Dictionary = {}
	if combat_component and combat_component.actor_owner and "grid_pos" in combat_component.actor_owner:
		token["owner_cell"] = combat_component.actor_owner.grid_pos
	if target and "grid_pos" in target:
		token["target_cell"] = target.grid_pos
	if validation_snapshot.size() > 0:
		token["snapshot"] = validation_snapshot.duplicate(true)
	return token

func get_failure_reason() -> String:
	return validation_reason
