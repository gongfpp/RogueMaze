class_name GameSession
extends RefCounted

const PLAYING: StringName = &"PLAYING"
const REWARD: StringName = &"REWARD"
const WON: StringName = &"WON"
const LOST: StringName = &"LOST"

const SPIKES: StringName = &"SPIKES"
const FALLING_ROCK: StringName = &"FALLING_ROCK"
const STEAM_VENT: StringName = &"STEAM_VENT"
const REPAIR_PAD: StringName = &"REPAIR_PAD"
const ROAD_MISSING: StringName = &"ROAD_MISSING"
const ROCK_HIT: StringName = &"ROCK_HIT"
const NO_HEALTH: StringName = &"NO_HEALTH"

const EVENT_NODE_CLEARED: StringName = &"NODE_CLEARED"
const EVENT_EXPEDITION_WON: StringName = &"EXPEDITION_WON"
const EVENT_RUN_LOST: StringName = &"RUN_LOST"
const EVENT_SPIKE_HIT: StringName = &"SPIKE_HIT"
const EVENT_ROCK_FELL: StringName = &"ROCK_FELL"
const EVENT_ROAD_SAVED: StringName = &"ROAD_SAVED"
const EVENT_STEAM_HIT: StringName = &"STEAM_HIT"
const EVENT_REPAIRED: StringName = &"REPAIRED"

const REWARD_ADD: StringName = &"ADD"
const REWARD_UPGRADE: StringName = &"UPGRADE"
const REWARD_REMOVE: StringName = &"REMOVE"

const BOARD_SIZE := Vector2i(8, 5)
const START := Vector2i(0, 2)
const FINISH := Vector2i(7, 2)
const HAND_SIZE := 4
const START_COUNTDOWN := 4.0
const NODE_COUNT := 5

var board: BoardState
var deck: DeckState
var runner: RunnerState
var content
var run_deck: Array[CardState] = []
var hand: Array[CardState] = []
var selected_card_index := 0
var selected_quarter_turns := 0
var state: StringName = PLAYING
var paused := false
var countdown := START_COUNTDOWN
var node_index := 0
var health := 3
var max_health := 3
var hazards: Dictionary = {}
var reward_options: Array[Dictionary] = []
var failure_reason: StringName = &""
var events: Array[StringName] = []
var next_card_instance_id := 1
var elapsed_seconds := 0.0
var roads_placed := 0
var invalid_placements := 0
var damage_taken := 0
var health_recovered := 0
var rewards_added := 0
var rewards_upgraded := 0
var rewards_removed := 0


func _init(p_content = null) -> void:
	content = p_content if p_content != null else ContentRegistry.default_registry()
	reset()


func reset() -> void:
	events.clear()
	run_deck.clear()
	next_card_instance_id = 1
	elapsed_seconds = 0.0
	roads_placed = 0
	invalid_placements = 0
	damage_taken = 0
	health_recovered = 0
	rewards_added = 0
	rewards_upgraded = 0
	rewards_removed = 0
	for road_id in content.starter_deck:
		run_deck.append(_create_card(road_id))
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
	for definition in content.node(node_index).get("hazards", []):
		var position: Vector2i = definition.position
		if definition.type == SPIKES:
			hazards[position] = {
				"type": SPIKES,
				"damage": definition.damage,
				"spent": false,
			}
		elif definition.type == FALLING_ROCK:
			hazards[position] = {
				"type": FALLING_ROCK,
				"timer": definition.timer,
				"triggered": false,
				"neutralized": false,
			}
		elif definition.type == STEAM_VENT:
			hazards[position] = {
				"type": STEAM_VENT,
				"cycle": definition.cycle,
				"active_duration": definition.active_duration,
				"phase": definition.phase,
				"elapsed": 0.0,
				"damage": definition.damage,
				"spent": false,
			}
		elif definition.type == REPAIR_PAD:
			hazards[position] = {
				"type": REPAIR_PAD,
				"healing": definition.healing,
				"spent": false,
			}


func update(delta: float) -> void:
	if paused or state != PLAYING:
		return
	elapsed_seconds += maxf(0.0, delta)
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
			_build_reward_options(content.node(node_index).reward_pool)
			events.append(EVENT_NODE_CLEARED)
	elif runner.status == RunnerState.FAILED:
		failure_reason = ROAD_MISSING
		state = LOST
		events.append(EVENT_RUN_LOST)


func _update_hazards(delta: float) -> void:
	for position in hazards:
		var hazard: Dictionary = hazards[position]
		if hazard.type == STEAM_VENT:
			hazard.elapsed += delta
			continue
		if hazard.type != FALLING_ROCK or hazard.triggered:
			continue
		hazard.timer = maxf(0.0, hazard.timer - delta)
		if hazard.timer > 0.0:
			continue
		hazard.triggered = true
		var road := board.road_at(position)
		if not road.is_empty() and int(road.get("level", 1)) > 1:
			road.level = 1
			hazard.neutralized = true
			events.append(EVENT_ROAD_SAVED)
			continue
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
		var spike_damage := int(hazard.get("damage", 1))
		damage_taken += mini(maxi(health, 0), spike_damage)
		health -= spike_damage
		events.append(EVENT_SPIKE_HIT)
		if health <= 0:
			failure_reason = NO_HEALTH
			state = LOST
			events.append(EVENT_RUN_LOST)
	elif hazard.type == FALLING_ROCK and hazard.triggered and not hazard.get("neutralized", false):
		failure_reason = ROCK_HIT
		state = LOST
		events.append(EVENT_RUN_LOST)
	elif hazard.type == STEAM_VENT and not hazard.spent and is_steam_active(hazard):
		hazard.spent = true
		var steam_damage := int(hazard.damage)
		damage_taken += mini(maxi(health, 0), steam_damage)
		health -= steam_damage
		events.append(EVENT_STEAM_HIT)
		if health <= 0:
			failure_reason = NO_HEALTH
			state = LOST
			events.append(EVENT_RUN_LOST)
	elif hazard.type == REPAIR_PAD and not hazard.spent and health < max_health:
		hazard.spent = true
		var health_before_repair := health
		health = mini(max_health, health + int(hazard.healing))
		health_recovered += health - health_before_repair
		events.append(EVENT_REPAIRED)


func is_steam_active(hazard: Dictionary) -> bool:
	var cycle := maxf(0.2, float(hazard.get("cycle", 4.0)))
	var phase_position := fmod(float(hazard.get("elapsed", 0.0)) + float(hazard.get("phase", 0.0)), cycle)
	return phase_position < float(hazard.get("active_duration", 1.5))


func steam_time_to_change(hazard: Dictionary) -> float:
	var cycle := maxf(0.2, float(hazard.get("cycle", 4.0)))
	var active_duration := float(hazard.get("active_duration", 1.5))
	var phase_position := fmod(float(hazard.get("elapsed", 0.0)) + float(hazard.get("phase", 0.0)), cycle)
	return active_duration - phase_position if phase_position < active_duration else cycle - phase_position


func choose_reward(index: int) -> bool:
	if state != REWARD or index < 0 or index >= reward_options.size():
		return false
	var option: Dictionary = reward_options[index]
	match option.type:
		REWARD_ADD:
			run_deck.append(_create_card(option.road_id))
			rewards_added += 1
		REWARD_UPGRADE:
			var card := _find_card(option.card_id)
			if card == null or not card.upgrade():
				return false
			rewards_upgraded += 1
		REWARD_REMOVE:
			if run_deck.size() <= HAND_SIZE:
				return false
			var card := _find_card(option.card_id)
			if card == null:
				return false
			run_deck.erase(card)
			rewards_removed += 1
		_:
			return false
	node_index += 1
	_start_node()
	return true


func _build_reward_options(road_pool: Array[StringName]) -> void:
	reward_options.clear()
	if road_pool.is_empty():
		return
	reward_options.append({
		"type": REWARD_ADD,
		"road_id": road_pool[0],
		"title": "ADD",
	})
	var upgrade_card := _first_upgrade_candidate()
	if upgrade_card != null:
		reward_options.append({
			"type": REWARD_UPGRADE,
			"road_id": upgrade_card.road_id,
			"card_id": upgrade_card.instance_id,
			"title": "UPGRADE",
		})
	var remove_card := _first_remove_candidate()
	if remove_card != null:
		reward_options.append({
			"type": REWARD_REMOVE,
			"road_id": remove_card.road_id,
			"card_id": remove_card.instance_id,
			"title": "REMOVE",
		})


func _create_card(road_id: StringName) -> CardState:
	var card := CardState.new(next_card_instance_id, road_id)
	next_card_instance_id += 1
	return card


func _find_card(instance_id: int) -> CardState:
	for card in run_deck:
		if card.instance_id == instance_id:
			return card
	return null


func _first_upgrade_candidate() -> CardState:
	for card in run_deck:
		if card.can_upgrade():
			return card
	return null


func _first_remove_candidate() -> CardState:
	for card in run_deck:
		if card.road_id in [RoadCatalog.UP_RAMP, RoadCatalog.DOWN_RAMP, RoadCatalog.TURN]:
			return card
	return run_deck.back() if run_deck.size() > HAND_SIZE else null


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
	return RoadCatalog.get_definition(hand[selected_card_index].road_id)


func validate_selected(position: Vector2i) -> Dictionary:
	if state != PLAYING or paused:
		return {"ok": false, "reason": &"SESSION_NOT_ACTIVE"}
	return board.validate_placement(selected_definition(), position, selected_quarter_turns)


func place_selected(position: Vector2i) -> Dictionary:
	var active_attempt := state == PLAYING and not paused
	var result := validate_selected(position)
	if not result.ok:
		if active_attempt:
			invalid_placements += 1
		return result
	result = board.place(
		selected_definition(),
		position,
		selected_quarter_turns,
		false,
		hand[selected_card_index].level,
	)
	if not result.ok:
		if active_attempt:
			invalid_placements += 1
		return result
	roads_placed += 1
	var played_card: CardState = hand[selected_card_index]
	deck.discard(played_card)
	hand[selected_card_index] = deck.draw()
	selected_quarter_turns = 0
	return result


func toggle_pause() -> void:
	set_paused(not paused)


func set_paused(value: bool) -> bool:
	if state != PLAYING:
		return false
	paused = value
	return true


func run_summary() -> Dictionary:
	return {
		"elapsed_seconds": elapsed_seconds,
		"roads_placed": roads_placed,
		"invalid_placements": invalid_placements,
		"damage_taken": damage_taken,
		"health_recovered": health_recovered,
		"rewards_added": rewards_added,
		"rewards_upgraded": rewards_upgraded,
		"rewards_removed": rewards_removed,
	}
