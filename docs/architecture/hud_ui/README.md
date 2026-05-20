# HUD/UI Architecture Audit

This directory documents the live HUD and UI architecture for the tactical card game. The goal is to describe responsibilities, data flow, signal flow, state ownership, and architectural risks without rewriting the system.

## Scope

- [HUDController.gd](../../scripts/ui/hud/HUDController.gd)
- [HotbarSlot.gd](../../scripts/ui/hud/HotbarSlot.gd)
- [CardTooltip.gd](../../scripts/ui/hud/CardTooltip.gd)
- [CardPanelUI.gd](../../scripts/ui/hud/CardPanelUI.gd)
- [StatPanelUI.gd](../../scripts/ui/hud/StatPanelUI.gd)
- [StatIcon.gd](../../scripts/ui/hud/StatIcon.gd)
- [StatusIndicator.gd](../../scripts/ui/hud/StatusIndicator.gd)
- [TimerUI.gd](../../scripts/ui/hud/TimerUI.gd)
- [CardRewardUI.gd](../../scripts/ui/card_reward/CardRewardUI.gd)

## Reading Order

1. [card_ui_audit.md](card_ui_audit.md) for the card hotbar, tooltip, and deck panel flow.
2. [stats_status_timer_audit.md](stats_status_timer_audit.md) for the stat panel, icon rendering, status display, and room timer.
3. [card_reward_audit.md](card_reward_audit.md) for reward selection and replacement flow.

## High-Level Ownership Model

- Gameplay state is owned by core systems such as `CardManager`, `StatusComponent`, `GameStateManager`, and `CardRewardManager`.
- HUD nodes should render that state, forward player intent, and avoid becoming a second source of truth.
- `HUDController` is the central coordination layer for the visible HUD, but it should remain a presenter and signal bridge rather than a gameplay decision maker.
- `CardRewardUI` is the clearest example of a UI node that also carries workflow state; that is acceptable for now, but it is a maintenance risk that should be documented explicitly.

## Key Risks

- Card payload formatting is duplicated across multiple UI consumers.
- Hover tooltip routing is layered through `HotbarSlot -> HUDController -> CardTooltip`.
- Reward selection re-emits through `HUDController` before reaching `Main2d`, increasing signal hops.
- HUD-owned potion gating blends UI presentation with gameplay validation.
- Status rendering is cleanly separated from status ownership, but the boundary should remain explicit as the system grows.