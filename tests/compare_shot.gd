extends Node
## G13.1: the yard and the diorama, shot the same way, so the quality gap (or
## what is left of it) can be judged side by side rather than argued about.

func _ready() -> void:
	var which := OS.get_environment("UTL_SHOT")
	if which == "yard":
		var game: Node = load("res://scenes/Main.tscn").instantiate()
		add_child(game)
		for _i in 30:
			await get_tree().process_frame
		await _shoot("yard")
	else:
		GameConfig.hub_mode = GameConfig.HUB_MODE_DIORAMA
		var hub := HubScreen.new()
		add_child(hub)
		await get_tree().process_frame
		for id: String in GameConfig.DIORAMA_BUILDINGS:
			RestoreBoard.of(id)
		for _i in 40:
			await get_tree().process_frame
		await _shoot("hub")
	get_tree().quit()


func _shoot(label: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://out/cmp_%s.png" % label)
