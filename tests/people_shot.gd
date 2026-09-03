extends Node
## G15.6: the man on the ridge from the start line, and the settler by the barn.
func _ready() -> void:
	GameState.set_setting("meta", "orientation_done", true)
	for key: String in ["money", "food"]:
		GameState.set_setting("tips", key, true)
	await _shot("ch14_listening_post", "res://out/observer.png", false)
	Settlers.reset()
	Settlers.accept(str((Settlers.all()[0] as Dictionary)["id"]))
	await _shot("harvest_field", "res://out/harvest_settler.png", true)
	Settlers.reset()
	get_tree().quit()


func _shot(chapter: String, path: String, aim_barn: bool) -> void:
	var game: Node = load("res://scenes/Main.tscn").instantiate()
	game.variant_id = chapter
	add_child(game)
	for _i in 10:
		get_tree().paused = false
		await get_tree().process_frame
	get_tree().paused = false
	game.hud._close_pause()
	game._begin_search()
	for _i in 30:
		get_tree().paused = false
		await get_tree().process_frame
	(game.get_node("UI") as CanvasLayer).visible = false
	# The player's own view, not the opening bird's-eye: the chase offsets, from
	# a spot on the lawn, looking north at the thing in question.
	var eye := Camera3D.new()
	eye.fov = GameConfig.CAMERA_FOV
	eye.keep_aspect = Camera3D.KEEP_WIDTH
	eye.current = true
	game.add_child(eye)
	if aim_barn:
		# Close and a little high, or the foreground crop hides everything below
		# head height at the target distance.
		var target := Vector3(7.6, 1.0, GameConfig.fence_north_z() + 0.5)
		eye.position = target + Vector3(0.0, 3.0, 4.2)
		eye.look_at(target)
	else:
		var ridge: Node3D = game.find_child("Observer", true, false)
		var target := ridge.global_position + Vector3(0.0, 1.0, 0.0) if ridge != null \
			else Vector3(0.0, 1.0, -GameConfig.HALF_Z)
		eye.position = Vector3(0.0, 4.2, -GameConfig.HALF_Z + 9.0)
		eye.look_at(target)
	for _i in 8:
		get_tree().paused = false
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	print("[cekim] %s yazildi" % path)
	game.queue_free()
	for _i in 6:
		get_tree().paused = false
		await get_tree().process_frame
