extends Node
## G12.10: the top bar as it looks during play, with the drawn chip icons.

func _ready() -> void:
	var game: Node = load("res://scenes/Main.tscn").instantiate()
	add_child(game)
	await get_tree().process_frame
	game.hud.set_secret_count(1, 2)
	game.hud.set_scrap(4250)
