extends Node
## G18: the yard and a line of dialogue at 16:9.
func _ready() -> void:
	GameState.set_setting("meta", "orientation_done", true)
	for key: String in ["money", "food"]:
		GameState.set_setting("tips", key, true)
	get_window().size = Vector2i(1600, 900)
	for _i in 4:
		await get_tree().process_frame
	var game: Node = load("res://scenes/Main.tscn").instantiate()
	game.variant_id = "ch01_aldridge"
	add_child(game)
	for _i in 10:
		get_tree().paused = false
		await get_tree().process_frame
	get_tree().paused = false
	game.hud._close_pause()
	game._begin_search()
	for _i in 30:
		get_tree().paused = false
		await get_tree().process_frame
	var layer := CanvasLayer.new()
	layer.layer = 60
	add_child(layer)
	var box := DialogueBox.new()
	layer.add_child(box)
	box.play(Dialogue.conversation("brief_ch01"), "")
	for _i in 8:
		get_tree().paused = false
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://out/landscape.png")
	print("[cekim] out/landscape.png yazildi")
	get_tree().quit()
