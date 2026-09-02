extends Node
## G14.16: down off the tractor, standing in the grass beside it.

func _ready() -> void:
	GameState.set_setting("meta", "orientation_done", true)
	SkyTime.set_mode(GameConfig.SKY_MODE_DAY)
	var game: Node = load("res://scenes/Main.tscn").instantiate()
	game.variant_id = "ch01_aldridge"
	add_child(game)
	for _i in 12:
		await get_tree().process_frame
	get_tree().paused = false
	game.hud._close_pause()
	game.select_mower(GameConfig.MOWER_TRACTOR)
	game._begin_search()
	for _i in 120:
		get_tree().paused = false
		await get_tree().process_frame
	game.toggle_walk()
	await get_tree().process_frame
	# Walk a few paces off, so the shot shows a person IN the grass rather than
	# a person standing on the machine they just left.
	var walker: Walker = game.get_node("Walker")
	walker.position += Vector3(2.6, 0.0, 2.2)
	for _i in 90:
		get_tree().paused = false
		await get_tree().process_frame
	get_tree().paused = false
	game.hud._close_pause()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://out/walk.png")
	SkyTime.set_mode(GameConfig.SKY_MODE_AUTO)
	get_tree().quit()
