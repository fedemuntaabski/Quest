# Connector Architecture Report

## Current Compatibility Status

The dungeon system is now prepared for connector metadata, but the live generator still behaves exactly as before: rooms are placed procedurally from rectangles, and corridors are carved between room centers. The new work only enriches the layout contract with connector and room-local geometry metadata.

The current state is additive and compatible. Existing consumers can keep using `rect`, `center_cell`, `floor_cells`, and corridor connection data, while future systems can start reading `connectors` and `local_floor_cells` from room layout records.

## What Still Assumes Rectangle-Only Rooms

Several runtime paths still treat `Rect2i` as the authoritative room shape:

- room activation and occupancy checks in `scripts/world/rooms/room_system.gd`
- room gating, pathing, and actor-room resolution in `scripts/world/rooms/MapManagerCore.gd`
- the public compatibility wrapper in `scripts/world/rooms/MapManager.gd`
- room framing in `scripts/world/rooms/room_camera_controller.gd`
- camera sizing helpers in `scripts/world/camera/CameraMode_Room.gd` and `scripts/world/camera/CameraMode_Corridor.gd`
- corridor endpoint selection in `scripts/world/dungeon/DungeonLayoutGenerator.gd`
- player placement in `scripts/world/dungeon/DungeonGenerator.gd`

Fog of war is already closer to the future model because it uses `floor_cells`, but it still consumes room info through the existing layout dictionaries.

## Reusable Scenes

These authored scenes already have the right shape for metadata attachment and can be reused as-is once a template registry exists:

- `scenes/sala_1.tscn`
- `scenes/sala_1_rotada.tscn`
- `scenes/sala_2.tscn`
- `scenes/sala_2_rotada.tscn`
- `scenes/sala_3.tscn`
- `scenes/sala_3_rotada.tscn`
- `scenes/sala_4.tscn`
- `scenes/sala_4_rotada.tscn`
- `scenes/pasillo_1.tscn`
- `scenes/pasillo_2.tscn`
- `scenes/pasillo_3.tscn`

They already expose `Entrada` and `Salida` markers, so connector inference can work without forcing a scene rewrite.

## Legacy Candidates

These scenes are still reusable, but they are more likely to need explicit template metadata sooner because they are not purely standard door pairs:

- `scenes/sala_tutorial.tscn` because it includes spawn markers in addition to a connector marker and is clearly special-purpose
- `scenes/sala_boss.tscn` because it currently appears asymmetric in marker coverage and is likely to need explicit boss-room template data rather than inference alone

## Risks For Future Prefab Migration

The biggest risks are not in generation itself; they are in the assumptions baked into downstream room consumers.

- Connector inference from existing markers depends on consistent authoring conventions, especially marker rotation and naming.
- Future prefab placement will need a clear rule for local-vs-world coordinates, or rotated rooms will drift out of alignment.
- `Rect2i` is still used as the practical room bounds helper, so any prefab migration has to preserve those compatibility hooks until pathing, visibility, and room locking are connector-aware.
- Corridor carving still starts from room centers. That is acceptable for now, but true prefab rooms will eventually need connector-to-connector corridor routing.
- The tutorial and boss scenes already carry special semantics that should be represented explicitly in template metadata rather than inferred forever.

## Notes On The New Metadata Layer

- `RoomConnectorData` defines connector direction, type, occupancy, and connection metadata in room-local space.
- `RoomTemplateData` is the future prefab-facing room contract: scene reference, tags, connectors, rotation rules, spawn profile, weights, and depth constraints.
- Room-local floor cells are now stored alongside world-grid floor cells so geometry can eventually come from authored prefabs instead of rectangles.
- `Puertas/Marker2D` is the intended future marker hierarchy, but existing authored rooms are still readable through the current `Entrada` and `Salida` markers.

## Next Migration Step

The next safe step is to add a template registry or authored-room resource pass that maps existing `sala_*` and `pasillo_*` scenes to `RoomTemplateData` assets, while leaving corridor carving and procedural room placement untouched.