# Technical Debt And Risks

## Severity-Ranked Risks

### CRITICAL
1. **Multiple room ownership sources**
   - `DungeonGenerator.active_room_id`
   - `RoomSystem.active_room_id`
   - enemy `my_room_id`
   - repair logic in `MapManagerCore`

   Failure mode: room membership can disagree across systems, which can block combat, suppress rewards, or make the UI report the wrong room.

2. **Async combat resolution touches shared runtime state**
   - `CardAction` awaits `CombatCardSystem.execute_card()`
   - `EffectApplier` awaits movement effects
   - `TurnManager` waits on the queue to settle

   Failure mode: a stale or invalid target can be discovered late, after the queue has already accepted the action.

3. **State gating depends on both tree pause and game-state checks**
   - `GameStateManager` pauses the tree
   - input and turn code also check `can_process_input()` / `can_process_turns()`

   Failure mode: a state transition mismatch can leave a subsystem active while another is paused.

### HIGH
1. **Runtime node lookups are fragile**
   - direct `get_node_or_null()` calls for `CombatComponent`, `StatusComponent`, `HUDController`, `CardManager`, and `PlayerStats`
   - group lookups for `hud`, `player`, and `game_state_manager`

   Failure mode: renamed scene nodes or late initialization produce null dependencies that are silently repaired or partially masked.

2. **Null dependency resolution is too forgiving**
   - `CombatComponent.setup()` can create a fallback `CharacterStats`
   - `MapManagerCore.get_actor_room_id()` can invent room membership from the active room
   - `EffectApplier` and `StatusRuntime` have fallback logic for legacy state

   Failure mode: bad wiring can survive long enough to create incorrect gameplay rather than failing fast.

3. **Implicit initialization order assumptions**
   - `MapManager` expects `DungeonGenerator` to be ready before enemy setup
   - `PlayerActionController` expects `CardSystemController` to exist as a child
   - `CardSystemController.bind_hud()` depends on deferred HUD readiness

   Failure mode: startup timing changes can create one-frame null access or missing signal connections.

4. **Turn loop and queue coupling is manual**
   - `TurnManager` advances based on queue state and `consume_turn`
   - actors also call queue methods directly from their own turn logic

   Failure mode: a queued action can unintentionally advance or stall the actor loop if a subclass violates the contract.

### MEDIUM
1. **Duplicate or overlapping responsibility in room managers**
   - `RoomSystem` and `DungeonRoomManager` both mutate room state and emit room changes

2. **Legacy behavior remains visible in fallback paths**
   - legacy metadata-based status handling still exists alongside `StatusComponent`
   - `MapManagerCore` and `EnemyManager` still contain repair/compatibility behavior

3. **No explicit queue cancellation semantics**
   - `ActionQueue.clear()` drops work without telling the rest of the runtime why

4. **Ad hoc logging instead of structured diagnostics**
   - several systems print warnings but do not emit machine-readable failure data

## Refactor Roadmap

### Phase 1: Make State Ownership Explicit
Goal: one writer per piece of runtime state.

Actions:
- Choose one room-state writer.
- Choose one authoritative source for actor room membership.
- Choose one canonical target-validation path for combat.

### Phase 2: Stabilize Deterministic Combat
Goal: actions should execute from a snapshot, not from shifting live lookups.

Actions:
- Pass queued actions a stable target snapshot.
- Standardize action result codes.
- Add explicit cancellation and failure reasons to the queue.
- Reduce direct scene lookup during execution.


### Phase 3: Improve Observability
Goal: make failures easy to diagnose without reproducing them in a debugger.

Actions:
- Introduce structured logs for room mismatch, target mismatch, and queue rejection.
- Add action IDs and room snapshot IDs to combat logs.
- Emit explicit events for queue cancellation and room-sync correction.

### Phase 3: Collapse Legacy Compatibility Paths
Goal: remove silent fallback behavior once the modern path is proven.

Actions:
- Retire metadata-based status fallback after coverage is verified.
- Remove duplicated card and room repair logic once the main path is stable.
- Delete dead or historical AI references if they are not used by the runtime.

## Runtime Correctness Checklist
- Room IDs should not be guessed when the real state exists.
- A queued action should not depend on a later scene lookup to remain valid.
- Input should be rejected for one reason at a time, with a clear log.
- Enemy and player turn code should both rely on the same engagement rule.
- Any compatibility fallback should be temporary and labeled.

## Needs Verification In Code
- Whether there are additional room writers outside the files inspected here.
- Whether any action subclass still mutates state after `finish()`.
- Whether any scene still references removed legacy AI files.
