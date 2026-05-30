# World Generation Changes Log

Date: 2026-05-30

This document summarizes the implementation work completed in this chat for the dungeon/world generation pipeline and adjacent enemy-flow helpers. The goal of the changes was to keep the current architecture intact while making corridor generation, room roles, tiles, walls, and future content expansion more configurable.

## Scope

The work focused on the live gameplay path:

- [scenes/Main2d.tscn](../../scenes/Main2d.tscn)
- [scenes/MapManager.tscn](../../scenes/MapManager.tscn)
- [scripts/managers/Main2d.gd](../../scripts/managers/Main2d.gd)
- [scripts/world/rooms/MapManager.gd](../../scripts/world/rooms/MapManager.gd)
- [scripts/world/dungeon/DungeonGenerator.gd](../../scripts/world/dungeon/DungeonGenerator.gd)
- [scripts/world/dungeon/DungeonLayoutGenerator.gd](../../scripts/world/dungeon/DungeonLayoutGenerator.gd)
- [scripts/world/dungeon/DungeonGraph.gd](../../scripts/world/dungeon/DungeonGraph.gd)
- [scripts/world/dungeon/DungeonTileRenderer.gd](../../scripts/world/dungeon/DungeonTileRenderer.gd)
- [scripts/world/dungeon/DungeonWallManager.gd](../../scripts/world/dungeon/DungeonWallManager.gd)
- [scripts/core/enemy/EnemyManager.gd](../../scripts/core/enemy/EnemyManager.gd)
- [scripts/core/enemy/EnemyDataSelector.gd](../../scripts/core/enemy/EnemyDataSelector.gd)
- [scripts/core/enemy/EnemySpawnLifecycleService.gd](../../scripts/core/enemy/EnemySpawnLifecycleService.gd)

## 1. Corridor Generation

### What changed

Corridor generation was extended from a fixed-width, warning-only system into a configurable, rollback-safe system.

### Files changed

- [scripts/world/dungeon/DungeonGenerator.gd](../../scripts/world/dungeon/DungeonGenerator.gd)
- [scripts/world/dungeon/DungeonLayoutGenerator.gd](../../scripts/world/dungeon/DungeonLayoutGenerator.gd)

### Details

- Added `corridor_width` as an exported setting on `DungeonGenerator`.
- Added `enforce_corridor_max_length` as an exported setting.
- `DungeonLayoutGenerator._carve_corridor()` now stamps corridor cells with configurable thickness.
- Corridor width is applied perpendicular to the travel segment so horizontal corridors can become taller and vertical corridors can become wider.
- When strict max-length enforcement is enabled, corridors that exceed the configured maximum are rolled back and the layout generation retries.
- The previous behavior is preserved by default because strict max-length enforcement is off unless explicitly enabled.
- Corridor connection functions now return success/failure so generation can retry cleanly when corridor constraints fail.

### Impact

- Corridor width can now be increased from 1 to 3 without redesigning the dungeon pipeline.
- Corridor length can now be treated as a hard constraint instead of only a warning.
- The layout system remains grid-based and compatible with floor/wall/nav occupancy.

## 2. Room Role Metadata

### What changed

Room generation now assigns explicit semantic metadata instead of relying only on room id conventions.

### Files changed

- [scripts/world/dungeon/DungeonGraph.gd](../../scripts/world/dungeon/DungeonGraph.gd)
- [scripts/world/dungeon/DungeonLayoutGenerator.gd](../../scripts/world/dungeon/DungeonLayoutGenerator.gd)
- [scripts/world/dungeon/DungeonGenerator.gd](../../scripts/world/dungeon/DungeonGenerator.gd)

### Details

- Added `DungeonGraph.TEMPLATE_TUTORIAL`.
- Room 0 now receives the tutorial template when tutorial rooms are enabled.
- The final room can be tagged as boss when boss rooms are enabled.
- Room records now include:
  - `template`
  - `room_role`
  - `size_category`
- Added generator helpers so downstream systems can query room metadata without reading raw dictionaries:
  - `get_room_template(room_id)`
  - `get_room_role(room_id)`
  - `get_room_size_category(room_id)`

### Impact

- Tutorial-first and boss-last behavior is now represented in data instead of only implicit index assumptions.
- Future room-type routing can use semantic room metadata instead of room numbering hacks.

## 3. Room Size Classification

### What changed

Rooms now get a coarse size category for future content expansion.

### Files changed

- [scripts/world/dungeon/DungeonGenerator.gd](../../scripts/world/dungeon/DungeonGenerator.gd)
- [scripts/world/dungeon/DungeonLayoutGenerator.gd](../../scripts/world/dungeon/DungeonLayoutGenerator.gd)
- [scripts/world/dungeon/DungeonGraph.gd](../../scripts/world/dungeon/DungeonGraph.gd)

### Details

- Added exported thresholds on `DungeonGenerator`:
  - `room_small_threshold`
  - `room_medium_threshold`
- `DungeonLayoutGenerator` computes each room’s area and maps it to one of:
  - `small`
  - `medium`
  - `large`
- That size category is stored in room info and copied into graph room records.

### Impact

- Future content can target room size classes without changing the placement algorithm.
- Special rooms, elites, or room variants can be routed by size later.

## 4. Floor Tile Theming

### What changed

Floor tile selection was made data-driven at the generator level, with resource-based profile support.

### Files changed

- [scripts/world/dungeon/DungeonGenerator.gd](../../scripts/world/dungeon/DungeonGenerator.gd)
- [scripts/world/dungeon/DungeonTileRenderer.gd](../../scripts/world/dungeon/DungeonTileRenderer.gd)
- [scripts/world/dungeon/DungeonFloorThemeProfile.gd](../../scripts/world/dungeon/DungeonFloorThemeProfile.gd)

### Details

- Added `DungeonFloorThemeProfile` as a Resource for floor theme definitions.
- Added `floor_theme_profile` export to `DungeonGenerator`.
- Existing hardcoded atlas coordinates were kept as fallback fields on `DungeonGenerator`.
- `get_floor_tile_profile()` now returns values from `floor_theme_profile` when assigned, otherwise it falls back to the existing exported values.
- `DungeonTileRenderer` now reads a floor profile from the generator at setup time.
- The renderer no longer depends on only hardcoded tile atlas constants.

### Impact

- Different floor tilesets can be swapped without changing renderer logic.
- Biome- or theme-specific floor art can be introduced by assigning a different resource.
- The current visual output remains stable because existing defaults are preserved.

## 5. Wall Theming

### What changed

Wall visuals were made configurable through a wall theme profile resource and generator-level overrides.

### Files changed

- [scripts/world/dungeon/DungeonGenerator.gd](../../scripts/world/dungeon/DungeonGenerator.gd)
- [scripts/world/dungeon/DungeonWallManager.gd](../../scripts/world/dungeon/DungeonWallManager.gd)
- [scripts/world/dungeon/DungeonWallThemeProfile.gd](../../scripts/world/dungeon/DungeonWallThemeProfile.gd)

### Details

- Added `DungeonWallThemeProfile` as a Resource for wall texture styling.
- Added `wall_theme_profile` export to `DungeonGenerator`.
- `DungeonGenerator` now exposes `get_wall_theme_profile()`.
- `DungeonWallManager` now reads wall texture, tint, and scale multiplier from the wall profile if one is assigned.
- Existing wall texture/modulate/scale fields remain as fallbacks.

### Impact

- Wall art can be swapped more easily.
- Room- or biome-specific wall styling becomes much easier to add later.
- Procedural wall generation still works the same way; only the visual source is configurable.

## 6. Enemy Spawn and Boss Flow

### What changed

Enemy selection now respects explicit room templates, and boss room discovery prefers template metadata instead of only the highest room id.

### Files changed

- [scripts/core/enemy/EnemyManager.gd](../../scripts/core/enemy/EnemyManager.gd)
- [scripts/core/enemy/EnemyDataSelector.gd](../../scripts/core/enemy/EnemyDataSelector.gd)
- [scripts/core/enemy/EnemySpawnLifecycleService.gd](../../scripts/core/enemy/EnemySpawnLifecycleService.gd)
- [scripts/world/dungeon/DungeonLayoutGenerator.gd](../../scripts/world/dungeon/DungeonLayoutGenerator.gd)

### Details

- `EnemyDataSelector` now supports a template-aware selection path.
- Tutorial rooms can resolve tutorial enemy data through `tutorial_room` metadata.
- Boss rooms can resolve boss enemy data through `boss_room` metadata.
- `EnemyManager.get_enemy_scene_for_room()` now accepts an optional room template string.
- `EnemySpawnLifecycleService` now passes room template metadata into enemy selection.
- The final room id computation now prefers a room explicitly tagged as a boss room when available.
- This preserves the existing room-id fallback behavior, so older content still works.

### Impact

- Boss flow is less dependent on room ordering conventions.
- Future generation systems can reorder rooms more safely as long as the semantic room role stays intact.
- Tutorial and boss selection logic is now better aligned with room metadata.

## 7. Generator Accessors and Extensibility

### What changed

The generator now exposes a few helper methods to reduce direct dictionary access.

### Files changed

- [scripts/world/dungeon/DungeonGenerator.gd](../../scripts/world/dungeon/DungeonGenerator.gd)

### Details

Added helper methods:

- `get_room_template(room_id)`
- `get_room_role(room_id)`
- `get_room_size_category(room_id)`
- `get_floor_tile_profile()`
- `get_wall_theme_profile()`

### Impact

- Downstream code can query dungeon metadata more safely.
- The generator is slightly easier to extend without more dictionary-shaped coupling.

## 8. Analyzer Compatibility Fixes

### What changed

A type-resolution issue in the layout generator was fixed so GDScript diagnostics would pass cleanly.

### Files changed

- [scripts/world/dungeon/DungeonLayoutGenerator.gd](../../scripts/world/dungeon/DungeonLayoutGenerator.gd)
- [scripts/world/dungeon/DungeonLayoutData.gd](../../scripts/world/dungeon/DungeonLayoutData.gd)

### Details

- Added explicit local preloads for `DungeonGraph` and `DungeonLayoutData` so the analyzer can resolve them cleanly.
- Cleaned up an integer-division warning by using floating-point division before converting corridor width radius math back to integer.

### Impact

- Layout scripts now validate cleanly in the editor.
- This prevents follow-on false positives while continuing to develop the dungeon system.

## 9. Validation Performed

### Static validation

The following files were checked with the workspace error tool after changes:

- [scripts/world/dungeon/DungeonGenerator.gd](../../scripts/world/dungeon/DungeonGenerator.gd)
- [scripts/world/dungeon/DungeonLayoutGenerator.gd](../../scripts/world/dungeon/DungeonLayoutGenerator.gd)
- [scripts/world/dungeon/DungeonGraph.gd](../../scripts/world/dungeon/DungeonGraph.gd)
- [scripts/world/dungeon/DungeonTileRenderer.gd](../../scripts/world/dungeon/DungeonTileRenderer.gd)
- [scripts/world/dungeon/DungeonWallManager.gd](../../scripts/world/dungeon/DungeonWallManager.gd)
- [scripts/core/enemy/EnemyManager.gd](../../scripts/core/enemy/EnemyManager.gd)
- [scripts/core/enemy/EnemyDataSelector.gd](../../scripts/core/enemy/EnemyDataSelector.gd)
- [scripts/core/enemy/EnemySpawnLifecycleService.gd](../../scripts/core/enemy/EnemySpawnLifecycleService.gd)
- [scripts/world/dungeon/DungeonFloorThemeProfile.gd](../../scripts/world/dungeon/DungeonFloorThemeProfile.gd)
- [scripts/world/dungeon/DungeonWallThemeProfile.gd](../../scripts/world/dungeon/DungeonWallThemeProfile.gd)
- [scripts/world/dungeon/DungeonLayoutData.gd](../../scripts/world/dungeon/DungeonLayoutData.gd)

All reported no errors at the time of validation.

## 10. Practical Outcome

The dungeon system is still the same architecture, but it is now more flexible in the areas that matter most for future content:

- Corridor width can vary.
- Corridor length can be constrained more strictly.
- Floor tiles can be themed through resources.
- Wall art can be themed through resources.
- Rooms have semantic metadata for role and size.
- Tutorial and boss room flow is driven more by metadata and less by implicit assumptions.

## 11. Notes

- The live generation path still remains rectangle-first and grid-based.
- This work does not rewrite the generator into a connector-grammar system.
- Existing defaults were kept so current content should continue to work unless specific new exports are changed in the inspector.
