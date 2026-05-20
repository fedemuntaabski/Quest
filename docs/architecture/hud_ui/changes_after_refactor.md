# HUD/UI Refactor Notes

This file documents the recent, small-scope refactors applied to stabilize the HUD UI.

Changes made:

- Introduced `CardViewModel` (`scripts/ui/hud/CardViewModel.gd`) — a UI-only adapter that normalizes gameplay card payloads into a stable presentation contract. UI widgets should consume this adapter rather than reinterpreting gameplay payloads.

- Moved tooltip timing ownership into `CardTooltip` (`scripts/ui/hud/CardTooltip.gd`). The tooltip now exposes `request_show(data)` and `request_hide()` and owns a short debounce `Timer` (0.08s). `HUDController` and `HotbarSlot` now delegate to the tooltip node.

- Extracted potion UI/logic into `PotionController` (`scripts/ui/hud/PotionController.gd`). This node owns potion button wiring, game-state binding, and refresh logic. `HUDController` now creates and wires a `PotionController` instance instead of owning potion logic directly.

- Centralized card presentation formatting in the adapter and migrated `HotbarSlot`, `CardTooltip`, `CardPanelUI`, and `CardRewardUI` to use it.

Notes and next steps:

1. Removing presentation-only fields from `CardManager.get_equipped_payload()` is recommended once all UI consumers are migrated to `CardViewModel` (current migration is partial but covers main consumers).

2. Consider centralizing localized strings and user-facing labels used by `CardViewModel` to ease translation.

3. If you prefer HotbarSlot to not accept CardTooltip directly, you can reintroduce a small `CardTooltipController` abstraction; the current direct-node wiring is acceptable and simpler.

4. Verify UI flows in editor after these changes (hover tooltips, potion press, reward menu text) and report any visual regressions.
