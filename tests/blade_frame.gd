extends Node
## G12.10: a held drag must keep meaning the same direction while the camera is
## free to turn between gestures.
##
## The bug this pins: the control frame used to be a COPY of the camera yaw
## taken at press. The camera kept turning during the drag, so "right on screen"
## and "right in the frame" drifted apart — the longer you held, the more wrong
## it got, and lifting the finger fixed it by re-latching.

var _fails := 0


func _ready() -> void:
	var game: Node = load("res://scenes/Main.tscn").instantiate()
	add_child(game)
	await get_tree().process_frame
	game.select_mower(GameConfig.MOWER_BLADE)
	var blade: MowerController = game.mower
	var rig: CameraRig = game.cam
	blade.position = Vector3.ZERO
	rig.yaw = 0.0
	rig.snap_to_target()
	await get_tree().physics_frame

	# Drive EAST while holding, so the camera has a reason to turn. This is the
	# case the north-only version missed: with yaw already 0, "camera held still"
	# passed no matter what the code did.
	blade.on_touch_pressed(0, Vector2(500, 1600))
	blade.on_touch_dragged(0, Vector2(800, 1600))
	for _i in 40:
		await get_tree().physics_frame
	var yaw_during := rig.yaw
	ck("surukleme sirasinda kamera sabit", absf(yaw_during) < 0.05,
		"%.3f" % yaw_during)

	# Same finger, now pulled forward. Forward must still mean forward on screen.
	var before := blade.position
	blade.on_touch_dragged(0, Vector2(500, 1300))
	for _i in 25:
		await get_tree().physics_frame
	var moved := blade.position - before
	ck("basili tutarken ileri cekince ileri gidiyor",
		moved.z < -0.5 and absf(moved.x) < -moved.z,
		"dx=%.2f dz=%.2f" % [moved.x, moved.z])
	blade.on_touch_released(0, Vector2(500, 1300))

	# Once the finger lifts, the camera is free to swing to the new heading.
	for _i in 90:
		await get_tree().physics_frame
	ck("parmak kalkinca kamera donuyor", absf(rig.yaw - blade.yaw) < 0.3,
		"cam=%.3f blade=%.3f" % [rig.yaw, blade.yaw])

	game.queue_free()
	if _fails > 0:
		push_error("%d BLADE TESTI BASARISIZ" % _fails)
		print("--- %d BLADE TESTI BASARISIZ ---" % _fails)
	else:
		print("--- TUM BLADE TESTLERI GECTI ---")
	get_tree().quit()


func ck(label: String, passed: bool, detail: String) -> void:
	if passed:
		return
	_fails += 1
	print("  FAIL %s  %s" % [label, detail])
