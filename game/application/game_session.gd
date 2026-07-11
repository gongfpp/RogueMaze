class_name GameSession
extends RefCounted

const PLAYING: StringName = &"PLAYING"
const REWARD: StringName = &"REWARD"
const WON: StringName = &"WON"
const LOST: StringName = &"LOST"

const SPIKES: StringName = &"SPIKES"
const FALLING_ROCK: StringName = &"FALLING_ROCK"
const ROAD_MISSING: StringName = &"ROAD_MISSING"
const ROCK_HIT: StringName = &"ROCK_HIT"
const NO_HEALTH: StringName = &"NO_HEALTH"

const EVENT_NODE_CLEARED: StringName = &"NODE_CLEARED"
const EVENT_EXPEDITION_WON: StringName = &"EXPEDITION_WON"
const EVENT_RUN_LOST: StringName = &"RUN_LOST"
const EVENT_SPIKE_HIT: StringName = &"SPIKE_HIT"
const EVENT_ROCK_FELL: StringName = &"ROCK_FELL"

const BOARD_SIZE := Vector2i(8, 5)
const START := Vector2i(0, 2)
const FINISH := Vector2i(7, 2)
const HAND_SIZE := 4
const START_COUNTDOWN := 4.0
const NODE_COUNT := 3

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
var run_deck: Array[StringName] = []
var hand: Array[StringName] = []
var selected_card_index := 0
var selected_quarter_turns := 0
var state: StringName = PLAYING
var paused := false
var countdown := START_COUNTDOWN
var node_index := 0
var health := 3
var max_health := 3
var hazards: Dictionary = {}
var reward_options: Array[StringName] = []
var failure_reason: StringName = &""
var events: Array[StringName] = []


func _init() -> void:
	reset()


func reset() -> void:
	events.clear()
	run_deck.assign(STARTER_DECK)
	node_index = 0
	health = max_health
	_start_node()


func _start_node() -> void:
	board = BoardState.new(BOARD_SIZE.x, BOARD_SIZE.y)
	board.place(RoadCatalog.get_definition(RoadCatalog.STRAIGHT), START, 0, true)
	deck = DeckState.new(run_deck, DeckState.Mode.FIXED_CYCLE)
	hand.clear()
	for index in HAND_SIZE:
		hand.append(deck.draw())
	runner = RunnerState.new(START)
	selected_card_index = 0
	selected_quarter_turns = 0
	state = PLAYING
	paused = false
	countdown = START_COUNTDOWN
	reward_options.clear()
	failure_reason = &""
	_configure_hazards()


func _configure_hazards() -> void:
	hazards.clear()
	if node_index >= 1:
		hazards[Vector2i(3, 2)] = {
			"type": SPIKES,
			"spent": false,
		}
	if node_index >= 2:
		hazards[Vector2i(5, 2)] = {
			"type": FALLING_ROCK,
			"timer": 8.0,
			"triggered": false,
		}


func update(delta: float) -> void:
	if paused or state != PLAYING:
		return
	if countdown > 0.0:
		countdown = maxf(0.0, countdown - delta)
		return
	_update_hazards(delta)
	if state != PLAYING:
		return
	runner.update(delta, board, FINISH)
	if runner.entered_cell:
		_apply_entered_cell_hazard(runner.last_entered_position)
	if state != PLAYING:
		return
	if runner.status == RunnerState.REACHED:
		if node_index + 1 >= NODE_COUNT:
			state = WON
			events.append(EVENT_EXPEDITION_WON)
		else:
			state = REWARD
			reward_options.assign([RoadCatalog.BRIDGE, RoadCatalog.STRAIGHT, RoadCatalog.UP_RAMP])
			events.append(EVENT_NODE_CLEARED)
	elif runner.status == RunnerState.FAILED:
		failure_reason = ROAD_MISSING
		state = LOST
		events.append(EVENT_RUN_LOST)


func _update_hazards(delta: float) -> void:
	for position in hazards:
		var hazard: Dictionary = hazards[position]
		if hazard.type != FALLING_ROCK or hazard.triggered:
			continue
		hazard.timer = maxf(0.0, hazard.timer - delta)
		if hazard.timer > 0.0:
			continue
		hazard.triggered = true
		board.remove(position)
		events.append(EVENT_ROCK_FELL)
		if runner.current_position == position or (runner.has_target and runner.target_position == position):
			failure_reason = ROCK_HIT
			state = LOST
			events.append(EVENT_RUN_LOST)


func _apply_entered_cell_hazard(position: Vector2i) -> void:
	if not hazards.has(position):
		return
	var hazard: Dictionary = hazards[position]
	if hazard.type == SPIKES and not hazard.spent:
		hazard.spent = true
		health -= 1
		events.append(EVENT_SPIKE_HIT)
		if health <= 0:
			failure_reason = NO_HEALTH
			state = LOST
			events.append(EVENT_RUN_LOST)
	elif hazard.type == FALLING_ROCK and hazard.triggered:
		failure_reason = ROCK_HIT
		state = LOST
		events.append(EVENT_RUN_LOST)


func choose_reward(index: int) -> bool:
	if state != REWARD or index < 0 or index >= reward_options.size():
		return false
	run_deck.append(reward_options[index])
	node_index += 1
	_start_node()
	return true


func pop_events() -> Array[StringName]:
	var result: Array[StringName] = events.duplicate()
	events.clear()
	return result


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
