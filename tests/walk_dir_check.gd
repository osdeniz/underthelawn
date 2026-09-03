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
			var machine_dir := _machine_direction(mower, camera_yaw, stick)
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
	var want := _machine_direction(mower, 0.0, Vector2(0, 1))
	var got := Vector2(moved.x, moved.z).normalized()
	ck("dogru yone yurudu",
		rad_to_deg(absf(want.angle_to(got))) < 12.0,
		"%.0f derece" % rad_to_deg(absf(want.angle_to(got))))
	# --- and he FACES where he is going. Walking backwards was the other half
	# of this bug and no test looked at it: the direction was 90 degrees off
	# and the facing 180, so the figure moonwalked across the yard.
	var facing := -walker.global_transform.basis.z
	var flat := Vector2(facing.x, facing.z).normalized()
	ck("gittigi yone bakiyor",
		rad_to_deg(absf(flat.angle_to(got))) < 15.0,
		"%.0f derece" % rad_to_deg(absf(flat.angle_to(got))))

	game.queue_free()

	if _fails > 0:
		push_error("%d YON TESTI BASARISIZ" % _fails)
		print("--- %d YON TESTI BASARISIZ ---" % _fails)
	else:
		print("--- YURUME YONU MAKINEYLE AYNI ---")
	get_tree().quit()


## Where the mower would go — ASKED, not restated. The first version of this
## function copied the formula out by hand as Vector2(cos(yaw), sin(yaw)),
## which is MowerController.right(), not forward(). So it compared a walker
## that was 90 degrees wrong against a hand-copy that was 90 degrees wrong in
## the same direction, and they agreed. A test that restates the code it is
## testing proves that two copies match, and nothing else.
func _machine_direction(mower: MowerController, camera_yaw: float,
		stick: Vector2) -> Vector2:
	var was := mower.yaw
	mower.yaw = camera_yaw + atan2(stick.x, stick.y)
	var f := mower.forward()
	mower.yaw = was
	return Vector2(f.x, f.z)


## Where the walker goes, read out of the walker itself rather than restated.
func _walk_direction(camera_yaw: float, stick: Vector2) -> Vector2:
	return Walker.direction_for(camera_yaw, stick)


func ck(label: String, passed: bool, detail: String) -> void:
	if passed:
		return
	_fails += 1
	print("  FAIL %s  %s" % [label, detail])
