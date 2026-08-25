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
