extends Node
## G14.3: the same yard under each mode the switch offers.

const MODES := ["day", "dusk", "night"]


func _ready() -> void:
	GameState.set_setting("meta", "orientation_done", true)
	for mode: String in MODES:
		SkyTime.set_mode(mode)
		var game: Node = load("res://scenes/Main.tscn").instantiate()
		game.variant_id = "ch04_flooded"
		add_child(game)
		for _i in 8:
			await get_tree().process_frame
		get_tree().paused = false
		game.hud._close_pause()
		game._begin_search()
		for _i in 260:
			get_tree().paused = false
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://out/sky_%s.png" % mode)
		game.queue_free()
		for _i in 6:
			await get_tree().process_frame
	SkyTime.set_mode(GameConfig.SKY_MODE_AUTO)
	get_tree().quit()
