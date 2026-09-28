# _deprecated

Code replaced but kept for reference (`.gdignore` → Godot never loads it).

- `map_v1/` (sesión 3): hardcoded `Main2d.LAYOUT` dict, 4 hand-placed `Doors/*` in `Main2d.tscn`, `RoomManager.build_from_layout(dict)`, `NexoController` hardcoded to `"start_room"`. Replaced by `MapLayout`/`MapGenerator` (`scripts/world/map/`) + `RoomManager.build_from_map()` + runtime door spawning in `Main2d`. Same layout lives on as `resources/maps/fallback_layout.tres`.
- `hud_v1/` (sesión 6): `HUD.tscn` with the bottom-center stat bar (HP as `"32/32"` text + 4 resources), and the list-of-buttons `BuildingMenu.gd`/`.tscn`. Replaced by the top-left resource bar with per-turn gain, the `HeroPortrait` column (top-right) + `CharacterPopup`, and the tabbed/card `BuildingMenu`.
