# session9 snapshots (taken at the start of session 10)

State before the research system (Ciencia sink) was added. Godot ignores this folder (`.gdignore` in `_deprecated/`).

| File | Replaced by (session 10) |
|---|---|
| `ResourceManager.gd` | + research state: `research_config`, `can_research`/`research`/`is_unlocked`/`get_bonus`/`reset_research`, `research_changed`; generator bonus × (1 + GENERATOR_YIELD_PCT) |
| `Main.gd` | `_begin_new_run()` also calls `reset_research()` |
| `BuildingMenu.gd` | locked modules: padlock + "Requiere: X", not armable, `get_block_reason` reports the lock |
| `HUDController.gd`, `HUD.tscn` | "Investigar" button + code-built `ResearchPanel` docked in `BottomBar`; Ciencia tooltip |
| `StatIcon.gd` | new `"lock"` icon |
| `TurretModule.gd` | `get_damage()` = damage + TURRET_DAMAGE bonus |
| `RoomZone.gd`, `RoomLight.gd`, `EnergyButton.gd`, `RoomPowerSystem.gd` | `RoomZone.get_power_cost()` (POWER_COST − research, min 1) |
| `FloorManager.gd` | discovery dust + DISCOVERY_DUST bonus |
