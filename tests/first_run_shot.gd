extends Node
## G15: the orientation sheet as the player meets it.

func _ready() -> void:
	GameState.set_setting("meta", "orientation_done", false)
	var game: Node = load("res://scenes/Main.tscn").instantiate()
	add_child(game)
	for _i in 10:
		await get_tree().process_frame
	game._begin_search()
	await get_tree().create_timer(GameConfig.FIRST_RUN_MODAL_AFTER + 0.9).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://out/first_run.png")
	get_tree().paused = false
	GameState.set_setting("meta", "orientation_done", true)
	get_tree().quit()
