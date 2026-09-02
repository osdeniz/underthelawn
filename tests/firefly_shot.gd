extends Node
## G14.15: the sparks, close enough to see their shape.

func _ready() -> void:
	GameState.set_setting("meta", "orientation_done", true)
	SkyTime.set_mode(GameConfig.SKY_MODE_NIGHT)
	var game: Node = load("res://scenes/Main.tscn").instantiate()
	game.variant_id = "ch01_aldridge"
	add_child(game)
	for _i in 10:
		await get_tree().process_frame
	get_tree().paused = false
	game.hud._close_pause()
	game._begin_search()
	for _i in 150:
		get_tree().paused = false
		await get_tree().process_frame
	get_tree().paused = false
	game.hud._close_pause()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://out/fireflies.png")
	SkyTime.set_mode(GameConfig.SKY_MODE_AUTO)
	get_tree().quit()
