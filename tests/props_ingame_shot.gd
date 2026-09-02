extends Node
## G14.12: the props at the distance a player actually sees them, and the two
## counters they feed.

func _ready() -> void:
	GameState.set_setting("meta", "orientation_done", true)
	TownStats.reset()
	SkyTime.set_mode(GameConfig.SKY_MODE_DAY)
	var game: Node = load("res://scenes/Main.tscn").instantiate()
	game.variant_id = "ch01_aldridge"
	add_child(game)
	for _i in 10:
		await get_tree().process_frame
	get_tree().paused = false
	game.hud._close_pause()
	var host: Node3D = game.get_node("ScrapField")
	MoneyProp.spawn(host, Vector3(-1.4, 0.0, 5.6))
	FoodProp.spawn(host, Vector3(1.4, 0.0, 5.6))
	game._begin_search()
	for _i in 130:
		get_tree().paused = false
		await get_tree().process_frame
	get_tree().paused = false
	game.hud._close_pause()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://out/props_game.png")
	SkyTime.set_mode(GameConfig.SKY_MODE_AUTO)
	get_tree().quit()
