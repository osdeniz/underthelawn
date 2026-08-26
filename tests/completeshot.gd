extends Node
## G12.10: a look at the completion screen's evidence strip and case notes,
## which used to draw emoji (a blank box on iOS).

func _ready() -> void:
	var game: Node = load("res://scenes/Main.tscn").instantiate()
	add_child(game)
	await get_tree().process_frame
	var variant: LevelVariant = LevelVariant.of("ch01_aldridge")
	var collected: Array = []
	for slot in 2:
		collected.append(variant.evidence_info(slot))
	game.hud.show_complete(420, "1:32", collected, 3,
		{"base": 900, "bonus": 300, "total": 1200}, "Neighbour's yard")
	for _i in 40:
		await get_tree().process_frame
	get_tree().paused = false
	game.hud._close_pause()
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://out/complete.png")
	get_tree().quit()
