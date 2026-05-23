# Card System Overlap Analysis

This document analyzes the current runtime implementation of card gameplay in the live tree only. It prioritizes observed execution paths over intended architecture and excludes refactor-era files that are no longer part of the active workspace.

Scope covered:
- `scripts/core/cards`
- direct combat, actions, effects, targeting, queueing, cooldown, reward, UI, hover, and room-overlay dependencies
- runtime ownership and snapshot vs live-state boundaries

## Runtime Anchor

The active card runtime is centered on `CardManager`, `CardSystemController`, `CombatCardSystem`, `CardAction`, `CardResolver`, `EffectApplier`, `ActionQueue`, `TurnManager`, `PlayerActionController`, `HUDController`, `HotbarSlot`, `CardRewardUI`, `CardRewardManager`, `MapManager`, and `TileHighlighter`.

Observed flow:

1. `PlayerActionController` reads the active card from `CardManager` and queues play attempts through `CombatCardSystem`.
2. `CombatCardSystem` validates the play, constructs a `CardAction`, and enqueues it on `ActionQueue`.
3. `ActionQueue` executes the action, which calls the snapshot-aware `CombatCardSystem.execute_card_snapshot()` path.
4. `CardResolver` resolves effects into a summary.
5. `EffectApplier` performs live movement and status mutation using `EffectContext` rollback support.
6. `CardSystemController`, `HUDController`, and `HotbarSlot` propagate selection and UI state.
7. `TileHighlighter` separately maintains hover/path/range overlays from `MapManager` hover state and active card state.
8. `CardRewardManager` and `CardRewardUI` drive reward selection and replacement, then `Main2d` bridges reward completion back into the game state.

## Repeated Systems / Functions

### 1) Card execution exists in two near-parallel forms

`CombatCardSystem.execute_card()` and `CombatCardSystem.execute_card_snapshot()` repeat almost the same body: validation, target resolution, `CardResolver.resolve_card()`, HUD roll-label updates, hit/miss application, effect application, cooldown start, signal emission, and active-index reset. The snapshot version adds occupancy-version checks, but the body is otherwise a duplicate execution path.

Risk: high. This is the clearest current overlap in the runtime card path because the same business logic is maintained twice and can diverge.

Files:
- [scripts/core/combat/CombatCardSystem.gd](scripts/core/combat/CombatCardSystem.gd#L119)
- [scripts/core/combat/CombatCardSystem.gd](scripts/core/combat/CombatCardSystem.gd#L162)
- [scripts/core/combat/CardAction.gd](scripts/core/combat/CardAction.gd#L42)

### 2) Basic attacks mirror the card action pipeline

`CombatComponent.get_attack_validation()` / `attack()` and `AttackAction.can_execute()` / `execute()` are the non-card analog of the card pipeline. They use the same general pattern of validate, queue, execute, and snapshot-check occupancy version. The logic is not literally duplicated line-for-line, but it is close enough that combat-rule changes can easily drift between card combat and basic attack combat.

Risk: medium-high. This is a parallel subsystem with the same turn, occupancy, and hit-resolution concerns.

Files:
- [scripts/core/combat/CombatComponent.gd](scripts/core/combat/CombatComponent.gd#L33)
- [scripts/core/combat/CombatComponent.gd](scripts/core/combat/CombatComponent.gd#L77)
- [scripts/core/combat/AttackAction.gd](scripts/core/combat/AttackAction.gd#L15)
- [scripts/core/combat/AttackAction.gd](scripts/core/combat/AttackAction.gd#L28)

### 3) Tooltip and card-display formatting is repeated across UI layers

Card presentation is formatted independently in `CardManager.get_equipped_payload()`, `HotbarSlot._update_ui()`, `CardTooltip.set_card()`, `CardPanelUI._create_card_row()`, and `CardRewardUI._create_card_button()` / `_build_reward_effects_text()`. The payload is shared, but each view reinterprets it with different fallback keys, labels, and availability assumptions.

Risk: medium. This is not a correctness bug by itself, but it is a maintenance hotspot because schema drift will surface as inconsistent UI rather than a clean failure.

Files:
- [scripts/core/cards/CardManager.gd](scripts/core/cards/CardManager.gd#L137)
- [scripts/ui/hud/HotbarSlot.gd](scripts/ui/hud/HotbarSlot.gd#L38)
- [scripts/ui/hud/CardTooltip.gd](scripts/ui/hud/CardTooltip.gd#L8)
- [scripts/ui/hud/CardPanelUI.gd](scripts/ui/hud/CardPanelUI.gd#L1)
- [scripts/ui/card_reward/CardRewardUI.gd](scripts/ui/card_reward/CardRewardUI.gd#L38)

## Duplicate Validation Paths

### 1) Card play validation is checked repeatedly in the same flow

The current play path validates the same attempt in several places:
- `CombatCardSystem.get_card_validation()` checks cooldown, target type, alive state, range, and component presence.
- `CardAction.can_execute()` calls back into `CombatCardSystem.get_card_validation()` again.
- `CombatCardSystem.execute_card()` validates yet again before resolving.
- `CombatCardSystem.execute_card_snapshot()` validates again after snapshot checks.

This is redundant even when it is intentional because the later validation path is not just a safety net; it is effectively a second business rule implementation.

Risk: high. Any future rule change can be applied to one branch and missed in the others.

Files:
- [scripts/core/combat/CombatCardSystem.gd](scripts/core/combat/CombatCardSystem.gd#L19)
- [scripts/core/combat/CombatCardSystem.gd](scripts/core/combat/CombatCardSystem.gd#L82)
- [scripts/core/combat/CombatCardSystem.gd](scripts/core/combat/CombatCardSystem.gd#L119)
- [scripts/core/combat/CombatCardSystem.gd](scripts/core/combat/CombatCardSystem.gd#L162)
- [scripts/core/combat/CardAction.gd](scripts/core/combat/CardAction.gd#L15)

### 2) Card cooldown validation is separate from actual playability

`CardManager.can_play_card()` only checks cooldown, while `CombatCardSystem.get_card_validation()` checks target, room, range, alive state, and combat component state. The UI gets a payload from `CardManager` that can mark a card as usable while combat validation still rejects it for non-cooldown reasons.

Risk: medium. The runtime truth is correct, but the UI and the action system communicate different notions of “can play.”

Files:
- [scripts/core/cards/CardManager.gd](scripts/core/cards/CardManager.gd#L111)
- [scripts/core/cards/CardManager.gd](scripts/core/cards/CardManager.gd#L137)
- [scripts/core/combat/CombatCardSystem.gd](scripts/core/combat/CombatCardSystem.gd#L19)

### 3) Range and target checks are repeated across card and overlay systems

`CardTargeting.is_in_range()` is used in `CombatCardSystem`, while `TileHighlighterCache` uses `CardTargeting.get_range_cells()` to build visual overlays. The visuals and the validator are coordinated, but they are still separate consumers of the same rule. The `CardTargeting.is_valid_target()` helper is currently unused, which suggests the helper layer is only partially adopted.

Risk: medium. This is not harmful today, but it is a sign that validation helpers were split before the call graph finished converging.

Files:
- [scripts/core/combat/CardTargeting.gd](scripts/core/combat/CardTargeting.gd#L16)
- [scripts/core/combat/CardTargeting.gd](scripts/core/combat/CardTargeting.gd#L23)
- [scripts/core/combat/CardTargeting.gd](scripts/core/combat/CardTargeting.gd#L49)
- [scripts/core/combat/CombatCardSystem.gd](scripts/core/combat/CombatCardSystem.gd#L54)
- [scripts/world/rooms/TileHighlighterCache.gd](scripts/world/rooms/TileHighlighterCache.gd#L1)

## Ownership Conflicts

### 1) Active card state is owned by multiple layers

`CardManager` stores `active_index`. `CardSystemController` resets it on state changes and hotbar interactions. `PlayerActionController` also resets it after play and on explicit targeting cleanup. `CombatCardSystem` resets it after execution for player-owned actions. The result is multiple runtime writers for the same selection state.

Risk: high. Selection is a single piece of state that is currently mutated by three control layers, which makes “why did the card deselect?” difficult to reason about.

Files:
- [scripts/core/cards/CardManager.gd](scripts/core/cards/CardManager.gd#L90)
- [scripts/core/cards/CardSystemController.gd](scripts/core/cards/CardSystemController.gd#L145)
- [scripts/core/cards/CardSystemController.gd](scripts/core/cards/CardSystemController.gd#L154)
- [scripts/core/cards/CardSystemController.gd](scripts/core/cards/CardSystemController.gd#L159)
- [scripts/core/movement/PlayerActionController.gd](scripts/core/movement/PlayerActionController.gd#L180)
- [scripts/core/movement/PlayerActionController.gd](scripts/core/movement/PlayerActionController.gd#L214)
- [scripts/core/combat/CombatCardSystem.gd](scripts/core/combat/CombatCardSystem.gd#L158)
- [scripts/core/combat/CombatCardSystem.gd](scripts/core/combat/CombatCardSystem.gd#L222)

### 2) Hover-state ownership is split between map, overlay, and input layers

`MapManager` owns `hovered_cell` and emits `hover_changed`. `TileHighlighter` caches its own `hovered_cell`, listens to the map signal, and independently clears previews and range caches. `PlayerActionController` also updates hover from mouse clicks and hover events for input-driven targeting.

Risk: medium-high. This is a classic split ownership problem: the map, overlay, and input system all touch hover state, but they do so for different reasons and with different invalidation rules.

Files:
- [scripts/world/rooms/MapManager.gd](scripts/world/rooms/MapManager.gd#L9)
- [scripts/world/rooms/MapManager.gd](scripts/world/rooms/MapManager.gd#L20)
- [scripts/world/rooms/MapManager.gd](scripts/world/rooms/MapManager.gd#L83)
- [scripts/world/rooms/TileHighlighter.gd](scripts/world/rooms/TileHighlighter.gd#L41)
- [scripts/world/rooms/TileHighlighter.gd](scripts/world/rooms/TileHighlighter.gd#L177)
- [scripts/world/rooms/TileHighlighter.gd](scripts/world/rooms/TileHighlighter.gd#L221)
- [scripts/core/movement/PlayerActionController.gd](scripts/core/movement/PlayerActionController.gd#L94)
- [scripts/core/movement/PlayerActionController.gd](scripts/core/movement/PlayerActionController.gd#L245)

### 3) Reward completion is bridged through too many layers

`CardRewardUI` emits selection events, `HUDController` re-emits them, `Main2d` receives them, and `CardRewardManager` mutates the deck and re-emits completion. The logic is not incorrect, but the reward flow has multiple ownership handoffs for a simple deck mutation path.

Risk: medium. The chain is working, but the number of event hops increases the chance of stale state or a missed signal connection.

Files:
- [scripts/ui/card_reward/CardRewardUI.gd](scripts/ui/card_reward/CardRewardUI.gd#L38)
- [scripts/ui/hud/HUDController.gd](scripts/ui/hud/HUDController.gd#L154)
- [scripts/managers/Main2d.gd](scripts/managers/Main2d.gd#L429)
- [scripts/core/cards/CardRewardManager.gd](scripts/core/cards/CardRewardManager.gd#L166)

## Snapshot vs Live-State Inconsistencies

### 1) Snapshot data is used as a gate, not as the authoritative execution record

`CardAction` and `AttackAction` both store occupancy-version snapshots, but the actual execution still re-resolves the live target and mutates the live scene. This means the system detects stale state, but it does not fully replay from a frozen snapshot.

Risk: medium. The current implementation is a hybrid determinism model, not a strict snapshot replay model.

Files:
- [scripts/core/combat/CardAction.gd](scripts/core/combat/CardAction.gd#L61)
- [scripts/core/combat/AttackAction.gd](scripts/core/combat/AttackAction.gd#L35)
- [scripts/core/combat/CombatCardSystem.gd](scripts/core/combat/CombatCardSystem.gd#L162)
- [scripts/core/combat/CombatComponent.gd](scripts/core/combat/CombatComponent.gd#L33)

### 2) Effect application is transactional, but the summary it consumes is still live-state derived

`CardResolver` produces a live effect summary from card/effect resources and actor stats, then `EffectApplier` applies movement and status effects into the live world with rollback support. That is a good incremental refactor, but it is still a boundary where summary generation and execution live on different sides of the determinism line.

Risk: medium. The split is healthy, but it is only a partial isolation of deterministic intent from live mutation.

Files:
- [scripts/core/combat/CardResolver.gd](scripts/core/combat/CardResolver.gd#L6)
- [scripts/core/effects/EffectApplier.gd](scripts/core/effects/EffectApplier.gd#L8)
- [scripts/core/effects/EffectContext.gd](scripts/core/effects/EffectContext.gd#L1)

## UI Duplication / Problems

### 1) Hover tooltip flow is duplicated across slot and HUD layers

`HotbarSlot` handles mouse enter/exit and asks `HUDController` to show or hide the tooltip. `HUDController` then debounces the hover, owns the timer, and writes into `CardTooltip`. That is a reasonable UI composition, but it is more layered than necessary for a single hover effect.

Risk: low-medium. This is not a logic bug, but it is repeated UI orchestration.

Files:
- [scripts/ui/hud/HotbarSlot.gd](scripts/ui/hud/HotbarSlot.gd#L97)
- [scripts/ui/hud/HotbarSlot.gd](scripts/ui/hud/HotbarSlot.gd#L106)
- [scripts/ui/hud/HUDController.gd](scripts/ui/hud/HUDController.gd#L182)
- [scripts/ui/hud/HUDController.gd](scripts/ui/hud/HUDController.gd#L192)

### 2) Reward UI mixes selection workflow and slot replacement workflow in one node

`CardRewardUI` renders reward cards, then mutates into slot-selection mode if replacement is required. The pending-card state, replacement list, and hide/show transitions are all kept in the same canvas-layer UI node.

Risk: low-medium. This is an intentional combined workflow, but it is also a local dead-end abstraction because the node is doing workflow control, not just presentation.

Files:
- [scripts/ui/card_reward/CardRewardUI.gd](scripts/ui/card_reward/CardRewardUI.gd#L38)
- [scripts/ui/card_reward/CardRewardUI.gd](scripts/ui/card_reward/CardRewardUI.gd#L200)
- [scripts/ui/card_reward/CardRewardUI.gd](scripts/ui/card_reward/CardRewardUI.gd#L254)
- [scripts/ui/card_reward/CardRewardUI.gd](scripts/ui/card_reward/CardRewardUI.gd#L352)

### 3) Card tooltip and card-panel schema drift is already visible

`CardTooltip` expects the compact hotbar payload fields, while `CardPanelUI` renders a list from the same payload with a slightly different display vocabulary. These are separate consumers of the same card data shape, which means any future payload change has to be updated in several places.

Risk: medium. The risk is inconsistency rather than immediate breakage.

Files:
- [scripts/ui/hud/CardTooltip.gd](scripts/ui/hud/CardTooltip.gd#L8)
- [scripts/ui/hud/CardPanelUI.gd](scripts/ui/hud/CardPanelUI.gd#L1)
- [scripts/core/cards/CardManager.gd](scripts/core/cards/CardManager.gd#L137)

## Technical Debt From Partial Refactors

### 1) Reward card sourcing still has two sources of truth

`CardRewardManager` dynamically scans `resources/cards` first and falls back to `CardLibrary` if discovery returns nothing. `CardSystemController`, by contrast, uses `CardLibrary.get_starter_deck()` as the source for the player deck. The two systems still have different primary sources, but they now share the same curated fallback library at `resources/cards/card_library.tres`.

Risk: medium. This is a classic partial-refactor symptom: both paths are valid independently, but they are not converged.

Files:
- [scripts/core/cards/CardRewardManager.gd](scripts/core/cards/CardRewardManager.gd#L43)
- [scripts/core/cards/CardRewardManager.gd](scripts/core/cards/CardRewardManager.gd#L59)
- [scripts/core/combat/CardLibrary.gd](scripts/core/combat/CardLibrary.gd#L8)
- [scripts/core/combat/CardLibrary.gd](scripts/core/combat/CardLibrary.gd#L13)
- [scripts/core/cards/CardSystemController.gd](scripts/core/cards/CardSystemController.gd#L145)

### 2) Legacy cleanup hooks remain after newer ownership paths were added

`Main2d` still forces a hotbar refresh after reward completion even though `CardManager` and `CardSystemController` already emit UI state changes. This looks like a residue from the older reward flow, kept as a safety refresh even though the newer signal chain should already update the UI.

Risk: low. It is mostly redundant, but it reveals that the migration did not fully retire the earlier refresh path.

Files:
- [scripts/managers/Main2d.gd](scripts/managers/Main2d.gd#L429)
- [scripts/managers/Main2d.gd](scripts/managers/Main2d.gd#L440)
- [scripts/core/cards/CardSystemController.gd](scripts/core/cards/CardSystemController.gd#L143)

### 3) Range overlay helpers are partially factored but still layered

`TileHighlighter` delegates range caching to `TileHighlighterCache` and drawing to `TileHighlighterRenderer`, which is good decomposition, but the overlay still depends on `CardManager`, `CardTargeting`, `MapManager`, and its own internal hover state. That is a healthy split of responsibilities, yet the live behavior is still assembled across three helper layers.

Risk: low-medium. The code is organized, but the overlay remains a multi-hop system rather than a single owner of card-range truth.

Files:
- [scripts/world/rooms/TileHighlighter.gd](scripts/world/rooms/TileHighlighter.gd#L41)
- [scripts/world/rooms/TileHighlighterCache.gd](scripts/world/rooms/TileHighlighterCache.gd#L1)
- [scripts/world/rooms/TileHighlighterRenderer.gd](scripts/world/rooms/TileHighlighterRenderer.gd#L7)
- [scripts/core/combat/CardTargeting.gd](scripts/core/combat/CardTargeting.gd#L49)

## Confirmed Dead / Unused Helper

`CardTargeting.is_valid_target()` is currently unused outside its own definition. I did not find a live call site in the workspace search results. That makes it a candidate for removal or for explicit adoption if there is a planned caller.

Risk: low.

Files:
- [scripts/core/combat/CardTargeting.gd](scripts/core/combat/CardTargeting.gd#L23)

## Recommended Incremental Cleanups

These are deliberately small and reversible. They are not rewrite proposals.

1. Extract a single internal validator inside `CombatCardSystem` and have `queue_card_action`, `execute_card`, and `execute_card_snapshot` reuse it.
2. Make `CardManager` expose a clearer distinction between cooldown availability and full playability, or rename the current field to reflect its actual scope.
3. Assign one layer as the sole writer for `active_index`. The least risky choice is `CardSystemController`; `PlayerActionController` should only request changes.
4. Keep `MapManager` as the source of hover position and let `TileHighlighter` own only presentation caches, not its own notion of hover identity.
5. Consider aligning reward sourcing so `CardRewardManager` and `CardSystemController` read the same canonical card source instead of mixing directory discovery with library lookup.
6. Remove or explicitly document unused helpers like `CardTargeting.is_valid_target()` if they are not part of the live runtime.

## Risk Summary

- High: duplicate card execution path, repeated validation, and multi-writer active card state.
- Medium-high: basic-attack path mirroring the card pipeline, and split hover ownership.
- Medium: reward flow handoffs, snapshot/live-state hybrid execution, and UI schema drift.
- Low-medium: tooltip orchestration, reward UI workflow mixing, and legacy refresh hooks.
- Low: unused helper cleanup.

## Notes On Runtime Truth

The older `CardContainer`, `SkillCard`, and standalone `TurnManager` references that existed in historical notes are not present as live files in the current workspace tree. I therefore did not count them as current runtime overlap, even though they are useful as historical context for the refactor story.