extends Node

func _ready() -> void:
    print("Running EffectApplier integration test...")

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
    print("Resolved summary:", summary)

    # Create a fake CombatComponent for the target
    var target_comp := CombatComponent.new()
    target_comp.setup(target_owner, target_stats, null)

    # EffectContext: owner = source_owner
    var ctx := EffectContext.new(source_owner, null, null, target_comp)

    var applier := EffectApplier.new()
    # Apply effects (no movement expected; status => buff)
    applier.apply(summary, target_comp, ctx)

    # Check resulting modifier on ModifierStack
    var rt_total := target_stats.get_total_strength()
    print("Target total strength after apply:", rt_total)

    # Tick turns to expire modifiers
    var res := target_stats.process_runtime_modifiers_turn_start()
    print("After tick, expired:", res)

    # Second tick should expire buff
    var res2 := target_stats.process_runtime_modifiers_turn_start()
    print("After second tick, expired:", res2)

    print("Test complete.")
