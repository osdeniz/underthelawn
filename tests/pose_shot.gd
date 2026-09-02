extends Node
## G14.18: the riding poses, after the figure was reshaped.
##
## The arms got longer and the torso changed shape, and both poses put the
## hands on something — a handlebar and a steering wheel. This is the check
## that they still reach it and do not go through it.

func _ready() -> void:
	GameState.set_setting("meta", "orientation_done", true)
	SkyTime.set_mode(GameConfig.SKY_MODE_DAY)
	for index: int in [GameConfig.MOWER_TRACTOR]:
		var game: Node = load("res://scenes/Main.tscn").instantiate()
		game.variant_id = "ch01_aldridge"
		add_child(game)
		for _i in 12:
			await get_tree().process_frame
		get_tree().paused = false
		game.hud._close_pause()
		game.select_mower(index)
		game._begin_search()
		for _i in 130:
			get_tree().paused = false
			await get_tree().process_frame
		get_tree().paused = false
		game.hud._close_pause()
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(
			"res://out/pose_%d.png" % index)
		game.queue_free()
		for _i in 6:
			await get_tree().process_frame
	SkyTime.set_mode(GameConfig.SKY_MODE_AUTO)
	get_tree().quit()
