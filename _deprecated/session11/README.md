# session11 snapshots (taken at the start of session 12)

State before multi-hero. One hero per floor, one global `run_level`, camera following `get_parent()`. Godot ignores this folder (`.gdignore` in `_deprecated/`).

| File | Replaced by (session 12) |
|---|---|
| `PlayerStats.gd` | `heroes` (hero_id → CharacterStats), `run_levels` (hero_id → levels), `active_hero_id`; `stats`/`run_level` = read-only views of the active hero; level API takes an optional `hero_id`; `select_hero`/`cycle_active_hero`/`clear_party`/`get_all_stats`/`get_hero_ids`; `active_hero_changed`; `run_upgrades_changed` gains `hero_id` |
| `CharacterStats.gd` | `hero_id` |
| `Player.gd` | sets `stats.hero_id`; `sprite_offset` |
| `Main2d.gd` | `party_config` + `_spawn_heroes()` (N Players, one camera), `heroes`, `camera`, Tab (`hero_cycle`), `_on_active_hero_changed` |
| `GameCamera.gd` | `follow(target)` / `get_target()` |
| `PlayerActionController.gd` | `set_player()`; `_run_move` finishes with the hero that left |
| `ManagerLocator.gd` | `get_player()` = active hero; `get_heroes()` |
| `HUDController.gd`, `HeroPortrait.gd`, `CharacterPopup.gd` | portraits per hero id + selection border; left = select / sheet, right = sheet; popup levels its own hero |
| `Enemy.gd` | SWARM/SAPPER → nearest hero; HUNTER → Nexo carrier |
| `Minimap.gd` | one dot per hero |
| `MapGenerator.gd` | `add_loops` never uses the exit room |
| `test_hud_ui.gd`, `test_map_generator.gd` | 1-hero party regression; no loop touches the exit |
