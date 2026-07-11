class_name GameSession
extends RefCounted

const PLAYING: StringName = &"PLAYING"
const WON: StringName = &"WON"
const LOST: StringName = &"LOST"

const BOARD_SIZE := Vector2i(8, 5)
const START := Vector2i(0, 2)
const FINISH := Vector2i(7, 2)
const HAND_SIZE := 4
const START_COUNTDOWN := 4.0

const STARTER_DECK: Array[StringName] = [
	RoadCatalog.STRAIGHT,
	RoadCatalog.STRAIGHT,
	RoadCatalog.UP_RAMP,
	RoadCatalog.DOWN_RAMP,
	RoadCatalog.STRAIGHT,
	RoadCatalog.BRIDGE,
	RoadCatalog.TURN,
	RoadCatalog.STRAIGHT,
]

var board: BoardState
var deck: DeckState
var runner: RunnerState
var hand: Array[StringName] = []
var selected_card_index := 0
var selected_quarter_turns := 0
var state: StringName = PLAYING
var paused := false
var countdown := START_COUNTDOWN


func _init() -> void:
	reset()


func reset() -> void:
	board = BoardState.new(BOARD_SIZE.x, BOARD_SIZE.y)
	board.place(RoadCatalog.get_definition(RoadCatalog.STRAIGHT), START, 0, true)
	deck = DeckState.new(STARTER_DECK, DeckState.Mode.FIXED_CYCLE)
	hand.clear()
	for index in HAND_SIZE:
		hand.append(deck.draw())
	runner = RunnerState.new(START)
	selected_card_index = 0
	selected_quarter_turns = 0
	state = PLAYING
	paused = false
	countdown = START_COUNTDOWN


func update(delta: float) -> void:
	if paused or state != PLAYING:
		return
	if countdown > 0.0:
		countdown = maxf(0.0, countdown - delta)
		return
	runner.update(delta, board, FINISH)
	if runner.status == RunnerState.REACHED:
		state = WON
	elif runner.status == RunnerState.FAILED:
		state = LOST


func select_card(index: int) -> bool:
	if index < 0 or index >= hand.size():
		return false
	selected_card_index = index
	selected_quarter_turns = 0
	return true


func rotate_selected() -> void:
	selected_quarter_turns = DirectionRules.normalize_quarter_turns(selected_quarter_turns + 1)


func selected_definition() -> RoadDefinition:
	return RoadCatalog.get_definition(hand[selected_card_index])


func validate_selected(position: Vector2i) -> Dictionary:
	if state != PLAYING or paused:
		return {"ok": false, "reason": &"SESSION_NOT_ACTIVE"}
	return board.validate_placement(selected_definition(), position, selected_quarter_turns)


func place_selected(position: Vector2i) -> Dictionary:
	var result := validate_selected(position)
	if not result.ok:
		return result
	result = board.place(selected_definition(), position, selected_quarter_turns)
	if not result.ok:
		return result
	var played_card := hand[selected_card_index]
	deck.discard(played_card)
	hand[selected_card_index] = deck.draw()
	selected_quarter_turns = 0
	return result


func toggle_pause() -> void:
	if state == PLAYING:
		paused = not paused
