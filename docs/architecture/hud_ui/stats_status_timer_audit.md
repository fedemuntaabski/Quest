# Stats, Status, and Timer UI Audit

This document covers the stat and status presentation layer:

- [StatPanelUI.gd](../../scripts/ui/hud/StatPanelUI.gd)
- [StatIcon.gd](../../scripts/ui/hud/StatIcon.gd)
- [StatusIndicator.gd](../../scripts/ui/hud/StatusIndicator.gd)
- [TimerUI.gd](../../scripts/ui/hud/TimerUI.gd)

## Shared System Summary

This group of scripts is mostly presentation-only, which is good. `StatPanelUI` and `TimerUI` render gameplay values, `StatIcon` is a custom-drawn visual component, and `StatusIndicatorUI` mirrors status data from gameplay state. The main architectural concern is not that these scripts own too much gameplay logic; it is that `HUDController` currently orchestrates the stat panel, the potion control, and multiple tooltip behaviors in one place.

## StatPanelUI

### Script Purpose

Renders the player’s current HP and stat totals.

### Current Responsibilities

- Displays HP, strength, magic, and dexterity labels.
- Calls `CharacterStats` methods for total stat values.
- Updates HP independently when health changes.

### Dependencies

- `CharacterStats` for current and total stats.
- `HUDController` for data flow into the panel.

### Data Flow

- Input is a live `CharacterStats` object.
- Output is label text only.

### Potential Problems

- Depends on `CharacterStats` behavior and methods remaining stable.
- If more stat fields are added, the panel may need broader normalization logic.

### Overlap Analysis

- Overlaps loosely with `HUDController`, which owns the binding and refresh trigger.
- Does not overlap strongly with `StatIcon`; the two are complementary.

### Recommendations

- Keep the panel as a pure renderer.
- Avoid putting stat calculation logic here; let `CharacterStats` continue to own totals.

### Refactor Priority

Low. This component is appropriately narrow.

## StatIcon

### Script Purpose

Custom-draws a stylized stat icon for HP, strength, magic, dexterity, or potion.

### Current Responsibilities

- Draws icon shapes in `_draw()`.
- Supports export-driven configuration for icon type, outline, shadow, and offsets.
- Responds to size and property changes by redrawing.

### Dependencies

- Only Godot drawing APIs.
- The `icon_type` enum values used by the HUD scene.

### Data Flow

- Input is style configuration.
- Output is vector-drawn UI.

### Potential Problems

- It is purely visual, which is good, but it is duplicated by the need to maintain several shape variants by hand.
- If icon styles change, multiple drawing branches must be kept in sync.

### Overlap Analysis

- Overlaps with no other gameplay script; it is self-contained.

### Recommendations

- Keep this isolated from all gameplay logic.
- If more icons are needed, consider a resource-driven or texture-based approach before expanding the draw code further.

### Refactor Priority

Low. This is a healthy, isolated UI component.

## StatusIndicatorUI

### Script Purpose

Displays active statuses and their durations for a character.

### Current Responsibilities

- Clears and rebuilds status icons on refresh.
- Maps status IDs to icon paths.
- Displays duration next to each icon.
- Hides itself when there are no statuses.

### Dependencies

- `StatusComponent` indirectly, through `refresh_statuses()` calls from the owning actor.
- Status icon asset paths in `assets/ui/status/`.
- Scene composition in `StatusIndicator.tscn`.

### Data Flow

- Gameplay status state is owned by `StatusComponent`.
- `StatusComponent._on_status_changed()` pushes a simplified dictionary into this UI.
- The UI renders the dictionary and does not mutate gameplay state.

### Potential Problems

- Rebuilds all child nodes every refresh, which is simple but not especially scalable.
- Status-to-icon mapping is hard-coded in the UI layer.
- Assumes the status data shape will stay stable.

### Overlap Analysis

- Overlaps conceptually with gameplay status processing, but not in ownership.
- Should not overlap with `StatusComponent` state logic, and currently it does not.

### Recommendations

- Keep the ownership boundary explicit: this is a view, not the status owner.
- If status count grows, move to pooled children or a reusable row component.
- Consider a status icon registry if more status types are added.

### Refactor Priority

Medium. The current design is fine, but the hard-coded mapping will become brittle as statuses expand.

## TimerUI

### Script Purpose

Displays a formatted room timer.

### Current Responsibilities

- Converts seconds into `MM:SS` text.
- Applies a supplied color to the timer label.

### Dependencies

- `HUDController` for updates.
- The scene node containing `TimerLabel`.

### Data Flow

- Input is numeric time and a color.
- Output is label text and label modulation.

### Potential Problems

- None significant at the moment; the component is intentionally minimal.

### Overlap Analysis

- No meaningful overlap with gameplay logic.

### Recommendations

- Keep this script simple and presentation-only.

### Refactor Priority

Low. This is appropriately scoped.

## Cross-Cutting Findings

- `StatusComponent` remains the gameplay owner for statuses, which is the correct boundary.
- The main risk is not ownership confusion inside these scripts, but future coupling if more state gets pushed into `HUDController`.
- `StatusIndicatorUI` should continue to consume status dictionaries rather than derive state on its own.