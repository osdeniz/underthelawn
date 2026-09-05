extends TestBase
## G15.6: the man on the ridge from the start line, and the settler by the barn.
## On TestBase since G19.2 (see PoseShot).

func run() -> void:
	suite = "INSAN CEKIM"
	min_checks = 1
	for key: String in ["money", "food"]:
		GameState.set_setting("tips", key, true)
	await _shot("ch14_listening_post", "res://out/observer.png", false)
	Settlers.reset()
	Settlers.accept(str((Settlers.all()[0] as Dictionary)["id"]))
	await _shot("harvest_field", "res://out/harvest_settler.png", true)
	Settlers.reset()


func _shot(chapter: String, path: String, aim_barn: bool) -> void:
	var game: Node = load("res://scenes/Main.tscn").instantiate()
	game.variant_id = chapter
	add_child(game)
	await frames(10)
	game.hud._close_pause()
	game._begin_search()
	await frames(30)
	(game.get_node("UI") as CanvasLayer).visible = false
	# The player's own view, not the opening bird's-eye: the chase offsets, from
	# a spot on the lawn, looking north at the thing in question.
	var eye := Camera3D.new()
	eye.fov = GameConfig.CAMERA_FOV
	eye.keep_aspect = Camera3D.KEEP_WIDTH
	eye.current = true
	game.add_child(eye)
	if aim_barn:
		var target := Vector3(7.6, 1.0, GameConfig.fence_north_z() + 0.5)
		eye.position = target + Vector3(0.0, 3.0, 4.2)
		eye.look_at(target)
	else:
		var ridge: Node3D = game.find_child("Observer", true, false)
		var target := ridge.global_position + Vector3(0.0, 1.0, 0.0) if ridge != null \
			else Vector3(0.0, 1.0, -GameConfig.HALF_Z)
		eye.position = Vector3(0.0, 4.2, -GameConfig.HALF_Z + 9.0)
		eye.look_at(target)
	await frames(8)
	await drawn_frame()
	get_viewport().get_texture().get_image().save_png(path)
	print("[cekim] %s yazildi" % path)
	ck("sahne kuruldu: %s" % chapter, game.model != null)
	game.queue_free()
	await frames(6)
