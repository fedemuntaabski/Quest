extends Node
class_name RewardFlowState

## Manages multi-step reward selection workflow state.
## Separates workflow orchestration from presentation concerns.
##
## State machine:
##   IDLE → SHOWING_REWARDS → (SLOT_PENDING) → COMPLETE
##
## This class owns temporary workflow state but NOT gameplay mutations or visual presentation.
## Presentation layer (CardRewardUI) queries this state to decide what to render.

enum WorkflowState {
	IDLE,              # No reward session active
	SHOWING_REWARDS,   # User is choosing from reward options
	SLOT_PENDING,      # User selected a card; awaiting slot selection (replacement flow only)
	COMPLETE           # User confirmed selection; workflow finished
}

signal reward_flow_completed(selected_card: CardData, slot_index: int)

var current_state: WorkflowState = WorkflowState.IDLE
var _pending_card: CardData = null
var _requires_replace: bool = false
var _replace_slots: Array = []

## Initialize a new reward session.
## Called by CardRewardUI when show_reward() is invoked.
func start_reward_session(cards: Array, requires_replace: bool = false, equipped_slots: Array = []) -> void:
	if cards.is_empty():
		push_warning("[RewardFlowState] Attempted to start with empty cards array")
		return
	
	_reset_state()
	_requires_replace = requires_replace
	_replace_slots = equipped_slots.duplicate()
	current_state = WorkflowState.SHOWING_REWARDS

## User selected a reward card.
func select_card(card: CardData) -> void:
	if current_state != WorkflowState.SHOWING_REWARDS:
		push_warning("[RewardFlowState] select_card() called in invalid state: %s" % WorkflowState.keys()[current_state])
		return
	
	if _requires_replace:
		# Store the card and wait for slot selection
		_pending_card = card
		current_state = WorkflowState.SLOT_PENDING
	else:
		# Direct completion: no replacement needed
		_complete_reward_flow(card, -1)

## User selected a replacement slot (only valid after card selection in replacement flow).
func select_replacement_slot(slot_index: int) -> void:
	if current_state != WorkflowState.SLOT_PENDING:
		push_warning("[RewardFlowState] select_replacement_slot() called in invalid state: %s" % WorkflowState.keys()[current_state])
		return
	
	if _pending_card == null:
		push_error("[RewardFlowState] Pending card is null during slot selection")
		return
	
	_complete_reward_flow(_pending_card, slot_index)

## User skipped the reward (returns to previous state without selection).
func skip_reward() -> void:
	if current_state not in [WorkflowState.SHOWING_REWARDS, WorkflowState.SLOT_PENDING]:
		push_warning("[RewardFlowState] skip_reward() called in invalid state: %s" % WorkflowState.keys()[current_state])
		return
	
	_reset_state()
	current_state = WorkflowState.IDLE

func get_replacement_slots() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for slot in _replace_slots:
		if slot is Dictionary:
			result.append(slot)
	return result

## Internal state management.

func _complete_reward_flow(card: CardData, slot_index: int = -1) -> void:
	current_state = WorkflowState.COMPLETE
	reward_flow_completed.emit(card, slot_index)
	_reset_state()
	current_state = WorkflowState.IDLE

func _reset_state() -> void:
	_pending_card = null
	_requires_replace = false
	_replace_slots.clear()
