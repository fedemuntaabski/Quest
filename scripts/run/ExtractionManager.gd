extends Node
class_name ExtractionManager

## ExtractionManager: orthogonal run-flow flag, separate from
## GameStateManager.State (which gates ACTIVE/PAUSED/DEAD process-freezing).
## Extraction doesn't freeze anything — input/turns keep working, it just
## blocks new door-opens and starts waves in dark rooms. The waves go by stages
## (FloorConfig "Wave scaling"): stage 0 starts at pickup (phase_changed) and the
## stage rises on a timer, so waves get bigger and closer until the exit.
## Scene-instantiated per Main2d, group "extraction_manager".

enum Phase { EXPLORATION, EXTRACTION }

signal phase_changed(new_phase: Phase, old_phase: Phase)
## The waves just got heavier (stage 1..extraction_stage_count - 1).
signal stage_changed(new_stage: int)
signal victory_declared

var current_phase: Phase = Phase.EXPLORATION
## 0 while exploring; 0.. extraction_stage_count - 1 during extraction.
var stage: int = 0

var room_manager: RoomManager
var enemy_manager: EnemyManager
## Null = FloorManager.DEFAULT_CONFIG at floor 1 (standalone scenes, tests).
var floor_manager: FloorManager
var _spawn_timer: Timer
var _stage_timer: Timer


func _ready() -> void:
	add_to_group("extraction_manager")


func setup(p_room_manager: RoomManager, p_enemy_manager: EnemyManager, p_floor_manager: FloorManager = null) -> void:
	room_manager = p_room_manager
	enemy_manager = p_enemy_manager
	floor_manager = p_floor_manager

	_spawn_timer = Timer.new()
	_spawn_timer.name = "SpawnTimer"
	_spawn_timer.wait_time = _config().extraction_stage_interval(_floor_index(), 0)
	_spawn_timer.one_shot = false
	add_child(_spawn_timer)
	_spawn_timer.timeout.connect(_on_spawn_timeout)

	_stage_timer = Timer.new()
	_stage_timer.name = "StageTimer"
	_stage_timer.wait_time = maxf(_config().extraction_stage_sec, 0.1)
	_stage_timer.one_shot = false
	add_child(_stage_timer)
	_stage_timer.timeout.connect(_on_stage_timeout)


func start_extraction() -> void:
	if current_phase == Phase.EXTRACTION:
		return
	var old_phase := current_phase
	current_phase = Phase.EXTRACTION
	stage = 0
	_spawn_timer.wait_time = _config().extraction_stage_interval(_floor_index(), 0)
	_spawn_timer.start()
	_stage_timer.start()
	phase_changed.emit(current_phase, old_phase)
	QuestLogger.info(QuestLogger.Category.NEXO, "Extraction phase started.")


func can_open_doors() -> bool:
	return current_phase != Phase.EXTRACTION


func declare_victory() -> void:
	_spawn_timer.stop()
	_stage_timer.stop()
	victory_declared.emit()
	var gsm := ManagerLocator.get_game_state_manager()
	if gsm:
		gsm.request_victory()
	QuestLogger.info(QuestLogger.Category.NEXO, "Victory: nexo reached the exit room.")


func _on_spawn_timeout() -> void:
	if room_manager == null or enemy_manager == null:
		return
	enemy_manager.spawn_wave(_config().extraction_wave_size(stage))


func _on_stage_timeout() -> void:
	if stage >= _config().extraction_stage_count - 1:
		_stage_timer.stop()
		return
	stage += 1
	_spawn_timer.wait_time = _config().extraction_stage_interval(_floor_index(), stage)
	stage_changed.emit(stage)
	QuestLogger.info(QuestLogger.Category.NEXO, "Extraction stage %d (wave %d, every %.1fs)." % [stage, _config().extraction_wave_size(stage), _spawn_timer.wait_time])


func _config() -> FloorConfig:
	return floor_manager.config if floor_manager else FloorManager.DEFAULT_CONFIG


func _floor_index() -> int:
	return floor_manager.floor_index if floor_manager else 1
