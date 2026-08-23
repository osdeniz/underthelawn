extends Node
## G6.7 pace audit: measures each mower's AVERAGE speed over a real drive and
## reports it against the §6 nominal. A type that averages far below nominal is
## losing time to throttle ramps or steering thrash.

var game: Game
var frame := 0
var idx := -1
var samples := 0
var sum_speed := 0.0
var start_cells := 0
var fails := 0

const WINDOW := 300
const TYPES := [
	[GameConfig.MOWER_PUSH, "push"], [GameConfig.MOWER_TRACTOR, "traktor"],
	[GameConfig.MOWER_ROBOT, "robot"], [GameConfig.MOWER_BLADE, "blade"],
]
const SPOTS := [Vector3(-5.0, 0.0, 9.0), Vector3(5.0, 0.0, 9.0),
	Vector3(-5.0, 0.0, -3.0), Vector3(1.0, 0.0, -7.0)]


func _ready() -> void:
	game = get_node("Main") as Game
	print("--- hiz denetimi (pencere %.1f sn) ---" % (float(WINDOW) / 60.0))


func _process(_d: float) -> void:
	frame += 1
	if frame < 20:
		return
	var local := (frame - 20) % WINDOW
	var i := (frame - 20) / WINDOW
	if i >= TYPES.size():
		print("--- %s ---" % ("HIZ DENETIMI GECTI" if fails == 0 else "%d TIP YAVAS" % fails))
		get_tree().quit(fails)
		return

	if local == 0:
		idx = i
		game.select_mower(TYPES[i][0])
		game.mower.reset_to_start()
		game.mower.position = SPOTS[i]
		game.cam.snap_to_target()
		var robot := game.mower as RobotMower
		if robot != null:
			robot._rejoin_nearest()
		samples = 0
		sum_speed = 0.0
		start_cells = game.model.mowed_count
	elif local < WINDOW - 10:
		_drive(TYPES[i][0])
		sum_speed += game.mower.speed
		samples += 1
	elif local == WINDOW - 5:
		var avg := sum_speed / maxf(float(samples), 1.0)
		var nominal: float = GameConfig.MOWER_TYPES[TYPES[i][0]]["speed"]
		var ratio := avg / nominal
		var cells := game.model.mowed_count - start_cells
		# Below 55% of nominal means the vehicle is fighting itself.
		var ok := ratio >= 0.55
		if not ok:
			fails += 1
		print("  %s %-8s ort=%.2f nominal=%.1f oran=%%%d  %d hucre" % [
			"ok  " if ok else "FAIL", TYPES[i][1], avg, nominal, int(ratio * 100.0), cells])
		_release(TYPES[i][0])


func _drive(type: int) -> void:
	match type:
		GameConfig.MOWER_PUSH:
			game.mower.on_touch_pressed(0, Vector2(585, 1500))
			game.mower.on_touch_dragged(0, Vector2(585, 1250))
		GameConfig.MOWER_TRACTOR:
			game.hud.joystick._set_knob(Vector2(0.15, -0.98) * 165.0)
		GameConfig.MOWER_BLADE:
			if not (game.mower as BladeMower)._has_finger:
				game.mower.on_touch_pressed(0,
					game.cam.unproject_position(game.mower.global_position))
			# Orbit the spawn point: driving straight pins it on a wall within
			# half a second and the average then measures standing still.
			var a := float(frame) * 0.06
			var orbit := SPOTS[GameConfig.MOWER_BLADE] \
				+ Vector3(cos(a) * 3.0, 0.0, sin(a) * 3.0)
			game.mower.on_touch_dragged(0, game.cam.unproject_position(orbit))


func _release(type: int) -> void:
	match type:
		GameConfig.MOWER_PUSH, GameConfig.MOWER_BLADE:
			game.mower.on_touch_released(0, Vector2.ZERO)
		GameConfig.MOWER_TRACTOR:
			game.hud.joystick._set_knob(Vector2.ZERO)
