extends SceneTree


func _initialize() -> void:
	call_deferred("_capture")


func _capture() -> void:
	root.size = Vector2i(405, 720)
	var packed_scene: PackedScene = load("res://game/presentation/main.tscn")
	var scene: Node = packed_scene.instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var output_path := ProjectSettings.globalize_path("res://builds/ui-capture.png")
	var error := image.save_png(output_path)
	if error != OK:
		push_error("Failed to save UI capture: %s" % error)
		quit(1)
		return
	print("UI capture saved: %s" % output_path)
	quit(0)
