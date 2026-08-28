extends Node
## G13.6: the harvest field — the crop is meant to be looked UP at.

func _ready() -> void:
	GameState.set_setting("meta", "orientation_done", true)
	var game: Node = load("res://scenes/Main.tscn").instantiate()
	game.variant_id = GameConfig.HARVEST_VARIANT
	add_child(game)
	for _i in 14:
		await get_tree().process_frame
	game.select_mower(GameConfig.MOWER_TRACTOR)
	# The harvest camera descends for 14 s from high above the crop; shooting
	# early only photographs the fog it starts in.
	for _i in 950:
		await get_tree().process_frame
	# The window loses focus while rendering headless-ish, which now pauses the
	# game (G14.1); the shot wants the field, not the pause sheet.
	get_tree().paused = false
	game.hud._close_pause()
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://out/harvest.png")
	get_tree().quit()
