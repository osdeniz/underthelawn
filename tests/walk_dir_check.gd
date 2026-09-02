extends Node
## G14.17: on foot, "forward" has to mean what it means on the machine.

var _fails := 0


func _ready() -> void:
	GameState.set_setting("meta", "orientation_done", true)
	var game: Node = load("res://scenes/Main.tscn").instantiate()
	game.variant_id = "ch01_aldridge"
	add_child(game)
	for _i in 12:
		await get_tree().process_frame
	get_tree().paused = false
	game.hud._close_pause()
	game._begin_search()
	for _i in 10:
		get_tree().paused = false
		await get_tree().process_frame

	# The machine's own answer, for the same stick and the same camera.
	var mower: MowerController = game.mower
	for camera_yaw: float in [0.0, PI * 0.5, PI, -PI * 0.35]:
		for stick: Vector2 in [Vector2(0, 1), Vector2(0, -1),
				Vector2(1, 0), Vector2(-1, 0)]:
			var machine_dir := _machine_direction(camera_yaw, stick)
			var foot_dir := _walk_direction(camera_yaw, stick)
			var angle := rad_to_deg(absf(machine_dir.angle_to(foot_dir)))
			ck("yon esit  kamera=%.0f stick=%v" % [rad_to_deg(camera_yaw), stick],
				angle < 1.0, "%.1f derece sapma" % angle)
	# --- and the keys have to actually REACH the walker. The first version of
	# this feature parked the machine by switching off its physics processing,
	# which is where the keyboard is read — so on foot nothing moved at all,
	# and the test that "checked walking" had been moving the walker by hand.
	game.toggle_walk()
	for _i in 4:
		await get_tree().process_frame
	var walker: Walker = game.get_node("Walker")
	walker.camera_yaw = 0.0
	var from := walker.position
	Input.action_press("move_forward")
	for _i in 30:
		await get_tree().process_frame
	Input.action_release("move_forward")
	var moved := walker.position - from
	ck("tuslar yuruyucuye ulasiyor", moved.length() > 0.3,
		"%.2f birim" % moved.length())
	# And in the direction the machine would have gone, not 90 degrees off it.
	var want := _machine_direction(0.0, Vector2(0, 1))
	var got := Vector2(moved.x, moved.z).normalized()
	ck("dogru yone yurudu",
		rad_to_deg(absf(want.angle_to(got))) < 12.0,
		"%.0f derece" % rad_to_deg(absf(want.angle_to(got))))

	game.queue_free()

	if _fails > 0:
		push_error("%d YON TESTI BASARISIZ" % _fails)
		print("--- %d YON TESTI BASARISIZ ---" % _fails)
	else:
		print("--- YURUME YONU MAKINEYLE AYNI ---")
	get_tree().quit()


## Where the mower would go: its yaw model, then its own forward vector.
func _machine_direction(camera_yaw: float, stick: Vector2) -> Vector2:
	var yaw := camera_yaw + atan2(stick.x, stick.y)
	return Vector2(cos(yaw), sin(yaw))


## Where the walker goes, read out of the walker itself rather than restated.
func _walk_direction(camera_yaw: float, stick: Vector2) -> Vector2:
	return Walker.direction_for(camera_yaw, stick)


func ck(label: String, passed: bool, detail: String) -> void:
	if passed:
		return
	_fails += 1
	print("  FAIL %s  %s" % [label, detail])
