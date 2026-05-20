# Card Reward UI Audit

This document covers [CardRewardUI.gd](../../scripts/ui/card_reward/CardRewardUI.gd).

## Script Purpose

`CardRewardUI` presents the post-combat reward choice, and when replacement is required it also becomes the slot-selection UI for resolving the reward.

## Current Responsibilities

- Displays reward cards.
- Builds card buttons with hover and selection feedback.
- Shows reward metadata, stats, and effect summaries.
- Supports a two-stage workflow when the hotbar is full.
- Stores pending reward state until a replacement slot is chosen.
- Emits `card_selected`, `card_replace_selected`, and `reward_skipped`.
- Manages open/close animation and visibility.

## Dependencies

- `CardData` resources and card metadata.
- `HUDController` as the signal bridge.
- `Main2d` and `CardRewardManager` downstream of the HUD signal path.
- `StatTypes` for reward summary labels.
- Scene composition in `CardRewardUI.tscn`.

## Data Flow

- Input arrives from the game flow through `HUDController.show_reward_selection()`.
- The UI renders a card list from an Array of `CardData` resources.
- If replacement is required, the selected card is stored in `_pending_card` until a slot is selected.
- When the user confirms, the UI emits either card selection or replacement selection.
- `HUDController` re-emits those signals to the game layer.

## Signal / Event Flow

1. `GameStateManager` enters reward state.
2. `Main2d` asks the HUD to show the reward selection.
3. `CardRewardUI` emits selection or skip signals.
4. `HUDController` re-emits those signals.
5. `Main2d` receives the choice and applies the reward through `CardRewardManager`.

## Potential Problems

- The UI owns temporary workflow state, not just presentation state.
- `_pending_card` is necessary for the current flow, but it means the node is carrying orchestration state.
- The selection workflow and the replacement workflow are tightly coupled inside the same node.
- The UI is one hop away from `Main2d`, but still requires `HUDController` to forward its events.
- The reward card payload is interpreted here using yet another display vocabulary, which adds to the card-schema duplication already present elsewhere.

## Overlap Analysis

- Overlaps with `CardTooltip` and `CardPanelUI` on card metadata presentation.
- Overlaps with `HUDController` on reward-event propagation.
- Overlaps with `CardManager` and `CardRewardManager` on reward-related state transitions, but does not own the actual deck mutation.

## Recommendations

- Keep the current behavior, but treat the node as workflow-bearing UI rather than a pure view.
- If reward flow grows, split rendering from replacement selection into separate child controls.
- Move shared reward-card formatting into a reusable adapter or helper so it matches the other card UI surfaces.
- Consider removing the extra event hop through `HUDController` only if the scene wiring becomes simpler and more explicit.

## Refactor Priority

High. The current design works, but it concentrates several responsibilities into one UI node and increases the cost of future reward-flow changes.

## Overlap With Other Systems

- This script is part of the same card presentation family as `HotbarSlot`, `CardTooltip`, and `CardPanelUI`.
- It is the clearest example of a UI node that also owns temporary decision state.
- It does not own gameplay mutation, but it participates in the workflow that eventually mutates the deck through `CardRewardManager`.