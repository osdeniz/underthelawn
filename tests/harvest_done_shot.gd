extends Node
## G13.6: the harvest's own completion panel — no evidence, no case notes, a
## crumb from Gus and the field's pay.

func _ready() -> void:
	GameState.set_setting("meta", "orientation_done", true)
	GameState.set_setting("harvest", "runs", 1)
	var game: Node = load("res://scenes/Main.tscn").instantiate()
	game.variant_id = GameConfig.HARVEST_VARIANT
	add_child(game)
	for _i in 20:
		await get_tree().process_frame
	get_tree().paused = false
	game.hud._close_pause()
	game.hud.show_complete(1240, "3:18", [], 0,
		{"base": 210, "bonus": 484, "total": 694}, "")
	for _i in 30:
		await get_tree().process_frame
	get_tree().paused = false
	game.hud._close_pause()
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://out/harvest_done.png")
	GameState.set_setting("harvest", "runs", 0)
	get_tree().quit()
