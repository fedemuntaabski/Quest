extends Node
class_name TileHighlighterCache

# Cache logic for TileHighlighter: computes and stores range cells for the active card

func update_range_cache(highlighter: TileHighlighter) -> void:
    if highlighter._player == null or highlighter._card_manager == null:
        return

    var card = highlighter._card_manager.get_active_card()

    if card == highlighter._last_active_card:
        return

    highlighter._last_active_card = card
    highlighter._cached_range_cells.clear()

    if card == null:
        highlighter.queue_redraw()
        return

    if card.target_type != "enemy":
        highlighter.queue_redraw()
        return

    if card.range <= 0:
        highlighter.queue_redraw()
        return

    highlighter._cached_range_cells = CardTargeting.get_range_cells(
        highlighter._player.grid_pos,
        card.range,
        highlighter.map_manager
    )

    highlighter.queue_redraw()
