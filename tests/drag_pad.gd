extends Node
## G6.12: every mower must be drivable by a drag starting ANYWHERE on screen,
## with the same four directions. Drives each type through the real touch entry
## points (on_touch_pressed/dragged/released), from a press in a screen corner
## far away from the mower, and checks it actually went the intended way.

const CORNER := Vector2(90.0, 190.0)   # nowhere near the mower
const PUSH := 260.0                    # drag distance: well past full deflection
## Open lawn, clear of the pool/flowerbed/stone. Starting inside an obstacle
## makes the push-out swamp the movement being measured.
const START := Vector3(0.0, 0.0, -6.0)


func _ready() -> void:
	var game: Node = load("res://scenes/Main.tscn").instantiate()
	add_child(game)
	await get_tree().process_frame
	var failures := 0
	for type_index in GameConfig.MOWER_TYPES.size():
		failures += await _check(game, type_index)
	if failures > 0:
		push_error("SURUKLEME PEDI TESTI BASARISIZ: %d arac" % failures)
		print("--- SURUKLEME PEDI TESTI BASARISIZ ---")
	else:
		print("--- SURUKLEME PEDI TESTI GECTI ---")
	get_tree().quit()


func _check(game: Node, type_index: int) -> int:
	var id: String = GameConfig.MOWER_TYPES[type_index]["id"]
	var yaw_free: bool = id == "blade"
	var ahead := await _run(game, type_index, Vector2(0.0, -PUSH))
	var back := await _run(game, type_index, Vector2(0.0, PUSH))
	var right := await _run(game, type_index, Vector2(PUSH, 0.0))
	var left := await _run(game, type_index, Vector2(-PUSH, 0.0))

	var problems: Array[String] = []
	var fwd: Vector2 = ahead["moved"]
	var rev: Vector2 = back["moved"]
	var rt: Vector2 = right["moved"]
	var lf: Vector2 = left["moved"]
	var rt_turn: float = right["turned"]
	var lf_turn: float = left["turned"]
	if fwd.length() < 0.35:
		problems.append("ileri hareket yok (%.2f)" % fwd.length())
	if rev.dot(fwd) >= 0.0:
		problems.append("geri, ileriyle ayni yonde")

	if yaw_free:
		# The blade has no heading: sideways must MOVE it sideways.
		var axis := fwd.normalized()
		var side_r := rt.x * axis.y - rt.y * axis.x
		var side_l := lf.x * axis.y - lf.y * axis.x
		if signf(side_r) == signf(side_l) or absf(side_r) < 0.3 or absf(side_l) < 0.3:
			problems.append("sag/sol ayrismadi (%.2f / %.2f)" % [side_r, side_l])
		else:
			print("  ok   %-8s ileri=%.2f geri=%.2f yan=%.2f/%.2f"
				% [id, fwd.length(), rev.length(), side_r, side_l])
			return 0
	else:
		# The others steer: sideways must TURN them, in opposite directions.
		if signf(rt_turn) == signf(lf_turn) \
				or absf(rt_turn) < 0.2 or absf(lf_turn) < 0.2:
			problems.append("sag/sol donusu ayrismadi (%.2f / %.2f rad)"
				% [rt_turn, lf_turn])
		else:
			print("  ok   %-8s ileri=%.2f geri=%.2f donus=%.2f/%.2f rad"
				% [id, fwd.length(), rev.length(), rt_turn, lf_turn])
			return 0

	print("  HATA %-8s %s" % [id, ", ".join(problems)])
	return 1


## One drag, held for 40 physics ticks. Returns the ground displacement and the
## heading change.
func _run(game: Node, type_index: int, offset: Vector2) -> Dictionary:
	game.select_mower(type_index)
	var mower: MowerController = game.mower
	mower.position = START
	mower.yaw = 0.0
	mower.speed = 0.0
	mower.omega = 0.0
	# The control is camera-relative and the camera chases the mower, so each leg
	# has to start from the same camera heading or the legs are not comparable.
	game.cam.yaw = 0.0
	game.cam.snap_to_target()
	mower.camera_yaw = 0.0
	var from := Vector2(mower.position.x, mower.position.z)

	mower.on_touch_pressed(0, CORNER)
	mower.on_touch_dragged(0, CORNER + offset)
	for _i in 40:
		await get_tree().physics_frame
	mower.on_touch_released(0, CORNER + offset)
	var out := {
		"moved": Vector2(mower.position.x, mower.position.z) - from,
		"turned": MowerController.shortest_angle(0.0, mower.yaw),
	}
	# Settle, so the next leg starts from rest.
	for _i in 10:
		await get_tree().physics_frame
	return out
