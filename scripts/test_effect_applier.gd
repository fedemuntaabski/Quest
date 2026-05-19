extends Node

func _ready() -> void:
    # Setup minimal owners and stats
    var source_owner := Node.new()
    var target_owner := Node.new()

    var source_stats := CharacterStats.new()
    source_stats.strength = 5
    source_owner.add_child(source_stats)

    var target_stats := CharacterStats.new()
    target_stats.strength = 1
    target_owner.add_child(target_stats)

    # Ensure stacks exist for the target so BuffEffect will use them
    target_stats._ensure_stacks()

    # Create a BuffEffect and CardData
    var buff := BuffEffect.new()
    buff.stat_key = "strength"
    buff.value = 2
    buff.duration_turns = 2

    var card := CardData.new()
    card.effects = [buff]

    # Resolve the card
    var summary := CardResolver.resolve_card(card, source_stats, target_stats)

    # Create a fake CombatComponent for the target
    var target_comp := CombatComponent.new()
    target_comp.setup(target_owner, target_stats, null)

    # EffectContext: owner = source_owner
    var ctx := EffectContext.new(source_owner, null, null, target_comp)

    var applier := EffectApplier.new()
    # Apply effects (no movement expected; status => buff)
    await applier.apply(summary, target_comp, ctx)

    # Tick turns to expire modifiers
    target_stats.process_runtime_modifiers_turn_start()
    target_stats.process_runtime_modifiers_turn_start()
