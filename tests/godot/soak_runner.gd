extends SceneTree

const DEFAULT_RUNS := 250
const MAX_RUNS := 5000

var checks := 0
var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var runs := _requested_runs()
	var started_at := Time.get_ticks_msec()
	var winning_session := GameSession.new()
	var losing_session := GameSession.new()
	for run_index in range(runs):
		winning_session.reset()
		_run_winning_expedition(winning_session, run_index)
		losing_session.reset()
		_run_expected_loss(losing_session, run_index)
	var elapsed_seconds := (Time.get_ticks_msec() - started_at) / 1000.0
	if failures > 0:
		push_error(
			"Godot soak: %d expedition(s), %d check(s), %d failure(s)" %
			[runs, checks, failures]
		)
		quit(1)
		return
	print(
		"Godot soak: %d expedition(s), %d invariant check(s), all passed in %.2fs" %
		[runs, checks, elapsed_seconds]
	)
	quit(0)


func _requested_runs() -> int:
	# PowerShell script forwarding can retain custom values in the full list even after `--`.
	# Searching both lists keeps the focused wrapper and direct Godot invocation consistent.
	var arguments := OS.get_cmdline_user_args() + OS.get_cmdline_args()
	for argument in arguments:
		if argument.begins_with("--runs="):
			var parsed := int(argument.trim_prefix("--runs="))
			if parsed > 0:
				return clampi(parsed, 1, MAX_RUNS)
	return DEFAULT_RUNS


func _run_winning_expedition(session: GameSession, run_index: int) -> void:
	_expect_equal(session.state, GameSession.PLAYING, "run %d starts active" % run_index)
	_expect_equal(session.node_index, 0, "run %d resets node" % run_index)
	_expect_equal(session.health, session.max_health, "run %d resets health" % run_index)
	_expect_equal(
		session.run_deck.size(),
		session.content.starter_deck.size(),
		"run %d resets deck size" % run_index,
	)
	for node_index in range(GameSession.NODE_COUNT):
		# Hazard behavior has focused unit tests. This route isolates long-run session progression.
		session.hazards.clear()
		if not _place_flat_route(session, run_index, node_index):
			return
		session.countdown = 0.0
		for step in range(GameSession.BOARD_SIZE.x - 1):
			session.update(2.0)
		var expected_state := (
			GameSession.WON if node_index + 1 == GameSession.NODE_COUNT else GameSession.REWARD
		)
		_expect_equal(
			session.state,
			expected_state,
			"run %d node %d reaches expected state" % [run_index, node_index],
		)
		var events := session.pop_events()
		var expected_event := (
			GameSession.EVENT_EXPEDITION_WON
			if expected_state == GameSession.WON
			else GameSession.EVENT_NODE_CLEARED
		)
		_expect_true(
			events.has(expected_event),
			"run %d node %d emits completion event" % [run_index, node_index],
		)
		if expected_state == GameSession.WON:
			break
		_expect_true(
			not session.reward_options.is_empty(),
			"run %d node %d offers a reward" % [run_index, node_index],
		)
		if session.reward_options.is_empty():
			return
		var reward_index := (run_index + node_index) % session.reward_options.size()
		_expect_true(
			session.choose_reward(reward_index),
			"run %d node %d applies reward %d" % [run_index, node_index, reward_index],
		)
		_expect_equal(
			session.node_index,
			node_index + 1,
			"run %d advances after node %d" % [run_index, node_index],
		)
		_check_card_invariants(session, run_index, node_index)


func _place_flat_route(session: GameSession, run_index: int, node_index: int) -> bool:
	for x in range(1, GameSession.BOARD_SIZE.x):
		var flat_card_index := -1
		for hand_index in range(session.hand.size()):
			if session.hand[hand_index].road_id in [RoadCatalog.STRAIGHT, RoadCatalog.BRIDGE]:
				flat_card_index = hand_index
				break
		_expect_true(
			flat_card_index >= 0,
			"run %d node %d has flat card for x=%d" % [run_index, node_index, x],
		)
		if flat_card_index < 0:
			return false
		session.select_card(flat_card_index)
		var placement := session.place_selected(Vector2i(x, 2))
		_expect_true(
			placement.ok,
			"run %d node %d places x=%d" % [run_index, node_index, x],
		)
		if not placement.ok:
			return false
	return true


func _check_card_invariants(session: GameSession, run_index: int, node_index: int) -> void:
	_expect_equal(
		session.hand.size(),
		GameSession.HAND_SIZE,
		"run %d node %d keeps hand size" % [run_index, node_index],
	)
	_expect_true(
		session.run_deck.size() >= GameSession.HAND_SIZE,
		"run %d node %d keeps a drawable deck" % [run_index, node_index],
	)
	var instance_ids := {}
	for card in session.run_deck:
		instance_ids[card.instance_id] = true
		_expect_true(
			card.level >= 1 and card.level <= CardState.MAX_LEVEL,
			"run %d node %d keeps valid card levels" % [run_index, node_index],
		)
	_expect_equal(
		instance_ids.size(),
		session.run_deck.size(),
		"run %d node %d keeps unique card instances" % [run_index, node_index],
	)


func _run_expected_loss(session: GameSession, run_index: int) -> void:
	var countdown_before_pause := session.countdown
	_expect_true(session.set_paused(true), "loss run %d can pause" % run_index)
	session.update(60.0)
	_expect_equal(
		session.countdown,
		countdown_before_pause,
		"loss run %d does not advance while paused" % run_index,
	)
	_expect_true(session.set_paused(false), "loss run %d can resume" % run_index)
	session.countdown = 0.0
	session.update(2.0)
	_expect_equal(session.state, GameSession.LOST, "loss run %d reaches lost state" % run_index)
	_expect_equal(
		session.failure_reason,
		GameSession.ROAD_MISSING,
		"loss run %d keeps failure reason" % run_index,
	)
	_expect_true(
		session.pop_events().has(GameSession.EVENT_RUN_LOST),
		"loss run %d emits loss event" % run_index,
	)


func _expect_true(value: bool, label: String) -> void:
	_expect_equal(value, true, label)


func _expect_equal(actual: Variant, expected: Variant, label: String) -> void:
	checks += 1
	if actual != expected:
		failures += 1
		push_error("%s | expected=%s actual=%s" % [label, expected, actual])
