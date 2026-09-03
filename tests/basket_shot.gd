extends Node
## G15.2: the patch at the end of the road, close — does the basket read as a
## basket with a child in it, and does the dog stand clear of the grass?
func _ready() -> void:
	GameState.set_setting("meta", "orientation_done", true)
	GameState.set_setting("story", "prologue_done", false)
	var game: Node = load("res://scenes/Main.tscn").instantiate()
	game.variant_id = GameConfig.PROLOGUE_ID
	add_child(game)
	for _i in 10:
		get_tree().paused = false
		await get_tree().process_frame
	get_tree().paused = false
	game.hud._close_pause()
	game._begin_search()
	for _i in 16:
		get_tree().paused = false
		await get_tree().process_frame
	(game.get_node("UI") as CanvasLayer).visible = false
	var spot := GameConfig.prologue_dog_spot()
	var eye := Camera3D.new()
	eye.fov = 40.0
	eye.keep_aspect = Camera3D.KEEP_WIDTH
	eye.position = spot + Vector3(2.6, 2.4, 3.0)
	eye.current = true
	game.add_child(eye)
	eye.look_at(spot + Vector3(0.5, 0.25, 0.0))
	for _i in 8:
		get_tree().paused = false
		await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://out/basket.png")
	print("[cekim] out/basket.png yazildi")
	get_tree().quit()
