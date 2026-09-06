extends TestBase
## G14.2: the same yard at four hours of the one day the case runs over.
## On TestBase since G19.2 (see PoseShot).

const HOURS := ["ch04_flooded"]


func run() -> void:
	suite = "GUN CEKIM"
	min_checks = 1
	for id: String in HOURS:
		var game: Node = load("res://scenes/Main.tscn").instantiate()
		game.variant_id = id
		add_child(game)
		await frames(8)
		# The opening camera sits overhead until the search starts; from up
		# there the sky is not even in frame. Hold it open for the descent.
		game.hud._close_pause()
		game._begin_search()
		await frames(260)
		get_tree().paused = false
		game.hud._close_pause()
		if game.cam != null and game.cam.has_method("snap_to_target"):
			game.cam.snap_to_target()
		game.hud.visible = false
		await frames(6)
		# The background pause re-opens its sheet between the close and the
		# draw on some runs; hide the layer itself, right before the capture.
		if game.hud._pause_layer != null:
			game.hud._pause_layer.visible = false
		await drawn_frame()
		get_viewport().get_texture().get_image().save_png("res://out/day_%s.png" % id)
		print("[cekim] out/day_%s.png yazildi" % id)
		ck("bahce kuruldu", game.model != null)
		game.queue_free()
		await frames(6)
