class_name RunSimulator
extends RefCounted

const WIN: StringName = &"WIN"
const PLACEMENT_FAILED: StringName = &"PLACEMENT_FAILED"
const END_NOT_REACHED: StringName = &"END_NOT_REACHED"


static func simulate(scenario: Dictionary) -> Dictionary:
	var board_size: Vector2i = scenario.board_size
	var board := BoardState.new(board_size.x, board_size.y)
	var start: Dictionary = scenario.start
	var start_result := board.place(
		RoadCatalog.get_definition(start.road_id),
		start.position,
		start.get("quarter_turns", 0),
		true,
	)
	assert(start_result.ok, "Scenario must have a valid start road")

	var deck_data: Dictionary = scenario.deck
	var deck := DeckState.new(
		deck_data.cards,
		deck_data.get("mode", DeckState.Mode.FIXED_CYCLE),
		deck_data.get("seed", 1),
	)
	var history: Array[Dictionary] = []
	var placements: Array = scenario.placements
	for index in placements.size():
		var placement: Dictionary = placements[index]
		var card_id: StringName = deck.draw()
		var result := board.place(
			RoadCatalog.get_definition(card_id),
			placement.position,
			placement.get("quarter_turns", 0),
		)
		history.append({
			"turn": index + 1,
			"card_id": card_id,
			"placement": placement,
			"result": result,
		})
		deck.discard(card_id)
		if not result.ok:
			return {
				"outcome": PLACEMENT_FAILED,
				"reason": result.reason,
				"turn": index + 1,
				"history": history,
			}
		if board.are_connected(start.position, scenario.finish):
			return {
				"outcome": WIN,
				"reason": &"",
				"turn": index + 1,
				"history": history,
			}

	return {
		"outcome": END_NOT_REACHED,
		"reason": END_NOT_REACHED,
		"turn": placements.size(),
		"history": history,
	}
