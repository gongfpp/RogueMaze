extends SceneTree

var assertions := 0
var failures := 0


func _initialize() -> void:
	call_deferred("_run_all")


func _run_all() -> void:
	_test_directions_and_roads()
	_test_board_placement()
	_test_deck_cycles()
	_test_scenarios()
	_test_runner_and_session()
	_test_audio_cues()
	if failures > 0:
		push_error("Godot rules: %d assertion(s), %d failure(s)" % [assertions, failures])
		quit(1)
		return
	print("Godot rules: %d assertion(s), all passed" % assertions)
	quit(0)


func _expect_equal(actual: Variant, expected: Variant, label: String) -> void:
	assertions += 1
	if actual != expected:
		failures += 1
		push_error("%s | expected=%s actual=%s" % [label, expected, actual])


func _expect_true(value: bool, label: String) -> void:
	_expect_equal(value, true, label)


func _new_board_with_start() -> BoardState:
	var board := BoardState.new(4, 3)
	var result := board.place(
		RoadCatalog.get_definition(RoadCatalog.STRAIGHT),
		Vector2i(0, 1),
		0,
		true,
	)
	_expect_true(result.ok, "start road is valid")
	return board


func _test_directions_and_roads() -> void:
	_expect_equal(DirectionRules.rotate(DirectionRules.Value.LEFT, 1), DirectionRules.Value.UP, "rotate clockwise")
	_expect_equal(DirectionRules.rotate(DirectionRules.Value.LEFT, 4), DirectionRules.Value.LEFT, "four rotations reset")
	_expect_equal(DirectionRules.rotate(DirectionRules.Value.LEFT, -1), DirectionRules.Value.DOWN, "negative rotation")
	var vertical := RoadCatalog.get_definition(RoadCatalog.STRAIGHT).rotated_ports(1)
	_expect_true(vertical.has(DirectionRules.Value.UP), "vertical straight opens up")
	_expect_true(vertical.has(DirectionRules.Value.DOWN), "vertical straight opens down")
	_expect_equal(RoadCatalog.ALL_IDS.size(), 5, "five road definitions")


func _test_board_placement() -> void:
	var straight := RoadCatalog.get_definition(RoadCatalog.STRAIGHT)
	var board := _new_board_with_start()
	var legal := board.place(straight, Vector2i(1, 1))
	_expect_true(legal.ok, "matching ports connect")
	_expect_equal(legal.matching_connections, 1, "one matching neighbor")
	_expect_true(board.are_connected(Vector2i(0, 1), Vector2i(1, 1)), "connected search")

	board = _new_board_with_start()
	_expect_equal(board.place(straight, Vector2i(4, 1)).reason, BoardState.OUT_OF_BOUNDS, "out of bounds")
	_expect_equal(board.place(straight, Vector2i(0, 1)).reason, BoardState.OCCUPIED, "occupied")
	_expect_equal(board.place(straight, Vector2i(1, 1), 1).reason, BoardState.PORT_MISMATCH, "port mismatch")
	_expect_equal(board.place(straight, Vector2i(3, 2)).reason, BoardState.ISOLATED, "isolated")

	board = _new_board_with_start()
	var ramp := RoadCatalog.get_definition(RoadCatalog.UP_RAMP)
	_expect_true(board.place(ramp, Vector2i(1, 1)).ok, "lower ramp")
	_expect_true(board.place(ramp, Vector2i(1, 0), 2).ok, "upper ramp")
	_expect_true(board.place(straight, Vector2i(2, 0)).ok, "upper straight")
	_expect_true(board.are_connected(Vector2i(0, 1), Vector2i(2, 0)), "upward route connected")


func _draw_and_discard(deck: DeckState, count: int) -> Array[StringName]:
	var result: Array[StringName] = []
	for index in count:
		var card := deck.draw()
		result.append(card)
		deck.discard(card)
	return result


func _test_deck_cycles() -> void:
	var cards: Array[StringName] = [&"A", &"B", &"C"]
	var fixed := DeckState.new(cards, DeckState.Mode.FIXED_CYCLE)
	_expect_equal(
		_draw_and_discard(fixed, 7),
		[&"A", &"B", &"C", &"A", &"B", &"C", &"A"],
		"fixed cycle order",
	)

	var shuffle_cards: Array[StringName] = [&"A", &"B", &"C", &"D"]
	var first := DeckState.new(shuffle_cards, DeckState.Mode.SHUFFLE_DISCARD, 20260712)
	var second := DeckState.new(shuffle_cards, DeckState.Mode.SHUFFLE_DISCARD, 20260712)
	var third := DeckState.new(shuffle_cards, DeckState.Mode.SHUFFLE_DISCARD, 2)
	var first_sequence := _draw_and_discard(first, 12)
	_expect_equal(first_sequence, _draw_and_discard(second, 12), "same seed replays")
	_expect_equal(first_sequence == _draw_and_discard(third, 12), false, "different seed changes sequence")


func _test_scenarios() -> void:
	for scenario in ScenarioFixtures.all():
		var result := RunSimulator.simulate(scenario)
		var expected: Dictionary = scenario.expected
		_expect_equal(result.outcome, expected.outcome, "%s outcome" % scenario.id)
		_expect_equal(result.turn, expected.turn, "%s turn" % scenario.id)
		if expected.has("reason"):
			_expect_equal(result.reason, expected.reason, "%s reason" % scenario.id)


func _place_flat_route(session: GameSession) -> void:
	for x in range(1, GameSession.BOARD_SIZE.x):
		var flat_card_index := -1
		for index in session.hand.size():
			if session.hand[index] in [RoadCatalog.STRAIGHT, RoadCatalog.BRIDGE]:
				flat_card_index = index
				break
		_expect_equal(flat_card_index >= 0, true, "flat route always has a usable card")
		session.select_card(flat_card_index)
		_expect_true(session.place_selected(Vector2i(x, 2)).ok, "place full route cell %d" % x)


func _advance_runner_to_end(session: GameSession, steps: int = GameSession.BOARD_SIZE.x - 1) -> void:
	session.countdown = 0.0
	for step in steps:
		session.update(2.0)


func _test_runner_and_session() -> void:
	var board := BoardState.new(3, 1)
	var straight := RoadCatalog.get_definition(RoadCatalog.STRAIGHT)
	board.place(straight, Vector2i(0, 0), 0, true)
	board.place(straight, Vector2i(1, 0))
	board.place(straight, Vector2i(2, 0))
	var runner := RunnerState.new(Vector2i(0, 0), 1.0, 0.25)
	runner.update(1.0, board, Vector2i(2, 0))
	_expect_equal(runner.current_position, Vector2i(1, 0), "runner enters next road")
	runner.update(1.0, board, Vector2i(2, 0))
	_expect_equal(runner.current_position, Vector2i(2, 0), "runner reaches finish cell")
	_expect_equal(runner.status, RunnerState.REACHED, "runner reports reached")

	var blocked_board := BoardState.new(2, 1)
	blocked_board.place(straight, Vector2i(0, 0), 0, true)
	var blocked_runner := RunnerState.new(Vector2i(0, 0), 1.0, 0.25)
	blocked_runner.update(0.3, blocked_board, Vector2i(1, 0))
	_expect_equal(blocked_runner.status, RunnerState.FAILED, "runner fails after blocked grace")
	var failed_session := GameSession.new()
	failed_session.countdown = 0.0
	failed_session.update(2.0)
	_expect_equal(failed_session.state, GameSession.LOST, "session reports blocked route loss")
	_expect_equal(failed_session.failure_reason, GameSession.ROAD_MISSING, "blocked loss has clear reason")

	var session := GameSession.new()
	_expect_equal(session.hand.size(), GameSession.HAND_SIZE, "session deals four cards")
	var placed := session.place_selected(Vector2i(1, 2))
	_expect_true(placed.ok, "session places selected road")
	_expect_equal(session.hand.size(), GameSession.HAND_SIZE, "placing refills hand")
	_expect_equal(session.hand[0], GameSession.STARTER_DECK[4], "played slot receives next authored card")
	_expect_equal(session.deck.fixed_index, 5, "placing advances deck draw index")
	var hand_after_place := session.hand.duplicate()
	var rejected := session.place_selected(Vector2i(1, 2))
	_expect_equal(rejected.reason, BoardState.OCCUPIED, "session preserves board rejection")
	_expect_equal(session.hand, hand_after_place, "rejected placement keeps hand")
	_expect_true(session.select_card(3), "valid card selection")
	_expect_equal(session.select_card(9), false, "invalid card selection")

	var expedition := GameSession.new()
	_place_flat_route(expedition)
	_advance_runner_to_end(expedition)
	_expect_equal(expedition.state, GameSession.REWARD, "first node opens reward")
	var deck_size_before := expedition.run_deck.size()
	_expect_true(expedition.choose_reward(0), "choose a road reward")
	_expect_equal(expedition.node_index, 1, "reward advances node")
	_expect_equal(expedition.run_deck.size(), deck_size_before + 1, "reward grows run deck")
	_expect_true(expedition.hazards.has(Vector2i(3, 2)), "second node contains spikes")

	_place_flat_route(expedition)
	_advance_runner_to_end(expedition, 3)
	_expect_equal(expedition.health, 2, "crossing fresh spikes costs one health")
	_advance_runner_to_end(expedition, 4)
	_expect_equal(expedition.state, GameSession.REWARD, "second node opens reward")
	_expect_true(expedition.choose_reward(1), "choose second node reward")
	_expect_equal(expedition.node_index, 2, "second reward advances to final node")
	expedition.hazards.clear()
	_place_flat_route(expedition)
	_advance_runner_to_end(expedition)
	_expect_equal(expedition.state, GameSession.WON, "third node completes expedition")

	var rock_session := GameSession.new()
	rock_session.node_index = 2
	rock_session._start_node()
	_place_flat_route(rock_session)
	var rock: Dictionary = rock_session.hazards[Vector2i(5, 2)]
	rock.timer = 0.01
	rock_session.countdown = 0.0
	rock_session.update(0.02)
	_expect_equal(rock.triggered, true, "falling rock triggers on timer")
	_expect_equal(rock_session.board.road_at(Vector2i(5, 2)).is_empty(), true, "falling rock destroys road")
	_expect_true(rock_session.pop_events().has(GameSession.EVENT_ROCK_FELL), "rock event is observable")


func _test_audio_cues() -> void:
	var tone := AudioCues.build_tone(440.0, 0.08, 0.2)
	_expect_equal(tone.format, AudioStreamWAV.FORMAT_16_BITS, "procedural cue uses 16-bit PCM")
	_expect_equal(tone.mix_rate, AudioCues.MIX_RATE, "procedural cue uses expected mix rate")
	_expect_equal(tone.stereo, false, "procedural cue is mono")
	_expect_true(tone.data.size() > 1000, "procedural cue contains samples")
