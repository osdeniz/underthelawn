extends Node
func _ready() -> void:
	GameState.set_setting("meta", "orientation_done", true)
	var game: Node = load("res://scenes/Main.tscn").instantiate()
	game.variant_id = "ch04_flooded"
	add_child(game)
	for _i in 8: await get_tree().process_frame
	get_tree().paused = false
	game.hud._close_pause()
	game._begin_search()
	for _i in 200:
		get_tree().paused = false
		await get_tree().process_frame
	game.hud.set_progress(0.37)
	game.hud.set_scrap(86513)
	game.hud.set_secret_count(2, GameConfig.SECRET_TOTAL)
	for _i in 40:
		get_tree().paused = false
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("user://hud_now.png")
	# inventory of what is actually on screen
	for n in game.hud.find_children("*", "Control", true, false):
		var c := n as Control
		if not c.is_visible_in_tree(): continue
		if c.get_parent() != null and str(c.get_parent().name) in ["TopBar", "HUD"]:
			print("GORUNUR %-16s %-14s %s" % [c.name, c.get_class(), c.get_global_rect()])
	print("OK")
	get_tree().quit()
