# HUD/UI Architecture Audit

This directory documents the live HUD and UI architecture for the tactical card game. The goal is to describe responsibilities, data flow, signal flow, state ownership, and architectural risks without rewriting the system.

## 🔄 Recent Stabilization Work (May 2026)

### Phase 1 ✅ — Workflow State Separation
Extracted workflow orchestration from CardRewardUI into dedicated `RewardFlowState` class. CardRewardUI is now purely presentational; multi-step reward logic is explicit and validated.
- **Files**: [RewardFlowState.gd](../../scripts/ui/card_reward/RewardFlowState.gd), [CardRewardUI.gd](../../scripts/ui/card_reward/CardRewardUI.gd)

### Phase 2 ✅ — Signal Ownership Mapping
Documented signal chains, ownership at each hop, and relay rationale. Relay patterns are intentional and acceptable for scene decoupling.
- **Files**: [SIGNAL_TOPOLOGY_MAP.md](SIGNAL_TOPOLOGY_MAP.md)

### Phase 3A ✅ — Typed Payload Contracts
Created explicit `CardDisplayData` wrapper and `CardPresentationAdapter` to replace implicit dictionary payloads. Single point of normalization for card display fields.
- **Files**: [CardDisplayData.gd](../../scripts/ui/hud/CardDisplayData.gd), [CardPresentationAdapter.gd](../../scripts/ui/hud/CardPresentationAdapter.gd), [PAYLOAD_CONTRACT_PLAN.md](PAYLOAD_CONTRACT_PLAN.md)

### Phase 3B (TODO) — Consumer Migration
Update UI consumers (HotbarSlot, CardTooltip, CardPanelUI) to accept typed `CardDisplayData` incrementally.

---

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
- [RewardFlowState.gd](../../scripts/ui/card_reward/RewardFlowState.gd) (NEW)
- [CardDisplayData.gd](../../scripts/ui/hud/CardDisplayData.gd) (NEW)
- [CardPresentationAdapter.gd](../../scripts/ui/hud/CardPresentationAdapter.gd) (NEW)

## Reading Order

1. [card_ui_audit.md](card_ui_audit.md) for the card hotbar, tooltip, and deck panel flow.
2. [stats_status_timer_audit.md](stats_status_timer_audit.md) for the stat panel, icon rendering, status display, and room timer.
3. [card_reward_audit.md](card_reward_audit.md) for reward selection and replacement flow.
4. [SIGNAL_TOPOLOGY_MAP.md](SIGNAL_TOPOLOGY_MAP.md) for signal ownership and relay analysis (NEW).
5. [PAYLOAD_CONTRACT_PLAN.md](PAYLOAD_CONTRACT_PLAN.md) for typed payload migration strategy (NEW).

## High-Level Ownership Model

- Gameplay state is owned by core systems such as `CardManager`, `StatusComponent`, `GameStateManager`, and `CardRewardManager`.
- HUD nodes should render that state, forward player intent, and avoid becoming a second source of truth.
- `HUDController` is the central coordination layer for the visible HUD, but it should remain a presenter and signal bridge rather than a gameplay decision maker.
- `CardRewardUI` now delegates workflow state to `RewardFlowState`; it owns only presentation and input handling.
- Card display payloads are normalized through `CardPresentationAdapter` into typed `CardDisplayData` objects.

## Key Risks & Mitigations

| Risk | Mitigation | Status |
|------|-----------|--------|
| Workflow state scattered in UI | Extracted to `RewardFlowState` | ✅ Mitigated |
| Signal ownership unclear | Documented in `SIGNAL_TOPOLOGY_MAP` | ✅ Mitigated |
| Payload schema drift | Typed `CardDisplayData` + adapter | ✅ In Progress |
| Card formatting duplicated | Single `CardPresentationAdapter` | ✅ In Progress |
| Tooltip routing fragmented | Documented; Phase 4 refactor planned | ⚠️ Noted |
| HUD-owned potion logic | Beyond scope; document if expanding | ⚠️ Noted |

## Implementation Guidance

### For New Features

- **Reward flow extensions** (reroll, preview, upgrades): Add state types to `RewardFlowState`, not to `CardRewardUI`.
- **Card display fields**: Update `CardDisplayData` fields and `CardPresentationAdapter`, not individual consumers.
- **UI signals**: Document ownership in `SIGNAL_TOPOLOGY_MAP` before adding new chains.

### For Bug Fixes

- **Reward selection issues**: Trace through `RewardFlowState` state machine first.
- **Card display inconsistencies**: Check `CardPresentationAdapter` normalization.
- **Signal flow problems**: Reference `SIGNAL_TOPOLOGY_MAP` for authority and ownership.