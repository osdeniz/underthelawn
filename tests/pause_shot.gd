extends Node
## G14.9: the pause sheet, with the way out of the game on it.

func _ready() -> void:
	GameState.set_setting("meta", "orientation_done", true)
	var game: Node = load("res://scenes/Main.tscn").instantiate()
	game.variant_id = "ch01_aldridge"
	add_child(game)
	for _i in 24:
		await get_tree().process_frame
	game.hud._open_pause()
	for _i in 10:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://out/pause.png")
	get_tree().paused = false
	get_tree().quit()
