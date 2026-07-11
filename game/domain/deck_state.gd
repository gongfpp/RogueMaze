class_name DeckState
extends RefCounted

enum Mode {
	FIXED_CYCLE,
	SHUFFLE_DISCARD,
}

var cards: Array[StringName]
var mode: Mode
var fixed_index := 0
var draw_pile: Array[StringName]
var discard_pile: Array[StringName] = []
var random_state: int


func _init(p_cards: Array, p_mode: Mode = Mode.FIXED_CYCLE, seed: int = 1) -> void:
	assert(not p_cards.is_empty(), "Deck must contain at least one card")
	cards.assign(p_cards)
	draw_pile.assign(p_cards)
	mode = p_mode
	random_state = seed & 0xffffffff


func draw() -> StringName:
	if mode == Mode.FIXED_CYCLE:
		var card := cards[fixed_index % cards.size()]
		fixed_index += 1
		return card

	if draw_pile.is_empty():
		assert(not discard_pile.is_empty(), "Cannot draw from empty draw and discard piles")
		draw_pile = _shuffle(discard_pile)
		discard_pile.clear()
	return draw_pile.pop_front()


func discard(card: StringName) -> void:
	if mode == Mode.SHUFFLE_DISCARD:
		discard_pile.append(card)


func _next_random() -> float:
	random_state = (random_state * 1664525 + 1013904223) & 0xffffffff
	return float(random_state) / 4294967296.0


func _shuffle(items: Array[StringName]) -> Array[StringName]:
	var result: Array[StringName] = items.duplicate()
	for index in range(result.size() - 1, 0, -1):
		var swap_index := int(floor(_next_random() * float(index + 1)))
		var temporary := result[index]
		result[index] = result[swap_index]
		result[swap_index] = temporary
	return result
