# Prefab Scene Audit

This audit records the modular room and corridor scenes reviewed for the prefab-native migration slice. The goal is to normalize scene contracts without changing art layouts.

## Reviewed Scenes

| Scene | Observed Structure | Notes |
|---|---|---|
| `scenes/sala_tutorial.tscn` | `Node2D` root, `TileMapLayer`, root-level `Salida`, root-level `Spawn_jugador`, root-level `Spawn_tutorial` | Tutorial-specific spawn markers are present, but the naming uses legacy lowercase variants instead of the canonical `Spawn_Jugador` / `Spawn_Tutorial` contract. No `Puertas` container was present in the inspected slice. |
| `scenes/sala_1.tscn` | `Node2D` root, `TileMapLayer`, root-level `Entrada`, root-level `Salida` | Uses legacy root-level door markers. No `Puertas` container was present in the inspected slice. |
| `scenes/sala_1_rotada.tscn` | `Node2D` root, `TileMapLayer`, root-level `Entrada`, root-level `Salida` | Manual rotated variant of the same room family. Marker ownership is still root-level rather than container-based. |
| `scenes/sala_2.tscn` | `Node2D` root, `TileMapLayer`, root-level `Entrada`, root-level `Salida` | Uses the same legacy marker naming and root ownership pattern as the other standard rooms. |
| `scenes/sala_2_rotada.tscn` | `Node2D` root, `TileMapLayer`, root-level `Entrada`, root-level `Salida` | Rotated counterpart of `sala_2.tscn`; still uses the same marker naming convention. |
| `scenes/sala_3.tscn` | `Node2D` root, `TileMapLayer`, root-level `Entrada`, root-level `Salida` | Root-level markers only. No dedicated `Puertas` node was present in the reviewed snippet. |
| `scenes/sala_3_rotada.tscn` | `Node2D` root, `TileMapLayer`, root-level `Entrada`, root-level `Salida` | Rotated counterpart of `sala_3.tscn`; same contract mismatch. |
| `scenes/sala_4.tscn` | `Node2D` root, `TileMapLayer`, root-level `Entrada`, root-level `Salida` | Uses the same legacy marker layout as the other standard rooms. |
| `scenes/sala_4_rotada.tscn` | `Node2D` root, `TileMapLayer`, root-level `Entrada`, root-level `Salida` | Rotated counterpart of `sala_4.tscn`; still root-level marker ownership. |
| `scenes/sala_boss.tscn` | `Node2D` root, `TileMapLayer`, root-level `Entrada` in the reviewed excerpt | Boss room should be treated as a special-case prefab. The inspected slice showed asymmetric marker coverage, so this scene should be confirmed before it becomes a strict connector contract input. |
| `scenes/pasillo_1.tscn` | `Node2D` root, `TileMapLayer`, root-level `Entrada`, root-level `Salida` | Corridor prefab is usable as authored, but still lacks the normalized `Puertas` container contract. |
| `scenes/pasillo_2.tscn` | `Node2D` root, `TileMapLayer`, root-level `Entrada`, root-level `Salida` | Same corridor contract as `pasillo_1.tscn`, still using root-level markers. |
| `scenes/pasillo_3.tscn` | `Node2D` root, `TileMapLayer`, root-level `Entrada`, root-level `Salida` | Same corridor contract as the other corridor prefabs. |

## Structural Inconsistencies

- The reviewed scenes expose markers at the root instead of under a `Puertas` node.
- Tutorial-only spawn markers use lowercase legacy names instead of the canonical runtime names.
- The boss room appears to be asymmetric and should be re-verified before connector metadata is treated as final.
- The runtime bridge currently has to accept both canonical and legacy marker names so the migration can stay compatible while scenes are normalized.

## Marker Mismatches

- `Spawn_jugador` should normalize to `Spawn_Jugador`.
- `Spawn_tutorial` should normalize to `Spawn_Tutorial`.
- `Entrada` and `Salida` are acceptable canonical door names, but they should live under `Puertas` in the normalized contract.
- A future enemy-spawn marker should use `SpawnEnemigos` for consistency with the prefab-native path.

## TileMap Assumptions

- Every reviewed modular scene includes a `TileMapLayer` that acts as the authored gameplay footprint.
- The prefab bridge treats used cells as the local geometry source.
- The tutorial scene exposes a `caminable` custom data layer in the reviewed excerpt, while the other scenes are still readable through used-cell fallback when explicit custom data is absent.
- The runtime bridge should continue to prefer tile-based geometry from the authored scene rather than rebuilding room rectangles procedurally.

## Normalized Naming Conventions

- Room prefabs should keep canonical marker names: `Entrada`, `Salida`, `Spawn_Jugador`, `Spawn_Tutorial`, `SpawnEnemigos`.
- Marker ownership should move under `Puertas`.
- Spawn markers should be grouped separately from door connectors once the scene contract is normalized.
- Rotated room variants should remain explicit authored scenes until the runtime can rotate connector metadata safely.

## Audit Outcome

- The current scene set is suitable for a prefab-native bridge.
- The current scene set is not yet normalized to the final modular contract.
- The next safe step is to keep using the authored scenes directly while introducing the `Puertas` hierarchy and canonical marker names incrementally.