extends SceneTree

var assertions := 0
var failures := 0


func _initialize() -> void:
	call_deferred("_run_all")


func _run_all() -> void:
	_test_directions_and_roads()
	_test_content_registry()
	_test_card_progression()
	_test_board_placement()
	_test_deck_cycles()
	_test_scenarios()
	_test_runner_and_session()
	_test_audio_cues()
	_test_persistence()
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


func _test_content_registry() -> void:
	var content := ContentRegistry.default_registry()
	_expect_true(content.is_valid(), "default gameplay content validates")
	_expect_equal(content.roads.size(), RoadCatalog.ALL_IDS.size(), "content defines every road")
	_expect_equal(content.road_label(RoadCatalog.UP_RAMP), "RAMP UP", "road label comes from content")
	_expect_equal(content.nodes.size(), GameSession.NODE_COUNT, "content defines the expedition nodes")
	_expect_equal(content.node(1).hazards[0].damage, 1, "hazard damage comes from content")
	_expect_equal(content.node(2).hazards[1].timer, 8.0, "rock timer comes from content")

	var invalid := ContentRegistry.from_data({
		"schema_version": 1,
		"roads": [
			{"id": "broken", "ports": ["LEFT", "NOWHERE"]},
			{"id": "broken", "ports": ["LEFT", "RIGHT"]},
		],
		"expedition": {
			"starter_deck": ["missing"],
			"nodes": [{"id": "only", "hazards": [], "reward_pool": []}],
		},
	})
	_expect_equal(invalid.is_valid(), false, "invalid content is rejected")
	_expect_true(invalid.errors.size() >= 3, "content validation reports multiple authoring mistakes")


func _test_card_progression() -> void:
	var card := CardState.new(1, RoadCatalog.STRAIGHT)
	_expect_equal(card.level, 1, "new card starts at level one")
	_expect_true(card.upgrade(), "card upgrades once")
	_expect_equal(card.level, CardState.MAX_LEVEL, "card reaches armor level")
	_expect_equal(card.level_suffix(), "+", "upgraded card exposes readable suffix")
	_expect_equal(card.upgrade(), false, "card cannot exceed max level")

	var reward_session := GameSession.new()
	reward_session.state = GameSession.REWARD
	reward_session._build_reward_options([RoadCatalog.BRIDGE])
	_expect_equal(reward_session.reward_options.size(), 3, "reward offers three deck actions")
	_expect_equal(reward_session.reward_options[0].type, GameSession.REWARD_ADD, "first reward adds")
	_expect_equal(reward_session.reward_options[1].type, GameSession.REWARD_UPGRADE, "second reward upgrades")
	_expect_equal(reward_session.reward_options[2].type, GameSession.REWARD_REMOVE, "third reward removes")
	var original_size := reward_session.run_deck.size()
	_expect_true(reward_session.choose_reward(0), "add reward applies")
	_expect_equal(reward_session.run_deck.size(), original_size + 1, "add reward grows deck")

	var upgrade_session := GameSession.new()
	upgrade_session.state = GameSession.REWARD
	upgrade_session._build_reward_options([RoadCatalog.BRIDGE])
	var upgrade_id: int = upgrade_session.reward_options[1].card_id
	_expect_true(upgrade_session.choose_reward(1), "upgrade reward applies")
	_expect_equal(upgrade_session._find_card(upgrade_id).level, 2, "upgrade reward changes chosen instance")
	_expect_equal(upgrade_session.run_deck.size(), original_size, "upgrade reward keeps deck size")

	var remove_session := GameSession.new()
	remove_session.state = GameSession.REWARD
	remove_session._build_reward_options([RoadCatalog.BRIDGE])
	var remove_id: int = remove_session.reward_options[2].card_id
	_expect_true(remove_session.choose_reward(2), "remove reward applies")
	_expect_equal(remove_session._find_card(remove_id), null, "remove reward deletes chosen instance")
	_expect_equal(remove_session.run_deck.size(), original_size - 1, "remove reward shrinks deck")

	var armor_session := GameSession.new()
	armor_session.node_index = 2
	armor_session._start_node()
	armor_session.board.place(
		RoadCatalog.get_definition(RoadCatalog.STRAIGHT),
		Vector2i(5, 2),
		0,
		true,
		2,
	)
	var rock: Dictionary = armor_session.hazards[Vector2i(5, 2)]
	rock.timer = 0.01
	armor_session.countdown = 0.0
	armor_session.update(0.02)
	_expect_equal(armor_session.board.road_at(Vector2i(5, 2)).level, 1, "armor downgrades instead of breaking")
	_expect_equal(rock.neutralized, true, "armor neutralizes the falling rock")
	_expect_true(armor_session.pop_events().has(GameSession.EVENT_ROAD_SAVED), "armor save emits presentation event")


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
		var card: StringName = deck.draw()
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
			if session.hand[index].road_id in [RoadCatalog.STRAIGHT, RoadCatalog.BRIDGE]:
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
	_expect_equal(session.hand[0].road_id, session.content.starter_deck[4], "played slot receives next authored card")
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


func _test_persistence() -> void:
	var invalid_settings := PersistenceService.sanitize_settings({
		"version": 0,
		"sfx_enabled": "not a bool",
		"reduced_motion": true,
	})
	_expect_equal(invalid_settings.version, PersistenceService.SETTINGS_VERSION, "settings migrate to current version")
	_expect_equal(invalid_settings.sfx_enabled, true, "invalid SFX value uses default")
	_expect_equal(invalid_settings.reduced_motion, true, "valid legacy motion value migrates")

	var sanitized_progress := PersistenceService.sanitize_progress({
		"version": 0,
		"expeditions_won": 2.0,
		"best_node": 99,
		"unlocked_roads": ["straight", "straight", "unknown", "bridge"],
	})
	_expect_equal(sanitized_progress.expeditions_won, 2, "numeric wins migrate")
	_expect_equal(sanitized_progress.best_node, GameSession.NODE_COUNT, "best node is clamped")
	_expect_equal(sanitized_progress.unlocked_roads, ["straight", "bridge"], "unlocks are valid and unique")

	var service := PersistenceService.new(
		"user://tests/settings-roundtrip.json",
		"user://tests/progress-roundtrip.json",
	)
	_cleanup_persistence_test_files(service)
	service.settings.sfx_enabled = false
	service.settings.reduced_motion = true
	_expect_true(service.save_settings(), "settings save atomically")
	service.progress.expeditions_won = 4
	service.progress.best_node = 2
	_expect_true(service.save_progress(), "progress saves atomically")

	var loaded := PersistenceService.new(service.settings_path, service.progress_path)
	loaded.load_all()
	_expect_equal(loaded.settings.sfx_enabled, false, "settings roundtrip SFX")
	_expect_equal(loaded.settings.reduced_motion, true, "settings roundtrip motion")
	_expect_equal(loaded.progress.expeditions_won, 4, "progress roundtrip wins")
	_expect_equal(loaded.progress.best_node, 2, "progress roundtrip best node")
	_expect_true(loaded.record_expedition_win(), "win record persists")
	_expect_equal(loaded.progress.expeditions_won, 5, "win record increments")

	var corrupt_file := FileAccess.open(service.progress_path, FileAccess.WRITE)
	corrupt_file.store_string("{ this is not valid json")
	corrupt_file.close()
	var recovered := PersistenceService.new(service.settings_path, service.progress_path)
	recovered.load_all()
	_expect_equal(recovered.progress, PersistenceService.default_progress(), "corrupt progress falls back safely")
	_cleanup_persistence_test_files(service)


func _cleanup_persistence_test_files(service: PersistenceService) -> void:
	for path in [service.settings_path, service.progress_path]:
		var absolute := ProjectSettings.globalize_path(path)
		for suffix in ["", ".tmp", ".bak"]:
			if FileAccess.file_exists(absolute + suffix):
				DirAccess.remove_absolute(absolute + suffix)
