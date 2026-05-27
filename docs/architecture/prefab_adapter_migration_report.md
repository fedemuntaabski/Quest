# Prefab Adapter Migration Report

## Summary

This phase adds the first safe bridge between authored room scenes and the live procedural dungeon without replacing the current generator.

The bridge is additive only:
- the live dungeon still generates rectangle rooms
- room activation, occupancy, navigation, enemy spawning, and turn setup still use the existing runtime path
- authored room scenes can now be inspected and instantiated safely through a cached adapter layer when future content chooses to use it

## What Is Prefab-Ready Now

### Scene contract and metadata

The following systems now expose prefab-facing metadata or helpers that are safe for later modular room work:
- `RoomTemplateData` defines a scene-based room contract with connectors, rotation flags, spawn profile, and room-local floor cells
- `RoomConnectorData` already models connector identity, direction, occupancy, and local-space placement
- `RoomConnectorAdapter` can infer connector metadata from authored `Marker2D` nodes and from the legacy `Entrada` / `Salida` naming convention
- `RoomPrefabAdapter` can instantiate a `PackedScene` safely, cache inspection results, and extract connector, spawn marker, bounds, and floor-cell metadata once per scene resource
- `DungeonRoomLayoutState` now exposes room-local and world-space helper methods so layout data can be consumed in future prefab-placement code without mutating runtime state

### Layout contract

The generated room layout now carries prefab-friendly shape data in addition to the legacy rectangle contract:
- `local_bounds`
- `local_floor_cells`
- `connectors`
- `spawn_markers` placeholder data

This keeps the layout compiler authoritative while giving future prefab consumers a stable room-local geometry shape.

### Presentation bridge

`DungeonRoomFactory` still creates the current generic runtime room nodes, lights, and detector areas, but it now attaches prefab-ready metadata to the room root so future adapters can inspect the contract without re-deriving it.

## What Is Still Procedural-Only

The following systems remain bound to the current rectangle-based dungeon path:
- `DungeonGenerator` still owns the live generation flow
- `DungeonLayoutGenerator` still creates room rectangles and corridor cell paths
- `DungeonRoomFactory` still creates generic runtime placeholders instead of instanced authored room prefabs
- `DungeonPresentationManager` still builds the current map/fog presentation over the procedural layout
- `RoomSystem` still activates rooms using room rectangles and overlap-based detector areas
- `RoomCameraController` still decides room/corridor behavior from room rectangles
- enemy spawning still uses room floor cells and current occupancy rules
- navigation helpers still reason about `Rect2i` room bounds and floor-cell occupancy

## Assumptions That Still Block Full Migration

The following assumptions remain in the live path and must stay in place for this phase:
- room generation is rectangle-first rather than connector-first
- corridor carving still starts from room centers rather than connector sockets
- room activation still depends on `Rect2i` room bounds
- spawn selection still uses floor cells instead of room spawn markers
- the live runtime does not instantiate authored room scenes as the primary room representation
- room rotation is metadata-ready, but the live generator does not place rotated prefabs yet

These assumptions are intentional compatibility layers. Removing them now would risk occupancy, navigation, combat, enemy lifecycle behavior, and room activation.

## Authored Scene Inventory Notes

The current authored assets are useful input for the adapter, but they are not yet a live prefab grammar:
- `scenes/sala_*` and `scenes/pasillo_*` already expose `Entrada` and `Salida` markers
- `scenes/sala_*_rotada.tscn` demonstrates manual rotated variants, which is useful evidence for future rotation support
- `scenes/sala_tutorial.tscn` includes special spawn markers such as `Spawn_jugador` and `Spawn_tutorial`

The important gap is that the live runtime still ignores those markers and continues to use generic room areas and floor-cell selection.

## How To Proceed Toward A Connector-Based Generator

The next migration phase should do three things in order:
1. introduce a room template registry that maps dungeon room types to authored `PackedScene` resources
2. let the layout compiler choose templates and rotation metadata before corridor attachment is finalized
3. update corridor routing to target connector sockets instead of room centers

Once those steps are in place, prefab instancing can move behind the adapter as the default room assembly path while the legacy placeholder path remains available as a fallback.

## Notes On Safety And Caching

`RoomPrefabAdapter` is intentionally cached so scene inspection is not repeated every frame. The adapter inspects a scene once, stores the extracted contract, and returns duplicated data on later reads.

That caching policy is important because it keeps scene inspection read-only and avoids adding hidden runtime costs to the current dungeon flow.

## Recommended Follow-Up

- keep the current procedural generator as the default path until connector routing and rotation placement are validated end to end
- add prefab templates gradually, one room family at a time, so the adapter can be validated against real authored scenes without destabilizing the live dungeon
- only remove rectangle-based compatibility helpers after room activation, occupancy, navigation, and spawning have been explicitly rewritten around connector metadata