extends Node
## G14: WASD drives every hand-driven mower, in screen directions, and never
## fights a finger already on the pad.

var _fails := 0


func _ready() -> void:
	# Not a first run: the orientation sheet pauses the tree, and a paused tree
	# cannot be driven (G15).
	GameState.set_setting("meta", "orientation_done", true)
	var game: Node = load("res://scenes/Main.tscn").instantiate()
	add_child(game)
	await get_tree().process_frame

	for type_index: int in [GameConfig.MOWER_PUSH, GameConfig.MOWER_TRACTOR,
			GameConfig.MOWER_BLADE]:
		game.select_mower(type_index)
		var mower: MowerController = game.mower
		var label := str(GameConfig.MOWER_TYPES[type_index]["id"])
		await _drive(mower, "move_forward", label, Vector3(0.0, 0.0, -1.0))
		await _drive(mower, "move_right", label, Vector3(1.0, 0.0, 0.0))

	# The robot plans its own route and must ignore the keys.
	game.select_mower(GameConfig.MOWER_ROBOT)
	ck("robot klavyeyi reddediyor", not game.mower.keyboard_enabled(), "")

	# A finger on the pad outranks the keyboard.
	game.select_mower(GameConfig.MOWER_PUSH)
	var push: MowerController = game.mower
	push.on_touch_pressed(0, Vector2(500, 1600))
	push.on_touch_dragged(0, Vector2(500, 1300))
	_press("move_back")
	await get_tree().physics_frame
	ck("parmak klavyeden onceliklidir", push.pad_stick().y > 0.5,
		"stick=%v" % push.pad_stick())
	_release("move_back")
	push.on_touch_released(0, Vector2(500, 1300))

	game.queue_free()
	if _fails > 0:
		push_error("%d KLAVYE TESTI BASARISIZ" % _fails)
		print("--- %d KLAVYE TESTI BASARISIZ ---" % _fails)
	else:
		print("--- TUM KLAVYE TESTLERI GECTI ---")
	get_tree().quit()


## Holds one key and checks the mower actually travels that way on screen.
func _drive(mower: MowerController, action: String, label: String,
		screen_dir: Vector3) -> void:
	mower.position = Vector3.ZERO
	mower.speed = 0.0
	# Point the camera north and let the mower face the same way: "forward on
	# screen" is measured against the CAMERA, so a test that does not fix it is
	# measuring the camera's leftover heading.
	# snap_to_target() copies the MOWER's yaw onto the camera, so the mower has
	# to be facing north first — otherwise it overwrites the zero being set.
	mower.yaw = 0.0
	mower.rotation.y = 0.0
	var rig := mower.camera as CameraRig
	if rig != null:
		rig.yaw = 0.0
		rig.snap_to_target()
		rig.yaw = 0.0
	mower.camera_yaw = 0.0
	for _s in 4:
		await get_tree().physics_frame
	var from := mower.position
	_press(action)
	for _i in 90:
		await get_tree().physics_frame
	_release(action)
	var moved := mower.position - from
	# Camera yaw is 0 in this test, so screen direction and world direction
	# agree; what is being checked is that the key moves it THAT way at all.
	var along := moved.dot(screen_dir)
	ck("%s %s ile gidiyor" % [label, action], along > 0.5,
		"ilerleme=%.2f (%v)" % [along, moved])


func _press(action: String) -> void:
	Input.action_press(action)


func _release(action: String) -> void:
	Input.action_release(action)


func ck(label: String, passed: bool, detail: String) -> void:
	if passed:
		return
	_fails += 1
	print("  FAIL %s  %s" % [label, detail])
