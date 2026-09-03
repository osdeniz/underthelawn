extends Node
## G16.4: the dialogue box with large text on — does the panel still hold it?
func _ready() -> void:
	GameState.set_setting("display", "large_text", true)
	var shot: Node = load("res://tests/DialogueShot.tscn").instantiate()
	add_child(shot)
	# DialogueShot saves its own png and quits; turn the setting back off first
	# so the real save is not left in large text by a test.
	await get_tree().create_timer(2.0).timeout
	GameState.set_setting("display", "large_text", false)
