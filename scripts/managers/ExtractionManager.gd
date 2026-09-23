extends Node
class_name ExtractionManager

## ExtractionManager: orthogonal run-flow flag, separate from
## GameStateManager.State (which gates ACTIVE/PAUSED/DEAD process-freezing).
## Extraction doesn't freeze anything — input/turns keep working, it just
## blocks new door-opens and starts a spawn-timer wave in dark rooms.
## Scene-instantiated per Main2d, group "extraction_manager".

enum Phase { EXPLORATION, EXTRACTION }

signal phase_changed(new_phase: Phase, old_phase: Phase)
signal victory_declared

const SPAWN_INTERVAL := 5.0

var current_phase: Phase = Phase.EXPLORATION

var room_manager: RoomManager
var enemy_manager: EnemyManager
var _spawn_timer: Timer


func _ready() -> void:
	add_to_group("extraction_manager")


func setup(p_room_manager: RoomManager, p_enemy_manager: EnemyManager) -> void:
	room_manager = p_room_manager
	enemy_manager = p_enemy_manager

	_spawn_timer = Timer.new()
	_spawn_timer.name = "SpawnTimer"
	_spawn_timer.wait_time = SPAWN_INTERVAL
	_spawn_timer.one_shot = false
	add_child(_spawn_timer)
	_spawn_timer.timeout.connect(_on_spawn_timeout)


func start_extraction() -> void:
	if current_phase == Phase.EXTRACTION:
		return
	var old_phase := current_phase
	current_phase = Phase.EXTRACTION
	_spawn_timer.start()
	phase_changed.emit(current_phase, old_phase)
	QuestLogger.info(QuestLogger.Category.NEXO, "Extraction phase started.")


func can_open_doors() -> bool:
	return current_phase != Phase.EXTRACTION


func declare_victory() -> void:
	_spawn_timer.stop()
	victory_declared.emit()
	var gsm := ManagerLocator.get_game_state_manager()
	if gsm:
		gsm.request_victory()
	QuestLogger.info(QuestLogger.Category.NEXO, "Victory: nexo reached the exit room.")


func _on_spawn_timeout() -> void:
	if room_manager == null or enemy_manager == null:
		return
	for group_id in room_manager.get_unpowered_revealed_room_group_ids():
		enemy_manager.spawn_enemies_in_room(group_id, 1)
