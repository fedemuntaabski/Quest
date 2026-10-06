extends Resource
class_name ChestTier

## ChestTier (progresion-10): a kind of chest (Madera/Hierro/Oro) and the rarity
## odds of what it holds. `rarity_weights[i]` = weight of ItemData.Rarity i.

@export var display_name: String = "Madera"
## Modulate of the chest sprite.
@export var tint: Color = Color.WHITE
@export var rarity_weights: PackedFloat32Array = PackedFloat32Array([50, 30, 14, 5, 1])
