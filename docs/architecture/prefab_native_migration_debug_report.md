# Prefab Native Migration Debug Report

## Summary

This slice stabilizes the prefab-native dungeon runtime by removing the duplicate room-visual instancing path and tightening marker-based spawn resolution.

## Duplicate Room Instancing Fix

- `DungeonAssembler` remains the authoritative prefab instancer for the hard-coded tutorial -> corridor -> room chain.
- `DungeonRoomFactory.create_room_nodes()` now reuses an existing `visual_root` when one is already present in `room_info` instead of creating a second prefab instance.
- `ModularRoomAssembler.build_room_instance()` now also reuses an existing `visual_root` defensively, so direct calls cannot accidentally duplicate the tutorial room.
- Legacy placeholder room visuals remain only as an emergency fallback when prefab instancing genuinely fails.

## Tutorial Spawn Authority

- `DungeonGenerator.place_player_in_start_room()` now resolves the spawn point from the tutorial room marker first and then synchronizes movement/grid state immediately after placement.
- `DungeonGenerator.get_room_marker_ref()` now falls back to compatibility marker data in `room_infos` if presentation state is not available yet.
- Tutorial enemy spawning remains marker-authoritative through `Spawn_Tutorial`, with a compatibility fallback to `room_info.marker_refs` before any non-authoritative fallback can occur.

## Disabled or Reduced Presentation Paths

- Procedural tile painting remains disabled.
- Procedural wall derivation remains disabled.
- Legacy rectangle-first room visuals are no longer the active visual path for rooms that already have prefab roots.
- The presentation layer still creates room light and detector helpers, but not duplicate room prefabs for the tutorial slice.

## Remaining Legacy Procedural Systems

- `DungeonLayoutGenerator` still exists as a compatibility layout source.
- `room_infos`, `floor_cells`, and `dungeon_graph` still act as runtime bridges for downstream systems.
- `DungeonRoomFactory` still exposes a legacy placeholder fallback for recovery scenarios.
- Rectangle bounds are still used by room activation, camera framing, and some occupancy compatibility helpers.

## Corridor Alignment Notes

- The assembled hard-coded chain still uses authored marker alignment between `sala_tutorial.tscn`, `pasillo_1.tscn`, and `sala_1.tscn`.
- Debug logs were added to print room and corridor names, resolved marker names, and final world positions during assembly.
- Corridor overlap remains the main thing to verify in a live run, but the duplicate tutorial-room instancing path is now removed from the presentation bridge.

## Verification Status

- GDScript diagnostics passed for the touched runtime files in this slice.
- The next live validation step is a run of the start scene to confirm a single tutorial room root, a single corridor root, and marker-based player/tutorial-enemy placement.