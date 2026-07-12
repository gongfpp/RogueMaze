extends Control

const BACKGROUND_TEXTURE: Texture2D = preload("res://assets/art/backgrounds/paper-mechanical-blueprint-v1.png")

const BACKGROUND := Color("101827")
const BOARD_BACKGROUND := Color("18263a")
const GRID_COLOR := Color("30445f")
const ROAD_COLOR := Color("e9b84a")
const BRIDGE_COLOR := Color("74d4c0")
const TEXT_COLOR := Color("dce8f7")
const MUTED_TEXT := Color("8296b3")
const VALID_COLOR := Color(0.2, 0.85, 0.55, 0.22)
const SELECTED_COLOR := Color("f7cf62")
const DANGER_COLOR := Color("ef6a72")

var session := GameSession.new()
var board_rect := Rect2()
var card_rects: Array[Rect2] = []
var rotate_rect := Rect2()
var pause_rect := Rect2()
var restart_rect := Rect2()
var reward_rects: Array[Rect2] = []
var sound_rect := Rect2()
var motion_rect := Rect2()
var safe_rect := Rect2()
var cell_size := 0.0
var dragging_card := false
var drag_position := Vector2.ZERO
var feedback_text := ""
var feedback_remaining := 0.0
var visual_time := 0.0
var placement_pulse_remaining := 0.0
var placement_pulse_cell := Vector2i.ZERO
var audio_cues: AudioCues
var persistence := PersistenceService.new()
var reduced_motion := false


func _ready() -> void:
	persistence.load_all()
	audio_cues = AudioCues.new()
	add_child(audio_cues)
	audio_cues.enabled = persistence.settings.sfx_enabled
	reduced_motion = persistence.settings.reduced_motion
	set_process(true)
	_recalculate_layout()
	queue_redraw()
	if OS.get_cmdline_user_args().has("--smoke"):
		call_deferred("_complete_smoke_test")


func _complete_smoke_test() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	for legal_path in [
		"res://assets/legal/GODOT_LICENSE.txt",
		"res://assets/legal/GODOT_COPYRIGHT.txt",
		"res://assets/legal/CREDITS.txt",
	]:
		if not FileAccess.file_exists(legal_path):
			push_error("Release smoke: missing legal notice %s" % legal_path)
			get_tree().quit(1)
			return
	print("RogueMaze smoke: legal notices ready")
	print("RogueMaze smoke: main scene ready")
	get_tree().quit(0)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and is_inside_tree():
		_recalculate_layout()
		queue_redraw()
	elif what in [NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_WM_WINDOW_FOCUS_OUT]:
		if session != null and session.set_paused(true):
			feedback_text = "Paused while the app is away"
			feedback_remaining = 2.0
		if persistence != null:
			persistence.save_all()
	elif what == NOTIFICATION_WM_GO_BACK_REQUEST and OS.get_name() == "Android":
		if session != null:
			session.set_paused(true)


func _exit_tree() -> void:
	if persistence != null:
		persistence.save_all()


func _process(delta: float) -> void:
	visual_time += delta
	session.update(delta)
	_consume_game_events()
	feedback_remaining = maxf(0.0, feedback_remaining - delta)
	placement_pulse_remaining = maxf(0.0, placement_pulse_remaining - delta)
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("rotate_card"):
		session.rotate_selected()
		audio_cues.play_rotate()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("pause_game"):
		session.toggle_pause()
		get_viewport().set_input_as_handled()
	else:
		for index in GameSession.HAND_SIZE:
			if event.is_action_pressed("select_card_%d" % (index + 1)):
				session.select_card(index)
				get_viewport().set_input_as_handled()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			session.rotate_selected()
			audio_cues.play_rotate()
			accept_event()
		elif event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_begin_press(event.position)
			accept_event()
		elif event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			_end_press(event.position)
			accept_event()
	elif event is InputEventMouseMotion and dragging_card:
		drag_position = event.position
		accept_event()
	elif event is InputEventScreenTouch and event.pressed:
		_begin_press(event.position)
		accept_event()
	elif event is InputEventScreenTouch and not event.pressed:
		_end_press(event.position)
		accept_event()
	elif event is InputEventScreenDrag and dragging_card:
		drag_position = event.position
		accept_event()


func _begin_press(position: Vector2) -> void:
	if session.state == GameSession.REWARD:
		for index in reward_rects.size():
			if reward_rects[index].has_point(position):
				session.choose_reward(index)
				return
	if restart_rect.has_point(position) and session.state in [GameSession.WON, GameSession.LOST]:
		session.reset()
		return
	if pause_rect.has_point(position):
		session.toggle_pause()
		return
	if sound_rect.has_point(position):
		audio_cues.enabled = not audio_cues.enabled
		persistence.settings.sfx_enabled = audio_cues.enabled
		persistence.save_settings()
		if audio_cues.enabled:
			audio_cues.play_rotate()
		return
	if motion_rect.has_point(position):
		reduced_motion = not reduced_motion
		persistence.settings.reduced_motion = reduced_motion
		persistence.save_settings()
		return
	if rotate_rect.has_point(position):
		session.rotate_selected()
		audio_cues.play_rotate()
		return
	for index in card_rects.size():
		if card_rects[index].has_point(position):
			session.select_card(index)
			dragging_card = true
			drag_position = position
			return
	if board_rect.has_point(position):
		var local := position - board_rect.position
		var cell := Vector2i(floori(local.x / cell_size), floori(local.y / cell_size))
		_try_place(cell)


func _end_press(position: Vector2) -> void:
	if dragging_card and board_rect.has_point(position):
		var local := position - board_rect.position
		var cell := Vector2i(floori(local.x / cell_size), floori(local.y / cell_size))
		_try_place(cell)
	dragging_card = false


func _try_place(cell: Vector2i) -> void:
	var result := session.place_selected(cell)
	feedback_text = "Road placed" if result.ok else _failure_label(result.get("reason", &"UNKNOWN"))
	feedback_remaining = 1.35
	if result.ok:
		placement_pulse_cell = cell
		placement_pulse_remaining = 0.0 if reduced_motion else 0.28
		audio_cues.play_place()


func _recalculate_layout() -> void:
	safe_rect = _mobile_safe_rect()
	var padding := clampf(safe_rect.size.x * 0.045, 18.0, 40.0)
	cell_size = floorf(minf(
		(safe_rect.size.x - padding * 2.0) / float(GameSession.BOARD_SIZE.x),
		(safe_rect.size.y * 0.43) / float(GameSession.BOARD_SIZE.y),
	))
	var board_size := Vector2(cell_size * GameSession.BOARD_SIZE.x, cell_size * GameSession.BOARD_SIZE.y)
	board_rect = Rect2(Vector2(
		safe_rect.position.x + (safe_rect.size.x - board_size.x) * 0.5,
		safe_rect.position.y + safe_rect.size.y * 0.17,
	), board_size)

	var card_gap := clampf(safe_rect.size.x * 0.018, 8.0, 16.0)
	var card_width := (safe_rect.size.x - padding * 2.0 - card_gap * 3.0) / 4.0
	var card_height := clampf(safe_rect.size.y * 0.15, 96.0, 128.0)
	var hand_y := maxf(board_rect.end.y + 70.0, safe_rect.end.y - card_height - 24.0)
	hand_y = minf(hand_y, safe_rect.end.y - card_height - 16.0)
	card_rects.clear()
	for index in GameSession.HAND_SIZE:
		card_rects.append(Rect2(
			Vector2(safe_rect.position.x + padding + (card_width + card_gap) * index, hand_y),
			Vector2(card_width, card_height),
		))
	var left := safe_rect.position.x + padding
	rotate_rect = Rect2(Vector2(left, hand_y - 54.0), Vector2(150.0, 42.0))
	sound_rect = Rect2(Vector2(left + 160.0, hand_y - 54.0), Vector2(104.0, 42.0))
	motion_rect = Rect2(Vector2(left + 274.0, hand_y - 54.0), Vector2(maxf(92.0, safe_rect.size.x - padding * 2.0 - 274.0), 42.0))
	pause_rect = Rect2(Vector2(safe_rect.end.x - padding - 116.0, safe_rect.position.y + 34.0), Vector2(116.0, 46.0))
	restart_rect = Rect2(Vector2(safe_rect.position.x + (safe_rect.size.x - 220.0) * 0.5, safe_rect.position.y + safe_rect.size.y * 0.58), Vector2(220.0, 58.0))
	reward_rects.clear()
	var reward_gap := 10.0
	var reward_width := (safe_rect.size.x - padding * 2.0 - reward_gap * 2.0) / 3.0
	for index in 3:
		reward_rects.append(Rect2(
			Vector2(left + index * (reward_width + reward_gap), safe_rect.position.y + safe_rect.size.y * 0.49),
			Vector2(reward_width, 116.0),
		))


func _mobile_safe_rect() -> Rect2:
	if OS.get_name() not in ["Android", "iOS"]:
		return Rect2(Vector2.ZERO, size)
	var window_size := Vector2(DisplayServer.window_get_size())
	if window_size.x <= 0.0 or window_size.y <= 0.0:
		return Rect2(Vector2.ZERO, size)
	var platform_safe := DisplayServer.get_display_safe_area()
	if platform_safe.size.x <= 0 or platform_safe.size.y <= 0:
		return Rect2(Vector2.ZERO, size)
	var scale := Vector2(size.x / window_size.x, size.y / window_size.y)
	return Rect2(Vector2(platform_safe.position) * scale, Vector2(platform_safe.size) * scale)


func _draw() -> void:
	_draw_background()
	_draw_header()
	_draw_board()
	_draw_tutorial_hint()
	_draw_hand()
	_draw_dragged_card()
	_draw_state_overlay()


func _draw_header() -> void:
	_draw_text(safe_rect.position + Vector2(28.0, 56.0), "ROGUE MAZE", 30, SELECTED_COLOR)
	var node_title: String = session.content.node(session.node_index).get("title", "")
	var status := _node_instruction()
	if session.countdown > 0.0:
		status = "%s · START %.1f" % [node_title, session.countdown]
	elif session.runner.status == RunnerState.WAITING:
		status = "ROAD MISSING · %.1fs" % maxf(0.0, session.runner.blocked_remaining)
	if feedback_remaining > 0.0:
		status = feedback_text
	_draw_text(Vector2(28.0, 91.0), status, 17, MUTED_TEXT)
	_draw_text(
		Vector2(board_rect.position.x, board_rect.position.y - 10.0),
		"NODE %d/%d  ·  HP %d/%d" % [
			session.node_index + 1,
			GameSession.NODE_COUNT,
			session.health,
			session.max_health,
		],
		13,
		TEXT_COLOR,
	)
	_draw_text_right(
		Vector2(board_rect.end.x, board_rect.position.y - 10.0),
		"BEST %d/%d · W %d" % [
			persistence.progress.best_node,
			GameSession.NODE_COUNT,
			persistence.progress.expeditions_won,
		],
		13,
		MUTED_TEXT,
	)
	_draw_button(pause_rect, "RESUME" if session.paused else "PAUSE", false)


func _node_instruction() -> String:
	match session.node_index:
		0: return "BUILD BEFORE THE RUNNER"
		1: return "RED SPIKES HURT · GO ABOVE"
		2: return "TEAL + HEALS · STEAM CYCLES"
		3: return "ARMOR + STOPS ONE ROCK"
		4: return "FINAL · COMBINE YOUR TOOLS"
		_: return "BUILD THE ROAD"


func _draw_board() -> void:
	draw_rect(board_rect, BOARD_BACKGROUND, true)
	var selected := session.selected_definition()
	for y in GameSession.BOARD_SIZE.y:
		for x in GameSession.BOARD_SIZE.x:
			var cell := Vector2i(x, y)
			var rect := _cell_rect(cell)
			if session.board.road_at(cell).is_empty():
				var validation := session.board.validate_placement(
					selected,
					cell,
					session.selected_quarter_turns,
				)
				if validation.ok:
					draw_rect(rect.grow(-2.0), VALID_COLOR, true)
			draw_rect(rect, GRID_COLOR, false, 1.0)

	for cell in session.board.roads:
		_draw_road(cell, session.board.roads[cell], ROAD_COLOR)
	_draw_hazards()
	if placement_pulse_remaining > 0.0:
		var pulse_progress := 1.0 - placement_pulse_remaining / 0.28
		var pulse_rect := _cell_rect(placement_pulse_cell).grow(-4.0 - pulse_progress * 6.0)
		draw_rect(pulse_rect, Color(SELECTED_COLOR, 0.75 * (1.0 - pulse_progress)), false, 3.0)

	var finish_center := _cell_center(GameSession.FINISH)
	draw_line(finish_center + Vector2(0, 18), finish_center + Vector2(0, -22), TEXT_COLOR, 3.0)
	draw_colored_polygon(PackedVector2Array([
		finish_center + Vector2(2, -22),
		finish_center + Vector2(24, -14),
		finish_center + Vector2(2, -6),
	]), SELECTED_COLOR)

	var runner_position := board_rect.position + (session.runner.display_position() + Vector2(0.5, 0.5)) * cell_size
	if session.runner.status == RunnerState.RUNNING and not reduced_motion:
		runner_position.y += sin(visual_time * 11.0) * 2.2
	draw_circle(runner_position, cell_size * 0.18, Color("f2f5f9"))
	draw_circle(runner_position + Vector2(cell_size * 0.06, -cell_size * 0.035), cell_size * 0.025, BACKGROUND)

	if dragging_card and board_rect.has_point(drag_position):
		var local := drag_position - board_rect.position
		var preview_cell := Vector2i(floori(local.x / cell_size), floori(local.y / cell_size))
		var validation := session.validate_selected(preview_cell)
		var preview_color := VALID_COLOR if validation.ok else Color(0.94, 0.25, 0.32, 0.28)
		draw_rect(_cell_rect(preview_cell).grow(-2.0), preview_color, true)
		if validation.ok:
			_draw_road(preview_cell, {
				"definition": session.selected_definition(),
				"ports": session.selected_definition().rotated_ports(session.selected_quarter_turns),
			}, Color(ROAD_COLOR, 0.65))


func _draw_hand() -> void:
	_draw_button(rotate_rect, "ROTATE  R", false)
	_draw_button(sound_rect, "SFX ON" if audio_cues.enabled else "SFX OFF", false)
	_draw_button(motion_rect, "FX LOW" if reduced_motion else "FX FULL", false)
	for index in card_rects.size():
		var rect := card_rects[index]
		var card: CardState = session.hand[index]
		var selected := index == session.selected_card_index
		if selected and not reduced_motion:
			rect = Rect2(rect.position + Vector2(0, -7), rect.size)
		var fill := Color("26374f") if not selected else Color("44506a")
		draw_style_box(_rounded_box(fill, SELECTED_COLOR if selected else GRID_COLOR, 3.0), rect)
		var definition := RoadCatalog.get_definition(card.road_id)
		var turns := session.selected_quarter_turns if selected else 0
		_draw_card_road(rect, definition, turns, BRIDGE_COLOR if definition.id == RoadCatalog.BRIDGE else ROAD_COLOR)
		_draw_text(rect.position + Vector2(10, rect.size.y - 13), _road_label(definition.id) + card.level_suffix(), 13, TEXT_COLOR)
		if card.level > 1:
			_draw_text(rect.position + Vector2(8, 18), "ARMOR", 10, SELECTED_COLOR)
		_draw_text(rect.position + Vector2(rect.size.x - 22, 22), str(index + 1), 12, MUTED_TEXT)


func _draw_state_overlay() -> void:
	if session.paused and session.state == GameSession.PLAYING:
		_draw_center_message("PAUSED", "Tap pause or press Space")
		_draw_credits_note()
	elif session.state == GameSession.REWARD:
		_draw_reward_overlay()
	elif session.state == GameSession.WON:
		_draw_center_message(
			"EXPEDITION COMPLETE",
			"All three nodes cleared · Wins %d" % persistence.progress.expeditions_won,
		)
		_draw_button(restart_rect, "PLAY AGAIN", true)
	elif session.state == GameSession.LOST:
		_draw_center_message("RUN FAILED", _failure_summary())
		_draw_button(restart_rect, "TRY AGAIN", true)


func _draw_dragged_card() -> void:
	if not dragging_card or board_rect.has_point(drag_position):
		return
	var ghost := Rect2(drag_position - Vector2(42, 48), Vector2(84, 96))
	draw_style_box(_rounded_box(Color(0.15, 0.22, 0.32, 0.88), SELECTED_COLOR, 2.0), ghost)
	_draw_card_road(
		ghost,
		session.selected_definition(),
		session.selected_quarter_turns,
		ROAD_COLOR,
	)


func _draw_tutorial_hint() -> void:
	if session.node_index != 0 or session.state != GameSession.PLAYING or session.board.roads.size() > 1:
		return
	var rect := Rect2(Vector2(18, board_rect.end.y + 36), Vector2(size.x - 36, 106))
	draw_style_box(_rounded_box(Color(0.09, 0.14, 0.21, 0.92), GRID_COLOR, 1.0), rect)
	_draw_text(rect.position + Vector2(16, 28), "1  Select or drag a road card", 15, TEXT_COLOR)
	_draw_text(rect.position + Vector2(16, 54), "2  Green cells are legal", 15, Color("78dca5"))
	_draw_text(rect.position + Vector2(16, 80), "3  Tap ROTATE or press R", 15, TEXT_COLOR)


func _draw_hazards() -> void:
	for position in session.hazards:
		var hazard: Dictionary = session.hazards[position]
		var center := _cell_center(position)
		if hazard.type == GameSession.SPIKES:
			var spike_color := Color("74424b") if hazard.spent else DANGER_COLOR
			for offset in [-12.0, 0.0, 12.0]:
				draw_colored_polygon(PackedVector2Array([
					center + Vector2(offset - 6.0, 15.0),
					center + Vector2(offset, -4.0),
					center + Vector2(offset + 6.0, 15.0),
				]), spike_color)
		elif hazard.type == GameSession.FALLING_ROCK:
			if hazard.get("neutralized", false):
				draw_circle(center, cell_size * 0.18, Color("446077"), false, 3.0)
				_draw_text_centered(center + Vector2(0, 4), "OK", 10, SELECTED_COLOR)
			elif hazard.triggered:
				draw_circle(center, cell_size * 0.22, Color("3a2630"))
				draw_line(center + Vector2(-8, -8), center + Vector2(8, 8), DANGER_COLOR, 3.0)
				draw_line(center + Vector2(8, -8), center + Vector2(-8, 8), DANGER_COLOR, 3.0)
			else:
				var rock_scale := 1.0 if reduced_motion else 1.0 + sin(visual_time * 5.0) * 0.06
				draw_circle(center + Vector2(0, -cell_size * 0.22), cell_size * 0.16 * rock_scale, Color("b9825a"))
				_draw_text_centered(center + Vector2(0, cell_size * 0.36), "%.0f" % ceilf(hazard.timer), 12, DANGER_COLOR)
		elif hazard.type == GameSession.STEAM_VENT:
			var active := session.is_steam_active(hazard)
			var steam_color := DANGER_COLOR if active else Color("6fa8b7")
			draw_arc(center, cell_size * 0.2, 0.0, TAU, 18, steam_color, 3.0, true)
			if active:
				for offset in [-10.0, 0.0, 10.0]:
					draw_line(center + Vector2(offset, 7), center + Vector2(offset + 4, -15), steam_color, 3.0, true)
			_draw_text_centered(center + Vector2(0, cell_size * 0.37), "%.1f" % session.steam_time_to_change(hazard), 10, steam_color)
		elif hazard.type == GameSession.REPAIR_PAD:
			var repair_color := Color("48606e") if hazard.spent else BRIDGE_COLOR
			draw_circle(center, cell_size * 0.2, repair_color, false, 3.0)
			draw_line(center + Vector2(-8, 0), center + Vector2(8, 0), repair_color, 4.0, true)
			draw_line(center + Vector2(0, -8), center + Vector2(0, 8), repair_color, 4.0, true)


func _draw_reward_overlay() -> void:
	var overlay := Rect2(Vector2(0, size.y * 0.34), Vector2(size.x, size.y * 0.38))
	draw_rect(overlay, Color(0.03, 0.05, 0.08, 0.96), true)
	_draw_text_centered(Vector2(size.x * 0.5, overlay.position.y + 46), "TUNE YOUR DECK", 28, SELECTED_COLOR)
	_draw_text_centered(Vector2(size.x * 0.5, overlay.position.y + 75), "Add, armor, or remove one road", 14, TEXT_COLOR)
	for index in reward_rects.size():
		var rect := reward_rects[index]
		var option: Dictionary = session.reward_options[index]
		var road_id: StringName = option.road_id
		var definition := RoadCatalog.get_definition(road_id)
		draw_style_box(_rounded_box(Color("26374f"), GRID_COLOR, 2.0), rect)
		_draw_card_road(rect, definition, 0, BRIDGE_COLOR if road_id == RoadCatalog.BRIDGE else ROAD_COLOR)
		_draw_text_centered(rect.position + Vector2(rect.size.x * 0.5, 18), option.title, 11, SELECTED_COLOR)
		var suffix := "+" if option.type == GameSession.REWARD_UPGRADE else ""
		_draw_text_centered(rect.position + Vector2(rect.size.x * 0.5, rect.size.y - 14), _road_label(road_id) + suffix, 11, TEXT_COLOR)


func _draw_center_message(title: String, subtitle: String) -> void:
	var overlay := Rect2(Vector2(0, size.y * 0.38), Vector2(size.x, size.y * 0.28))
	draw_rect(overlay, Color(0.03, 0.05, 0.08, 0.92), true)
	_draw_text_centered(Vector2(size.x * 0.5, overlay.position.y + 70), title, 34, SELECTED_COLOR)
	_draw_text_centered(Vector2(size.x * 0.5, overlay.position.y + 108), subtitle, 17, TEXT_COLOR)


func _draw_credits_note() -> void:
	var center_x := safe_rect.position.x + safe_rect.size.x * 0.5
	var y := safe_rect.position.y + safe_rect.size.y * 0.38 + 142.0
	_draw_text_centered(Vector2(center_x, y), "Built with Godot Engine 4.7 · MIT", 12, MUTED_TEXT)
	_draw_text_centered(Vector2(center_x, y + 20.0), "Full notices are included in the game package", 11, MUTED_TEXT)


func _draw_road(cell: Vector2i, road: Dictionary, color: Color) -> void:
	var center := _cell_center(cell)
	var road_color := BRIDGE_COLOR if road.definition.id == RoadCatalog.BRIDGE else color
	for direction in road.ports:
		var vector := DirectionRules.vector(direction)
		var offset := Vector2(vector.x, vector.y) * cell_size * 0.5
		draw_line(center, center + offset, road_color, maxf(5.0, cell_size * 0.14), true)
	draw_circle(center, maxf(4.0, cell_size * 0.1), road_color)
	if int(road.get("level", 1)) > 1:
		draw_arc(center, cell_size * 0.24, 0.0, TAU, 20, SELECTED_COLOR, 2.0, true)


func _draw_card_road(rect: Rect2, definition: RoadDefinition, turns: int, color: Color) -> void:
	var center := rect.position + Vector2(rect.size.x * 0.5, rect.size.y * 0.43)
	var length := minf(rect.size.x, rect.size.y) * 0.32
	for direction in definition.rotated_ports(turns):
		var vector := DirectionRules.vector(direction)
		draw_line(center, center + Vector2(vector.x, vector.y) * length, color, 7.0, true)
	draw_circle(center, 5.0, color)


func _draw_button(rect: Rect2, label: String, prominent: bool) -> void:
	var fill := Color("d79d32") if prominent else Color("26374f")
	var text_color := BACKGROUND if prominent else TEXT_COLOR
	draw_style_box(_rounded_box(fill, SELECTED_COLOR if prominent else GRID_COLOR, 2.0), rect)
	var baseline := rect.position + Vector2(rect.size.x * 0.5, rect.size.y * 0.5 + 6.0)
	_draw_text_centered(baseline, label, 15, text_color)


func _rounded_box(fill: Color, border: Color, width: float) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(int(width))
	box.set_corner_radius_all(10)
	return box


func _cell_rect(cell: Vector2i) -> Rect2:
	return Rect2(board_rect.position + Vector2(cell) * cell_size, Vector2.ONE * cell_size)


func _cell_center(cell: Vector2i) -> Vector2:
	return board_rect.position + (Vector2(cell) + Vector2(0.5, 0.5)) * cell_size


func _road_label(road_id: StringName) -> String:
	return RoadCatalog.get_label(road_id)


func _failure_label(reason: StringName) -> String:
	match reason:
		BoardState.OUT_OF_BOUNDS: return "Outside the board"
		BoardState.OCCUPIED: return "That cell is occupied"
		BoardState.PORT_MISMATCH: return "Road ports do not match"
		BoardState.ISOLATED: return "Connect to an existing road"
		_: return "Cannot place road now"


func _failure_summary() -> String:
	match session.failure_reason:
		GameSession.ROCK_HIT: return "A falling rock destroyed the route"
		GameSession.NO_HEALTH: return "The runner lost all health"
		GameSession.ROAD_MISSING: return "The runner waited too long for a road"
		_: return "Review the route and try again"


func _draw_text(position: Vector2, text: String, font_size: int, color: Color) -> void:
	draw_string(get_theme_default_font(), position, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


func _draw_text_centered(position: Vector2, text: String, font_size: int, color: Color) -> void:
	var width := get_theme_default_font().get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	_draw_text(position - Vector2(width * 0.5, 0), text, font_size, color)


func _draw_text_right(position: Vector2, text: String, font_size: int, color: Color) -> void:
	var width := get_theme_default_font().get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	_draw_text(position - Vector2(width, 0), text, font_size, color)


func _draw_background() -> void:
	var texture_size := BACKGROUND_TEXTURE.get_size()
	var target_aspect := size.x / maxf(size.y, 1.0)
	var source_width := texture_size.y * target_aspect
	var source_rect := Rect2(
		Vector2((texture_size.x - source_width) * 0.5, 0.0),
		Vector2(source_width, texture_size.y),
	)
	draw_texture_rect_region(BACKGROUND_TEXTURE, Rect2(Vector2.ZERO, size), source_rect, Color(0.72, 0.75, 0.80, 1.0))
	draw_rect(Rect2(Vector2.ZERO, size), Color(BACKGROUND, 0.78), true)


func _consume_game_events() -> void:
	for event in session.pop_events():
		match event:
			GameSession.EVENT_NODE_CLEARED:
				persistence.record_node_cleared(session.node_index + 1)
				audio_cues.play_reward()
			GameSession.EVENT_EXPEDITION_WON:
				persistence.record_expedition_win()
				audio_cues.play_win()
			GameSession.EVENT_RUN_LOST:
				audio_cues.play_fail()
			GameSession.EVENT_SPIKE_HIT:
				audio_cues.play_damage()
			GameSession.EVENT_ROCK_FELL:
				audio_cues.play_rock()
			GameSession.EVENT_ROAD_SAVED:
				feedback_text = "Armor absorbed the falling rock"
				feedback_remaining = 2.2
				audio_cues.play_reward()
			GameSession.EVENT_STEAM_HIT:
				feedback_text = "Steam vent burned 1 HP"
				feedback_remaining = 2.0
				audio_cues.play_damage()
			GameSession.EVENT_REPAIRED:
				feedback_text = "Repair pad restored 1 HP"
				feedback_remaining = 2.0
				audio_cues.play_reward()
