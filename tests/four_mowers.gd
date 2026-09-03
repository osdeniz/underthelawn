extends Node
## Automated scene test (G6.5): drives all four mower types in one run and
## fails unless each cuts at least 5 cells in its ~3 s window.
## Run: Godot --headless --path . res://tests/FourMowers.tscn

var game: Game
var frame := 0
var fails := 0
var baseline := 0
var phase := -1

## [type, label]; each phase teleports to fresh grass first.
const PHASES := [
	[GameConfig.MOWER_PUSH, "push"],
	[GameConfig.MOWER_TRACTOR, "traktor"],
	[GameConfig.MOWER_ROBOT, "robot"],
	[GameConfig.MOWER_BLADE, "blade"],
]
## The robot stops-and-restarts at every waypoint (0.4 s ramp per §7 executor),
## averaging ~0.8 u/s — 5 cells inside 3 s is physically out of reach for it,
## so it gets a longer window. A pace fix would change robot control feel and
## needs its own sprint approval.
const PHASE_FRAMES_DEFAULT := 180
const PHASE_FRAMES_ROBOT := 480
const SPOTS := [Vector3(-5.0, 0.0, 10.0), Vector3(5.0, 0.0, 10.0),
	Vector3(-5.0, 0.0, -4.0), Vector3(0.0, 0.0, -8.0)]


func _ready() -> void:
	game = get_node("Main") as Game
	# A headless window has no focus, so the game correctly pauses itself for
	# the background — and a paused tree does not run this node's _process
	# either, so the test hung at this print forever with no verdict. Third
	# test in this project with the same cause (KeyboardCheck, InputMapCheck).
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = false
	print("--- dort mower sahne testi ---")


func _process(_delta: float) -> void:
	# Every frame, not once: the notification can arrive at any point.
	get_tree().paused = false
	frame += 1
	if frame < 30:
		return
	# Variable-length phases: walk the cumulative frame table.
	var offset := frame - 30
	var index := 0
	var local := offset
	while index < PHASES.size():
		var span := PHASE_FRAMES_ROBOT if PHASES[index][0] == GameConfig.MOWER_ROBOT \
			else PHASE_FRAMES_DEFAULT
		if local < span:
			break
		local -= span
		index += 1
	if index >= PHASES.size():
		if phase != 99:
			phase = 99
			print("--- %s ---" % ("DORT MOWER TESTI GECTI" if fails == 0
				else "%d TIP BASARISIZ" % fails))
			get_tree().quit(fails)
		return

	var type: int = PHASES[index][0]
	if local == 0:
		phase = index
		game.select_mower(type)
		game.mower.reset_to_start()
		game.mower.position = SPOTS[index]
		game.cam.snap_to_target()
		# The robot planned its route before the teleport; rejoin from here so
		# the window measures mowing, not the walk to the route's NW corner.
		var robot := game.mower as RobotMower
		if robot != null:
			robot._rejoin_nearest()
		baseline = game.model.mowed_count
	var my_span := PHASE_FRAMES_ROBOT if type == GameConfig.MOWER_ROBOT \
		else PHASE_FRAMES_DEFAULT
	if local < my_span - 10 and local > 0:
		_drive(type)
	elif local == my_span - 5:
		var cut := game.model.mowed_count - baseline
		var ok := cut >= 5
		if not ok:
			fails += 1
		print("  %s %-8s %d hucre" % ["ok  " if ok else "FAIL", PHASES[index][1], cut])
		_release(type)


func _drive(type: int) -> void:
	match type:
		GameConfig.MOWER_PUSH:
			game.mower.on_touch_pressed(0, Vector2(585, 1500))
			game.mower.on_touch_dragged(0, Vector2(585, 1300))
		GameConfig.MOWER_TRACTOR:
			game.hud.joystick._set_knob(Vector2(0.1, -0.95) * 165.0)
		GameConfig.MOWER_ROBOT:
			pass   # autonomous
		GameConfig.MOWER_BLADE:
			if not (game.mower as BladeMower)._has_finger:
				game.mower.on_touch_pressed(0,
					game.cam.unproject_position(game.mower.global_position))
			game.mower.on_touch_dragged(0, game.cam.unproject_position(
				game.mower.global_position + Vector3(1.4, 0.0, -2.0)))


func _release(type: int) -> void:
	match type:
		GameConfig.MOWER_PUSH:
			game.mower.on_touch_released(0, Vector2.ZERO)
		GameConfig.MOWER_TRACTOR:
			game.hud.joystick._set_knob(Vector2.ZERO)
		GameConfig.MOWER_BLADE:
			game.mower.on_touch_released(0, Vector2.ZERO)
