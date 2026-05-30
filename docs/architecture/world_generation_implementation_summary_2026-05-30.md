# World Generation Implementation Summary

Date: 2026-05-30

This document records the implementation work completed in this chat for the dungeon/world generation pipeline and adjacent enemy-flow helpers. The goal was to extend the current architecture without breaking gameplay, keep the grid-based layout model intact, and add a resource-driven foundation for future dungeon content.

## Summary of What Was Implemented

The work completed in this chat focused on four main areas:

1. Corridor generation was made configurable and backward compatible.
2. Room generation was extended with a room-template resource layer.
3. Room size selection moved earlier in the generation flow so room intent can be chosen before carving.
4. Tutorial and boss routing were made more metadata-driven in the enemy spawn path.

The existing floor, wall, navigation, occupancy, and pathfinding systems were intentionally preserved. The layout still produces a grid of floor cells, and downstream systems continue to derive behavior from those floor and wall cells rather than from a new geometry model.

## 1. Corridor Improvements

### What changed

The corridor pipeline was updated so corridor thickness and maximum corridor distance can be tuned from the inspector.

### Code changes

- `DungeonGenerator` now exposes `corridor_width` with a default of `3`.
- `DungeonGenerator` now exposes `corridor_max_length` with a default of `5`.
- `DungeonGenerator` keeps `enforce_corridor_max_length` as the opt-in switch that turns the length cap into a hard constraint.
- `DungeonLayoutGenerator._carve_corridor()` still performs the actual corridor stamping, but now uses the generator’s width setting and rolls back if strict max-length enforcement fails.
- Corridor stamping still writes to the same `floor_cells` / `corridor_cells` dictionaries, so the rest of the pipeline does not need special corridor-aware logic.

### Why this approach

The corridor logic was kept inside the layout generator because that is the layer that already owns pure layout mutation. That preserves the separation between generation and presentation and avoids spreading corridor concerns into renderer, enemy, or occupancy code.

### Backward compatibility

- The strict max-length behavior is still disabled by default.
- If `enforce_corridor_max_length` stays off, the pipeline preserves the legacy warning-style behavior.
- The grid model and connectivity model remain unchanged.

## 2. Room Template System

### What changed

A new resource-backed room-template layer was introduced to make room selection explicit and extensible.

### New files added

- `scripts/world/dungeon/DungeonRoomTemplateProfile.gd`
- `scripts/world/dungeon/DungeonRoomTemplateCatalog.gd`
- `resources/dungeon/room_templates/tutorial_room_template.tres`
- `resources/dungeon/room_templates/small_room_template.tres`
- `resources/dungeon/room_templates/medium_room_template.tres`
- `resources/dungeon/room_templates/large_room_template.tres`
- `resources/dungeon/room_templates/boss_room_template.tres`
- `resources/dungeon/room_templates/default_room_template_catalog.tres`

### Template model

Each `DungeonRoomTemplateProfile` carries:

- `template_id`
- `room_role`
- `size_category`
- `min_size`
- `max_size`
- `tags`

The catalog resource provides a lookup layer that can choose a profile by room role, room size category, or special progression stage.

### Why this approach

This keeps room intent in data instead of hardcoding it into generation branches. That makes it easier to add future room types, custom biome room sets, or special encounter rooms without editing the generation algorithm itself.

### Backward compatibility

- The template catalog is optional.
- If no catalog is assigned, the generator falls back to the current legacy room-template behavior.
- The existing `DungeonGraph` room template constants remain in place, so older content and existing metadata consumers still understand the same string values.

## 3. Room Size Driven Generation

### What changed

Room size is now selected before the room rectangle is carved, rather than only being classified afterward.

### Code changes

- `DungeonGenerator` now exposes configurable selection chances for small, medium, and large rooms.
- `DungeonGenerator` now exposes configurable min/max size ranges for:
  - small rooms
  - medium rooms
  - large rooms
- `DungeonLayoutGenerator.generate()` now asks the generator for a room generation plan before rolling the room rectangle.
- The layout generator uses that plan to decide which size range to roll from.
- The room’s resulting `size_category` is still stored in room metadata for compatibility.

### Why this approach

The old flow classified room size after placement. That works for reporting, but it does not let designers intentionally bias content by room size. Moving the decision earlier keeps the generation logic flexible while still leaving the final room rectangle carving inside the same layout system.

### Backward compatibility

- If the catalog is not assigned, the layout generator still falls back to the legacy room size roll.
- Existing systems that read `size_category` still get a value.
- No runtime systems were forced to depend on the new template catalog.

## 4. Dungeon Progression Flow

### What changed

The progression path now treats tutorial and boss rooms as metadata-driven special cases.

### Code changes

- Room `0` resolves to the tutorial template when tutorial rooms are enabled.
- The final room resolves to the boss template when boss rooms are enabled.
- A room with `room_role = "boss"` is treated as the boss destination, even if future layouts change room numbering or ordering.
- `EnemySpawnLifecycleService._compute_final_room_id()` now prefers explicit boss metadata over a highest-id assumption.

### Why this approach

The old room ordering conventions were brittle. By using room metadata, the dungeon can later reorder or expand content without forcing every downstream consumer to infer meaning from room ids.

### Backward compatibility

- The legacy room-id fallback remains available.
- The tutorial room still resolves to room `0` in the current default path.
- The boss room still resolves to the final room in the current default path.

## 5. Enemy Selection Updates

### What changed

Enemy selection now consumes room template and room role metadata.

### Code changes

- `EnemyDataSelector.select_enemy_data_with_template()` now accepts both `room_template` and `room_role`.
- Tutorial rooms resolve to tutorial enemy data when either template or role metadata indicates a tutorial room.
- Boss rooms resolve to boss enemy data when either template or role metadata indicates a boss room.
- `EnemyManager.get_enemy_scene_for_room()` now accepts room role metadata as well as the template string.
- `EnemySpawnLifecycleService` passes both template and role metadata to enemy selection.

### Why this approach

This keeps the enemy-flow layer aligned with the new room-template architecture. It also reduces reliance on room ids, which makes future layout changes safer.

### Backward compatibility

- Existing room-id based fallback logic remains in the selector.
- Existing enemy resources and scenes continue to work.
- No changes were required to the enemy resource format.

## 6. Room Metadata and Graph Compatibility

### What changed

The room metadata surface was kept intact and extended with the new template layer.

### Code changes

- `DungeonGraph` now defines explicit constants for tutorial, small, medium, large, boss, and normal room semantics.
- `DungeonGraph._build_room_record()` now uses stable defaults for room role and size category.
- `DungeonGenerator` continues to provide compatibility getters:
  - `get_room_template(room_id)`
  - `get_room_role(room_id)`
  - `get_room_size_category(room_id)`

### Why this approach

The project already had a merged room-info shape in runtime. Instead of replacing it, the work preserved those dictionaries and extended them so existing consumers remain functional while new systems can use the richer metadata.

## 7. Floor and Wall Theme Extensibility

### Status

No architectural rewrite was needed here because the existing floor and wall theme layers were already resource-backed and designed for fallback compatibility.

### Existing surfaces preserved

- `DungeonFloorThemeProfile`
- `DungeonWallThemeProfile`
- `DungeonGenerator.get_floor_tile_profile()`
- `DungeonGenerator.get_wall_theme_profile()`
- `DungeonTileRenderer`
- `DungeonWallManager`

### Outcome

The current themed tile pipeline remains resource-driven, and the work preserved the ability to swap visuals without changing generation logic.

## 8. Validation Performed

### Static validation

The following files were checked with the workspace error tool after the implementation changes:

- `scripts/world/dungeon/DungeonGenerator.gd`
- `scripts/world/dungeon/DungeonLayoutGenerator.gd`
- `scripts/world/dungeon/DungeonGraph.gd`
- `scripts/world/dungeon/DungeonRoomTemplateProfile.gd`
- `scripts/world/dungeon/DungeonRoomTemplateCatalog.gd`
- `scripts/core/enemy/EnemyDataSelector.gd`
- `scripts/core/enemy/EnemyManager.gd`
- `scripts/core/enemy/EnemySpawnLifecycleService.gd`

### Result

All reported no errors at the time of validation.

### Note on runtime validation

A live in-engine dungeon-generation smoke test was not run during this chat. The changes were validated statically instead.

## 9. Compatibility Notes

- The layout system remains rectangle-first and grid-based.
- The graph still stores room connectivity and corridor edges in the same broad shape.
- The renderer still consumes the same floor and wall cell dictionaries.
- Occupancy and pathfinding continue to rely on the generated walkable grid.
- The new room-template catalog is optional and does not need to be assigned for the game to function.

## 10. Practical Result

The dungeon system now has a more scalable foundation for future content:

- Corridor width can be increased without redesigning the pipeline.
- Corridor length can be made a hard constraint when desired.
- Room size can be selected intentionally before placement.
- Tutorial and boss progression is now metadata-driven.
- Future room categories can be added through resources instead of hardcoded branching.
- Existing gameplay remains compatible with the current fallback behavior.

## 11. Files Most Directly Involved

- `scripts/world/dungeon/DungeonGenerator.gd`
- `scripts/world/dungeon/DungeonLayoutGenerator.gd`
- `scripts/world/dungeon/DungeonGraph.gd`
- `scripts/world/dungeon/DungeonRoomTemplateProfile.gd`
- `scripts/world/dungeon/DungeonRoomTemplateCatalog.gd`
- `scripts/core/enemy/EnemyManager.gd`
- `scripts/core/enemy/EnemyDataSelector.gd`
- `scripts/core/enemy/EnemySpawnLifecycleService.gd`
- `resources/dungeon/room_templates/default_room_template_catalog.tres`

## 12. Notes For Future Work

- The catalog can be expanded with biome-specific or encounter-specific templates without changing the layout algorithm.
- If desired later, the template catalog can be wired into scene setup so a default catalog is assigned automatically in the live map path.
- Future work can add per-template content hooks, such as encounter tables, prop placement rules, or boss-specific room decorations, without breaking the current generation contract.