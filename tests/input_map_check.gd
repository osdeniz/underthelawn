extends Node
## G14.1: every driving action answers to touch-era keys AND a gamepad, so the
## input layer is finished before more screens are built on top of it.

var _fails := 0


func _ready() -> void:
	for action: String in ["move_forward", "move_back", "move_left",
			"move_right", "mower_next", "ui_pause"]:
		ck("eylem tanimli: %s" % action, InputMap.has_action(action), "")
		if not InputMap.has_action(action):
			continue
		var keys := 0
		var pads := 0
		for event: InputEvent in InputMap.action_get_events(action):
			if event is InputEventKey:
				keys += 1
			elif event is InputEventJoypadMotion or event is InputEventJoypadButton:
				pads += 1
		ck("%s klavyede var" % action, keys > 0, "%d tus" % keys)
		ck("%s kumandada var" % action, pads > 0, "%d kumanda olayi" % pads)

	# physical_keycode, not keycode: the WASD block must stay in the same PLACE
	# on an AZERTY keyboard rather than becoming ZQSD letters.
	for action: String in ["move_forward", "move_left"]:
		for event: InputEvent in InputMap.action_get_events(action):
			var key := event as InputEventKey
			if key == null:
				continue
			ck("%s fiziksel tusa bagli" % action, key.physical_keycode != 0,
				"keycode=%d physical=%d" % [key.keycode, key.physical_keycode])

	# The save file must carry a version, or a later format change cannot tell
	# an old file from a broken one.
	ck("kayit surumu damgalanmis", GameState.save_version() > 0,
		"surum=%d" % GameState.save_version())

	# Backgrounding must stop the lawn, not just the audio: a phone call used to
	# leave the mower driving.
	await _check_background()

	if _fails > 0:
		push_error("%d GIRDI TESTI BASARISIZ" % _fails)
		print("--- %d GIRDI TESTI BASARISIZ ---" % _fails)
	else:
		print("--- TUM GIRDI TESTLERI GECTI ---")
	get_tree().quit()


## Sends the real notification the OS sends and checks the tree pauses.
func _check_background() -> void:
	var game: Node = load("res://scenes/Main.tscn").instantiate()
	add_child(game)
	for _i in 4:
		await get_tree().process_frame
	game._begin_search()
	await get_tree().process_frame
	ck("arama basladi", get_tree().paused == false, "zaten duraklamis")
	game.notification(NOTIFICATION_APPLICATION_PAUSED)
	await get_tree().process_frame
	ck("arka plana alininca duraklar", get_tree().paused, "duraklamadi")
	get_tree().paused = false
	game.queue_free()
	await get_tree().process_frame


func ck(label: String, passed: bool, detail: String) -> void:
	if passed:
		return
	_fails += 1
	print("  FAIL %s  %s" % [label, detail])
