# Card UI Audit

This document covers the live card presentation and hotbar UI path:

- [HUDController.gd](../../scripts/ui/hud/HUDController.gd)
- [HotbarSlot.gd](../../scripts/ui/hud/HotbarSlot.gd)
- [CardTooltip.gd](../../scripts/ui/hud/CardTooltip.gd)
- [CardPanelUI.gd](../../scripts/ui/hud/CardPanelUI.gd)

## Shared System Summary

The card UI is split across four layers:

1. `CardManager` owns deck, equipped, cooldown, and active-selection state.
2. `HUDController` binds to card state, refreshes UI widgets, and forwards slot/reward events.
3. `HotbarSlot` handles local slot visuals and mouse events.
4. `CardTooltip` and `CardPanelUI` render different views of the same payload.

The architecture is broadly sound, but it currently has duplicated card formatting, layered tooltip orchestration, and a central HUD node that has started to absorb some gameplay-adjacent policy.

## HUDController

### Script Purpose

`HUDController` is the presentation hub for the visible HUD. It connects the card runtime to the UI, refreshes the hotbar and card panel, binds stat display updates, routes tooltip display, and bridges reward-selection signals back to the game flow.

### Current Responsibilities

- Finds and stores references to HUD subnodes.
- Tracks the bound `CardManager` and listens to `ui_state_changed`.
- Refreshes hotbar slots from the card payload.
- Refreshes the card panel from the same payload.
- Routes hotbar hover into tooltip display with a debounce timer.
- Owns and updates the simple stat tooltip.
- Binds player stats and refreshes stat labels.
- Manages potion button state and uses current `PlayerStats` to heal the player.
- Re-emits reward selection signals from `CardRewardUI`.
- Updates timer, room, and enemy counters.

### Dependencies

- `CardManager` for equipped payload and UI state.
- `PlayerStats` and `CharacterStats` for stat display and potion behavior.
- `GameStateManager` for potion availability checks.
- `HotbarSlot`, `CardPanelUI`, `CardTooltip`, `CardRewardUI`, `StatPanelUI`, `TimerUI`.
- Scene tree paths under `scenes/HUD.tscn`.

### Data Flow

- Input enters through `bind_card_manager()` and `HotbarSlot.slot_pressed`.
- `CardManager.ui_state_changed` triggers `update_hotbar()` and `update_cards_panel()`.
- Hover enters `HotbarSlot`, which asks `HUDController` to show or hide the tooltip.
- Tooltip data is buffered by a short-lived timer and then written into `CardTooltip`.
- Stat changes enter from `PlayerStats.stats_changed` and update `StatPanelUI`.
- Potion click enters through the HUD button, checks gameplay state, then heals `PlayerStats.stats` directly.

### Potential Problems

- The controller is close to a god object for the HUD layer.
- Potion usage is a gameplay effect owned by the HUD, not by a gameplay or inventory system.
- Tooltip display is split across three nodes and a debounce timer.
- The HUD stores and interprets card payload details instead of only presenting them.
- `update_hotbar()` and `update_cards_panel()` both consume the same data but independently reinterpret it.
- `show_simple_tooltip()` and `show_card_tooltip()` are parallel tooltip systems in the same class.

### Overlap Analysis

- `HUDController` overlaps with `HotbarSlot` on selection state presentation and tooltip routing.
- It overlaps with `CardTooltip` and `CardPanelUI` on card payload interpretation.
- It overlaps with gameplay systems on potion gating and healing.

### Recommendations

- Keep `HUDController` as a signal bridge, but move card payload normalization into `CardManager` or a dedicated presentation adapter.
- Replace direct potion healing in the HUD with a gameplay-facing consumable or action service.
- Collapse tooltip routing into a simpler ownership model if the debounce is no longer needed.
- Separate stat tooltip text construction from HUD orchestration.

### Refactor Priority

High. This is the main coordination point for the HUD and the most likely place for future coupling growth.

## HotbarSlot

### Script Purpose

`HotbarSlot` renders one equipped-card slot and forwards local mouse events to the HUD.

### Current Responsibilities

- Displays icon, name, cooldown, selection, and usability state.
- Emits `slot_pressed` on click.
- Applies hover and selection animations.
- Calls into the tooltip host on mouse enter and exit.

### Dependencies

- `HUDController` as `tooltip_host`.
- Card payload dictionaries produced by the card runtime.
- Scene nodes defined in `HotbarSlot.tscn`.

### Data Flow

- Receives payload dictionaries from `HUDController.update_hotbar()`.
- Pushes click and hover events back to `HUDController`.
- Uses card fields such as `name`, `icon`, `cooldown_remaining`, `full_playable`, `is_usable`, and playability reasons.

### Potential Problems

- Uses fallback keys that must stay in sync with other card views.
- Treats a data dictionary as a presentation contract without validation at the boundary.
- Delegates tooltip display upward rather than owning local hover presentation.

### Overlap Analysis

- Overlaps with `CardTooltip` and `CardPanelUI` on card display vocabulary.
- Overlaps with `HUDController` on selection and tooltip state presentation.

### Recommendations

- Keep slot behavior narrow: input, visuals, and payload forwarding only.
- Avoid adding more payload interpretation here unless the same normalization is also used elsewhere.

### Refactor Priority

Medium. The class is focused, but it is part of the duplicated card-presentation surface.

## CardTooltip

### Script Purpose

`CardTooltip` renders a compact hover tooltip for a card payload.

### Current Responsibilities

- Displays name, description, and detail lines.
- Switches visibility based on whether the payload is empty.
- Converts card data into localized display text.

### Dependencies

- Payload dictionaries from `HotbarSlot -> HUDController`.
- `StatTypes` for scaling labels.

### Data Flow

- Input is a normalized card dictionary from the HUD path.
- Output is purely visual: labels and visibility state.

### Potential Problems

- Reinterprets the same payload shape as other UI elements.
- Owns presentation logic but depends on upstream payload conventions being stable.

### Overlap Analysis

- Overlaps with `CardPanelUI` and `HotbarSlot` on card field interpretation.
- Overlaps indirectly with `CardRewardUI` because all three render the same card data family.

### Recommendations

- Keep this component strictly presentational.
- If payload fields grow, consider a shared card presentation adapter instead of adding more local fallback logic.

### Refactor Priority

Medium. The component is small, but it is exposed to schema drift from multiple sources.

## CardPanelUI

### Script Purpose

`CardPanelUI` renders the list view of equipped cards.

### Current Responsibilities

- Stores a local copy of card entries.
- Clears and rebuilds the deck list on refresh.
- Builds a row for each card or empty slot.
- Displays slot number, icon, name, state, description, and stat summary.

### Dependencies

- `StatTypes` for stat labels.
- Card payload dictionaries passed from `HUDController`.

### Data Flow

- Receives the same card payload as the hotbar, but re-renders it in a fuller, list-style format.
- Does not push gameplay events back out.

### Potential Problems

- Repeats card-field formatting logic already present in `CardTooltip`, `HotbarSlot`, and `CardRewardUI`.
- Builds UI nodes procedurally every refresh, which is acceptable at the current scale but can become noisy if the deck list grows or refreshes frequently.
- Uses hard-coded display text and color coding that may diverge from the rest of the HUD.

### Overlap Analysis

- Overlaps with `CardTooltip` on card detail interpretation.
- Overlaps with `HotbarSlot` on card name, cooldown, and usability presentation.

### Recommendations

- Treat this as a read-only deck browser.
- If more card metadata is added, centralize formatting rules before duplicating them here.

### Refactor Priority

Medium. The logic is simple but highly redundant with other card UI views.

## Cross-Cutting Findings

- The same card payload is formatted in at least four places: `CardManager`, `HotbarSlot`, `CardTooltip`, `CardPanelUI`, and `CardRewardUI`.
- `HUDController` is the current coordination bottleneck for hover and reward flows.
- The tooltip path is layered, but not broken.
- The biggest maintenance risk is schema drift: one payload change can silently affect several UI surfaces.