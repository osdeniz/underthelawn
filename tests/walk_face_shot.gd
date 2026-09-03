extends Node
## G14.26: what the player actually sees when they hold "forward" on foot.

func _ready() -> void:
	GameState.set_setting("meta", "orientation_done", true)
	for key: String in ["money", "food"]:
		GameState.set_setting("tips", key, true)
	var game: Node = load("res://scenes/Main.tscn").instantiate()
	game.variant_id = "ch01_aldridge"
	add_child(game)
	for _i in 10:
		await get_tree().process_frame
	get_tree().paused = false
	game.hud._close_pause()
	game._begin_search()
	for _i in 16:
		get_tree().paused = false
		await get_tree().process_frame

	game.toggle_walk()
	for _i in 6:
		get_tree().paused = false
		await get_tree().process_frame
	var walker: Walker = game.get_node("Walker")
	var from := walker.position
	Input.action_press("move_forward")
	var spent := 0.0
	while spent < 1.2:
		get_tree().paused = false
		await get_tree().process_frame
		spent += get_process_delta_time()
	Input.action_release("move_forward")
	var moved := walker.position - from
	var facing := -walker.global_transform.basis.z
	print("  [olcum] ileri tusu -> hareket %v" % Vector2(moved.x, moved.z).normalized())
	print("  [olcum] bakis %v  sapma %.0f derece" % [Vector2(facing.x, facing.z).normalized(),
		rad_to_deg(absf(Vector2(facing.x, facing.z).angle_to(Vector2(moved.x, moved.z))))])
	(game.get_node("UI") as CanvasLayer).visible = false
	for _i in 6:
		get_tree().paused = false
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://out/walk_face.png")
	print("[cekim] out/walk_face.png yazildi")
	get_tree().quit()
