extends Node
## G14.1: the missing poster with its new caption line.

func _ready() -> void:
	GameState.set_setting("meta", "orientation_done", true)
	var game: Node = load("res://scenes/Main.tscn").instantiate()
	add_child(game)
	for _i in 30:
		await get_tree().process_frame
	get_tree().paused = false
	game.hud._close_pause()
	game.hud.set_poster_visible(true)
	for _i in 10:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://out/poster.png")
	get_tree().quit()
