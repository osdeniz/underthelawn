extends Node
## G14.2: the same yard at four hours of the one day the case runs over.

const HOURS := ["ch04_flooded"]


func _ready() -> void:
	GameState.set_setting("meta", "orientation_done", true)
	for id: String in HOURS:
		var game: Node = load("res://scenes/Main.tscn").instantiate()
		game.variant_id = id
		add_child(game)
		for _i in 8:
			await get_tree().process_frame
		# The opening camera sits overhead until the search starts; from up
		# there the sky is not even in frame.
		# A headless-ish window has no focus, so the game pauses itself (G14.1)
		# and the camera never descends. Hold it open for the whole descent.
		get_tree().paused = false
		game.hud._close_pause()
		game._begin_search()
		for _i in 260:
			get_tree().paused = false
			await get_tree().process_frame
		game.hud.visible = false
		for _i in 6:
			get_tree().paused = false
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://out/day_%s.png" % id)
		game.queue_free()
		for _i in 6:
			await get_tree().process_frame
	get_tree().quit()
