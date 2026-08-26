extends Node
## G14: what the phone layout looks like on a 16:9 desktop window.

func _ready() -> void:
	var game: Node = load("res://scenes/Main.tscn").instantiate()
	add_child(game)
	for _i in 30:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://out/wide.png")
	get_tree().quit()
