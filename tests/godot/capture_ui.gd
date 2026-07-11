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
	var user_args := OS.get_cmdline_user_args()
	if not user_args.is_empty():
		mode = user_args[0]
	var session: GameSession = scene.get("session")
	match mode:
		"reward":
			session.state = GameSession.REWARD
			session._build_reward_options([RoadCatalog.BRIDGE, RoadCatalog.STRAIGHT, RoadCatalog.UP_RAMP])
		"hazards":
			session.node_index = 2
			session._start_node()
			session.countdown = 0.0
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
	for frame in 8:
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
