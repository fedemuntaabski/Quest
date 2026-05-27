# Code Cleanup Report

## Scope
This report collects dead code candidates, duplicate responsibilities, obsolete surfaces, and simplification opportunities in the current world-generation stack.

## Confirmed or Strong Legacy Candidates

### `DungeonMapRenderer.gd`
This file is a stub base class with empty methods. The actual rendering behavior lives in `DungeonTileRenderer.gd`.

Cleanup action:
- either keep it only as a minimal abstract interface
- or remove it if no other renderer implementations are planned

### `DungeonWorld.tscn`
This scene appears to be a parallel or legacy dungeon scene path, not the live gameplay entry.

Cleanup action:
- quarantine it as legacy if it is still needed for reference
- otherwise retire it after validating editor workflows and asset references

### Authored `sala_*.tscn` and `pasillo_*.tscn` assets
The room and corridor template scenes are not part of the live instancing path. The live generator builds generic runtime nodes instead.

Cleanup action:
- decide whether they are:
  - legacy art references
  - future modular prefabs
  - or dead assets that can be removed

## Duplicate Responsibilities

### Bootstrap duplication
`DungeonGenerator` and `DungeonRuntimeSetup` both ensure runtime helpers and scene roots exist.

Why it is redundant:
- both paths create or connect the same manager-like objects
- both are responsible for scene-root preparation

Cleanup action:
- choose one authoritative bootstrap boundary
- reduce the other layer to thin delegation only

### Map manager facade overlap
`MapManager.gd` and `MapManagerCore.gd` overlap as a scene-level manager and helper facade.

Why it is redundant:
- many methods are thin wrappers
- the helper already contains the real logic for occupancy and room queries

Cleanup action:
- keep one narrow facade and one real implementation layer
- delete pure pass-through methods that add no value

### Runtime/presentation merging
`DungeonGenerator.get_room_info()` and `get_room_infos_with_runtime()` merge procedural and runtime state into one dictionary surface.

Why it is redundant:
- the layout model already exists separately
- runtime/presentation should be stored in dedicated stores

Cleanup action:
- expose a clean layout contract and a separate runtime view model

## Unused or Low-Value Fields / Methods

### `DungeonGenerator.tile_renderer`
This field appears unused in the inspected slice.

Cleanup action:
- remove it if no external caller uses it
- otherwise wire it intentionally and document the ownership

### `DungeonGenerator._ensure_scene_roots()` / `_ensure_node()` / `_ensure_tile_map_layer()`
These are thin wrappers around `DungeonSceneHelper`.

Cleanup action:
- keep only the helper entry points that are actually needed
- remove wrappers if they only mirror the helper one-to-one

### `DungeonGraph.set_edge_runtime_node()`
This stores runtime node references on the graph model.

Why it is problematic:
- it blurs topology with runtime presentation

Cleanup action:
- move runtime node ownership to presentation state
- keep `DungeonGraph` topology-only if possible

### `DungeonRoomManager` and `RoomSystem` duality
`RoomSystem` is the authoritative active-room writer, while `DungeonRoomManager` still handles presentation updates.

Cleanup action:
- keep the split only if the ownership boundary is explicit
- otherwise collapse the responsibilities into a clearer state/presentation split

## Obsolete Orphan Surfaces

### Scene assets not used by live generation
The inspected live path does not instantiate the authored room/corridor scenes.

Candidates:
- `scenes/sala_1.tscn`
- `scenes/sala_1_rotada.tscn`
- `scenes/sala_2.tscn`
- `scenes/sala_2_rotada.tscn`
- `scenes/sala_3.tscn`
- `scenes/sala_3_rotada.tscn`
- `scenes/sala_4.tscn`
- `scenes/sala_4_rotada.tscn`
- `scenes/sala_boss.tscn`
- `scenes/sala_tutorial.tscn`
- `scenes/pasillo_1.tscn`
- `scenes/pasillo_2.tscn`
- `scenes/pasillo_3.tscn`

Cleanup action:
- keep only the assets that are still part of the intended modular roadmap
- archive or remove the rest after validation

## Simplification Opportunities

### Make layout data immutable by convention
`DungeonLayoutData` already exists as a handoff object. Tighten it so it carries only pure compile-time information.

Benefit:
- less accidental runtime coupling

### Reduce linear scans where they are repeated often
Potential hot paths observed in the workspace:
- `MapManagerCore.get_room_id_for_cell()` scans all rooms
- `RoomCameraController._is_player_in_corridor()` scans all rooms every frame

Benefit:
- fewer repeated rectangle scans at runtime

### Standardize spawn and room markers
The authored scenes use `Entrada`, `Salida`, and special tutorial spawn markers, but no common connector contract.

Benefit:
- simpler adapter logic later

### Remove legacy compatibility merges
The merged runtime/presentation room accessors are useful for backward compatibility, but they keep the model blurry.

Benefit:
- cleaner compiler/runtime separation

## Dead Code Confidence Notes

The following items are high-confidence cleanup candidates based on the inspected workspace slice:
- `DungeonMapRenderer.gd` as a stub abstraction
- `DungeonWorld.tscn` as a parallel/legacy scene path
- authored room/corridor scenes as non-authoritative content in the current live path

The following items are only medium-confidence and should be validated before deletion:
- `DungeonGenerator.tile_renderer`
- pure pass-through wrappers in `DungeonGenerator`
- any duplicate manager/helper methods in `MapManager` and `MapManagerCore`

## Recommended Cleanup Sequence

1. Remove or quarantine the stub renderer abstraction.
2. Choose one bootstrap authority and eliminate duplicate setup paths.
3. Separate layout state from runtime/presentation state.
4. Decide whether authored room/corridor scenes are future assets or legacy-only.
5. Remove pass-through wrappers that add no behavior.

## Bottom Line
The most valuable cleanup is not broad deletion. It is reducing the number of places where the same concept is represented twice:
- room layout vs runtime room state
- bootstrap vs helper bootstrap
- topology vs runtime node references
- authored room assets vs generic runtime placeholders