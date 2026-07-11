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
