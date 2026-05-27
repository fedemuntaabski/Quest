# Migration Plan

## Goal
Move from the current rectangle-and-grid dungeon assembly toward a modular grammar-based architecture without breaking the current gameplay loop.

This plan assumes the current live path remains stable during migration and that the rewrite is done in layers rather than as a big-bang replacement.

## Preserve

These systems should be preserved or adapted rather than thrown away:
- `DungeonLayoutGenerator` as the topology compiler
- `DungeonGraph` as the connection graph
- `DungeonLayoutData` as the handoff contract, after tightening it
- `OccupancyManager` as the canonical occupancy store
- `MapNavigationHelper` as the grid/pathfinding abstraction
- `RoomSystem` as the authority for active-room switching
- `EnemySpawnLifecycleService` and `EnemyDataSelector` for enemy spawn lifecycle
- `DungeonWallManager` for floor-to-wall derivation
- `MapManagerCore` concepts that are genuinely reusable, especially path and occupancy helpers

## Replace

These surfaces should eventually be replaced or retired:
- runtime creation of generic room/corridor placeholders in `DungeonRoomFactory`
- compatibility merging of runtime/presentation fields back into `room_infos`
- the duplicate runtime setup boundary in `DungeonRuntimeSetup` and `DungeonGenerator`
- `DungeonMapRenderer` as a stub base if it remains only as a wrapper around `DungeonTileRenderer`
- parallel/legacy scene assets that are not wired into the live generation path

## Recommended Safe Refactor Order

### Phase 1: Stabilize the contract
1. Freeze the existing layout contract.
2. Separate pure layout data from runtime and presentation data.
3. Make `DungeonLayoutData` explicit about what the compiler produces.
4. Stop adding new fields to `room_infos` that belong to runtime objects.

Why this comes first:
- The modular grammar layer will need a stable compile-time model.
- Any ambiguity here will leak into every later step.

### Phase 2: Introduce a room prefab adapter
1. Add a dedicated adapter layer that can instantiate authored room scenes.
2. Keep the old generic room-node builder behind the adapter initially.
3. Confirm how room metadata, room bounds, and spawn markers map into the adapter.

Why this comes second:
- It lets the new architecture coexist with the current runtime while prefabs are being validated.

### Phase 3: Add explicit connector semantics
1. Model connector slots or door sockets in layout metadata.
2. Map connector slots to scene markers.
3. Make rotations explicit in the compiled layout.

Why this comes third:
- Connector semantics are the core gap between the current system and a grammar-based system.

### Phase 4: Move corridors to the same grammar boundary
1. Decide whether corridors are prefab instances, synthesized tiles, or hybrid entities.
2. Make corridor endpoints attach to connector metadata instead of room centers.
3. Remove assumptions that corridor direction is only horizontal-first or vertical-first.

### Phase 5: Deprecate legacy surfaces
1. Remove or quarantine unused room and corridor scenes that are not part of the new contract.
2. Remove duplicate bootstrap code once the new instancing path is authoritative.
3. Collapse `DungeonMapRenderer` if it is not needed as an abstraction.

## What Should Be Preserved in Behavior

- Current grid size, tile size, and world-to-grid conversion semantics.
- Current active-room connectivity enforcement.
- Current occupancy/versioning behavior.
- Current enemy spawn lifecycle ordering.
- Current turn manager setup and dungeon startup flow.
- Current boss/tutorial difficulty and selection logic unless the redesign explicitly changes it.

## What Should Change

- Rooms should become authored modular prefabs, not generic `Node2D` placeholders.
- Room rotation should be a compiler/runtime concern, not a manually duplicated asset concern.
- Doors/connectors should be first-class metadata, not inferred from area overlap.
- Spawn points should come from room metadata and scene markers, not only from random floor-cell selection.
- Layout generation should produce a clean compile-time artifact that is independent from runtime node references.

## Risk Assessment

### High risk
- Replacing room instancing and connector semantics.
- Changing the layout/runtime contract for room metadata.
- Replacing scene assets that may be referenced by editor workflows or unpublished content.

### Medium risk
- Refactoring `DungeonRuntimeSetup` and `DungeonGenerator` bootstrap ownership.
- Removing compatibility shims around `room_infos`.
- Tightening spawn marker usage.

### Low risk
- Improving documentation and adding explicit contracts.
- Adding tests around current graph validation and occupancy rules.

## Deprecation Order

1. Mark legacy room/corridor scenes as non-authoritative.
2. Move presentation responsibilities behind the new room prefab adapter.
3. Remove compatibility merges from public room accessors.
4. Decommission duplicate bootstrap code.
5. Retire legacy scene roots once the new generator is stable.

## Success Criteria

The migration can be considered stable when:
- a generated dungeon can be fully assembled from prefab/grammar data without relying on generic placeholder room nodes
- connectors and rotations are reproducible and explicit
- room metadata remains immutable after compile-time handoff
- occupancy and navigation continue to work without regression
- boss/tutorial behavior remains functionally equivalent or intentionally improved

## Practical Advice

Do not attempt to replace everything at once. The safest order is:
1. stabilize data contracts
2. add prefab instancing behind an adapter
3. wire connectors and rotation
4. switch the live path
5. remove legacy surfaces