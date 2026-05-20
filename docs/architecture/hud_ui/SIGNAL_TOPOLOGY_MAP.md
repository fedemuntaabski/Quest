# Signal Topology Map — HUD/Reward/Card Systems

## Current State (As-Is Analysis)

### Signal Chain 1: Reward Selection (Normal Flow)

```
CardRewardUI.card_selected(card)
    ↓ [RELAY]
HUDController.reward_card_selected(card)
    ↓ [RELAY]
Main2d._on_reward_card_selected(card)
    ↓ [MUTATION]
CardRewardManager.complete_reward(card)
GameStateManager.close_reward(card)
```

**Hops**: 3 (CardRewardUI → HUDController → Main2d)
**Ownership Chain**:
- CardRewardUI: Presents UI, captures user input → **Owns presentation only**
- HUDController: Re-emits signal → **No logic, pure relay**
- Main2d: Calls reward completion handlers → **Owns orchestration** (where decision is made to mutate deck)

**Assessment**: The HUDController relay is **unnecessary for correctness** but provides scene decoupling.

---

### Signal Chain 2: Reward Replacement Flow

```
CardRewardUI.card_replace_selected(card, slot_index)
    ↓ [RELAY]
HUDController.reward_card_replace_selected(card, slot_index)
    ↓ [RELAY]
Main2d._on_reward_card_replace_selected(card, slot_index)
    ↓ [MUTATION]
CardRewardManager.complete_reward_with_replacement(card, slot_index)
GameStateManager.close_reward(card)
```

**Hops**: 3 (CardRewardUI → HUDController → Main2d)
**Ownership Chain**: Same as Chain 1
**Assessment**: Same—relay is decoupling, not necessary for logic.

---

### Signal Chain 3: Reward Skip

```
CardRewardUI.reward_skipped
    ↓ [RELAY]
HUDController.reward_skipped
    ↓ [RELAY]
Main2d._on_reward_skipped()
    ↓ [MUTATION]
GameStateManager.close_reward(null)
```

**Hops**: 3 (CardRewardUI → HUDController → Main2d)
**Ownership Chain**: Same
**Assessment**: Identical relay pattern.

---

### Signal Chain 4: Hotbar Slot Click

```
HotbarSlot.slot_pressed(index)
    ↓ [RELAY]
HUDController.hotbar_slot_pressed(index)
    ↓ [???]
(Currently: HUDController stores but does not emit further)
```

**Hops**: 2 (HotbarSlot → HUDController)
**Ownership Chain**:
- HotbarSlot: Detects click → **Owns input**
- HUDController: Receives, stores reference → **Unclear ownership**

**Assessment**: **Dead relay**—signal is captured but not forwarded. Hotbar slot click handling is unclear.

---

### Signal Chain 5: Tooltip Routing

```
HotbarSlot.mouse_entered
    ↓
HUDController.show_card_tooltip(payload)  [Direct method call, debounced]
    ↓
CardTooltip.update_display(payload)  [Visual update only]
```

**Hops**: 2 (HotbarSlot → HUDController → CardTooltip)
**Ownership Chain**:
- HotbarSlot: Detects hover → **Owns input**
- HUDController: Debounces, formats, routes → **Owns tooltip orchestration** (potentially should be higher-level)
- CardTooltip: Renders → **Owns presentation only**

**Assessment**: **Debounce logic is fragile**—tied to HUDController. Should be owned by tooltip component or separate timer service.

---

## Problem Analysis

### Problem A: Relay Pattern (Chains 1-3)
- **What**: CardRewardUI → HUDController → Main2d is a pure signal relay with no value-add
- **Why it exists**: Scene decoupling (CardRewardUI doesn't directly reference Main2d)
- **Risk**: Extra hop makes signal path harder to trace; maintenance burden if HUDController logic grows
- **Impact**: Low—relays are idempotent (no logic), just forwarding

### Problem B: Dead Relay (Chain 4)
- **What**: `hotbar_slot_pressed` is captured but not forwarded or acted upon
- **Why it exists**: Unclear—possibly legacy or incomplete implementation
- **Risk**: **High**—dead code path suggests unclear ownership for hotbar interactions
- **Impact**: Medium—unclear how hotbar clicks are supposed to drive gameplay

### Problem C: Fragmented Tooltip Routing (Chain 5)
- **What**: Tooltip display orchestration is spread across HUDController, HotbarSlot, and CardTooltip
- **Why it exists**: Debounce logic tied to HUDController
- **Risk**: **High**—if more tooltip types are added, logic will fragment further
- **Impact**: Medium—makes tooltip behavior hard to modify consistently

---

## Ownership Boundaries (Current)

| System | Owner | Responsibility |
|--------|-------|-----------------|
| Presentation state (visibility, animation) | CardRewardUI, HotbarSlot, CardTooltip | Render and visual feedback |
| Workflow state (multi-step selection) | **RewardFlowState (Phase 1 refactor)** | Validate transitions |
| Orchestration (when/how to apply reward) | Main2d | Coordinate mutation |
| Mutation authority (deck updates) | CardRewardManager | Actual deck change |
| State machine authority | GameStateManager | Global game state |

---

## Recommendations (Phase 2)

### Keep (No Change Required)

1. **Relay Chains 1-3** (Reward Selection)
   - **Rationale**: Decoupling benefit outweighs small indirection cost
   - **Future-proofing**: If HUDController grows, can refactor to direct connection
   - **Status**: ✅ Acceptable as-is

2. **Tooltip Routing** (Chain 5) — Partially
   - **Keep**: Debounce logic at HUDController level (centralized timer)
   - **Keep**: Routing through HUDController (scene flexibility)
   - **Status**: ✅ Acceptable after documentation

### Investigate

1. **Hotbar Slot Click Handler** (Chain 4)
   - **Action**: Trace where `hotbar_slot_pressed` signal is expected to be consumed
   - **Possible outcomes**:
     - Remove if truly dead code
     - Document ownership if it serves a purpose
     - Connect to explicit gameplay handler if missing

---

## Signal Ownership Model (Explicit)

### Rule 1: Presentation Layer Decoupling
- UI nodes (CardRewardUI, HotbarSlot) **MAY** emit raw input signals
- Middle layer (HUDController) **MAY** relay these for scene decoupling
- Relays **MUST** be intentional and documented

### Rule 2: Mutation Authority
- Only ONE node **MUST** decide when to mutate (usually Main2d or Manager)
- Related signals **MUST** flow to that authority
- Authority **MUST** delegate mutation to the owner (e.g., CardRewardManager)

### Rule 3: Bidirectional Consistency
- If A → B → C, then C's response **SHOULD** flow back C → B → A if feedback is needed
- Avoid asymmetric signal paths (A emits to B, but C responds directly to A)

### Rule 4: Documentation
- Every relay **MUST** be documented with:
  - **Why**: Purpose of the relay (decoupling, filtering, debouncing, etc.)
  - **Ownership**: Who decides, who executes
  - **Future**: How to refactor if relay is no longer needed

---

## Next Steps

1. **Clarify hotbar slot ownership**: Where should a click on a card slot drive the action?
   - Play the card?
   - Show tooltip?
   - Both?

2. **Document tooltip ownership**: Is debounce logic in HUDController or should CardTooltip own it?

3. **Create explicit signal topology diagram** with ownership markers for traceability

4. **Consider Phase 3**: Introduce a `SignalRouter` or explicit signal bus if relay complexity grows further

