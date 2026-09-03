extends Node
## G14.27: the dog's beat, at both ends and the middle, from in front of the
## porch — because the first line it walked went straight THROUGH the porch.

func _ready() -> void:
	GameState.set_setting("meta", "orientation_done", true)
	for key: String in ["money", "food"]:
		GameState.set_setting("tips", key, true)
	var game: Node = load("res://scenes/Main.tscn").instantiate()
	game.variant_id = "ch01_aldridge"
	add_child(game)
	for _i in 8:
		await get_tree().process_frame
	get_tree().paused = false
	game.hud._close_pause()
	game._begin_search()
	for _i in 14:
		get_tree().paused = false
		await get_tree().process_frame

	var animals := game._animals as Animals
	var dog_entry := {}
	for entry: Dictionary in animals._entries:
		if int(entry["kind"]) == Animals.Kind.DOG:
			dog_entry = entry
	var dog := dog_entry["node"] as Node3D

	(game.get_node("UI") as CanvasLayer).visible = false
	var cam := Camera3D.new()
	cam.fov = 42.0
	cam.keep_aspect = Camera3D.KEEP_WIDTH
	cam.position = Vector3(4.6, 3.0, -4.4)
	cam.current = true
	game.add_child(cam)
	cam.look_at(Vector3(4.6, 0.45, Animals.dog_z()))

	# Out (+x), the far end, and back (-x). Phase is stepped by hand and then
	# a few frames are let run, so the facing comes from the movement the tick
	# actually sees rather than from anything set here.
	var frames := {"a": 0.20, "b": 0.48, "c": 0.80}
	for key: String in frames:
		dog_entry["phase"] = frames[key]
		for _i in 6:
			get_tree().paused = false
			await get_tree().process_frame
		var facing := -dog.global_transform.basis.z
		print("  [olcum] %s x=%.2f z=%.2f bakis=(%.2f, %.2f)" % [key,
			dog.position.x, dog.position.z, facing.x, facing.z])
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://out/dog_%s.png" % key)
	print("[cekim] out/dog_a|b|c.png yazildi")
	get_tree().quit()
