# Visuales de entidades

Estado **antes** de `session/assets-3` (referencia; abajo, qué cambia).

| Entidad | Nodo visual | Colisiones |
|---|---|---|
| Héroe (`scenes/entities/Player.tscn`, `Player.gd`) | `AnimatedSprite2D`; `CharacterData.sprite_frames` (un `resources/sprite_frames/hero_*.tres` por héroe) lo rellena en `_apply_character_visuals`. Solo animación `idle`; `sprite_offset` (PartyConfig.sprite_spacing 28) separa héroes en la misma zona. | `Hurtbox` círculo r=20 (layer 4); `Hitbox` r=160 = área de ataque, independiente del sprite. |
| Enemigo (`scenes/entities/Enemy.tscn`, `Enemy.gd`) | `Polygon2D "Icon"` (triángulo) coloreado por `Enemy.TYPE_COLORS`. | Body r=14 (layer 2, detección de torretas), `Hurtbox` r=14 (layer 8), `Hitbox` de contacto r=24. |
| Nexo (`scenes/world/Nexo.tscn`) | `Polygon2D` rombo violeta. | `Area2D` r=18 (clic). |
| Retrato HUD (`HeroPortrait._make_icon`) | `CharacterData.portrait` (PNG de menús) o círculo con inicial. | — |
| Popup de héroe (`CharacterPopup._preview_texture`) | Frame idle de `sprite_frames` (Nearest) > portrait. | — |

## Enemigos y pisos
`Enemy.Variant` {SWARM, SAPPER, HUNTER} define **comportamiento** (`VARIANT_CONFIG`: hp/velocidad/intervalo IA/daño de contacto). `EnemyManager._roll_variant()` lo elegía con pesos fijos 60/25/15; no había pool por piso. `FloorConfig` escalaba solo HP y daño por piso (`enemy_hp_growth`, `enemy_damage_growth`).

## Feedback de daño
`HitboxComponent.hit_landed` → `FloatingTextManager.spawn_text` (números). El héroe recibe daño por `Hurtbox.hurt` → `CharacterStats.take_damage` → `hp_changed` (HUD flash en `HeroPortrait`). Ni héroe ni enemigo tenían feedback visual propio.

## Cambio en session/assets-3
`CharacterVisual` (`AnimatedSprite2D`) da a héroes y enemigos animación por estado (idle/run/hit), flip por dirección, parpadeo blanco al daño e idle procedural para sprites estáticos; hurtbox/body se ajustan al tamaño del sprite × `ART_SCALE`. Los enemigos salen de un `EnemyPool` por piso (`FloorConfig.enemy_pools`, recursos `EnemyType`). `Pickup.tscn` reemplaza el rombo del Nexo. Asset por uso: `docs/ASSETS.md`.
