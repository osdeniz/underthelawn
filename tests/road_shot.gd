extends Node
## G15.1: the prologue road, from the start line and from halfway.

func _ready() -> void:
	GameState.set_setting("meta", "orientation_done", true)
	GameState.set_setting("story", "prologue_done", false)
	Garage.trial = true
	var game: Node = load("res://scenes/Main.tscn").instantiate()
	game.variant_id = GameConfig.PROLOGUE_ID
	add_child(game)
	for _i in 10:
		get_tree().paused = false
		await get_tree().process_frame
	get_tree().paused = false
	game.hud._close_pause()
	game._begin_search()
	for _i in 20:
		get_tree().paused = false
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://out/road_start.png")

	# From the ground, near the end: what the player sees when the gate is the
	# next thing they reach. This is the framing that decides whether the goal
	# reads, and the plan view above cannot answer it.
	(game.get_node("UI") as CanvasLayer).visible = false
	var eye := Camera3D.new()
	eye.fov = GameConfig.CAMERA_FOV
	eye.keep_aspect = Camera3D.KEEP_WIDTH
	eye.position = Vector3(0.0, 4.2, -GameConfig.HALF_Z + 8.0)
	eye.current = true
	game.add_child(eye)
	eye.look_at(Vector3(0.0, 1.2, -GameConfig.HALF_Z - 1.0))
	for _i in 8:
		get_tree().paused = false
		await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://out/road_goal.png")
	eye.queue_free()

	# And from above, so the shape of the level is readable in one frame.
	var above := Camera3D.new()
	above.fov = 58.0
	above.keep_aspect = Camera3D.KEEP_WIDTH
	above.position = Vector3(0.0, 30.0, 6.0)
	above.rotation_degrees = Vector3(-72.0, 0.0, 0.0)
	above.current = true
	game.add_child(above)
	for _i in 8:
		get_tree().paused = false
		await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://out/road_plan.png")
	print("[cekim] out/road_start.png + road_plan.png yazildi")
	Garage.trial = false
	get_tree().quit()
