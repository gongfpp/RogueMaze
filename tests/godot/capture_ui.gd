extends SceneTree


func _initialize() -> void:
	call_deferred("_capture")


func _capture() -> void:
	root.size = Vector2i(405, 720)
	var packed_scene: PackedScene = load("res://game/presentation/main.tscn")
	var scene: Control = packed_scene.instantiate()
	root.add_child(scene)
	await process_frame

	var mode := "start"
	var arguments := OS.get_cmdline_user_args() + OS.get_cmdline_args()
	for candidate in ["reward", "hazards", "pause", "won", "lost", "start"]:
		if arguments.has(candidate):
			mode = candidate
			break
	var session: GameSession = scene.get("session")
	match mode:
		"reward":
			session.state = GameSession.REWARD
			session._build_reward_options([RoadCatalog.BRIDGE, RoadCatalog.STRAIGHT, RoadCatalog.UP_RAMP])
		"hazards":
			session.node_index = 2
			session._start_node()
			session.countdown = 0.0
		"pause":
			session.set_paused(true)
		"won":
			session.elapsed_seconds = 137.0
			session.roads_placed = 35
			session.invalid_placements = 3
			session.damage_taken = 2
			session.health_recovered = 1
			session.rewards_added = 2
			session.rewards_upgraded = 1
			session.rewards_removed = 1
			session.state = GameSession.WON
		"lost":
			session.elapsed_seconds = 48.0
			session.roads_placed = 9
			session.invalid_placements = 4
			session.damage_taken = 2
			session.failure_reason = GameSession.ROAD_MISSING
			session.state = GameSession.LOST
		"start":
			pass
		_:
			push_error("Unknown capture mode: %s" % mode)
			quit(2)
			return
	scene.queue_redraw()
	await _save_capture("ui-%s.png" % mode)
	quit(0)


func _save_capture(file_name: String) -> void:
	# Give the background texture and procedural draw pass time to settle on slower drivers.
	for frame in 16:
		await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var output_path := ProjectSettings.globalize_path("res://builds/%s" % file_name)
	var error := image.save_png(output_path)
	if error != OK:
		push_error("Failed to save UI capture: %s" % error)
		quit(1)
		return
	print("UI capture saved: %s" % output_path)
