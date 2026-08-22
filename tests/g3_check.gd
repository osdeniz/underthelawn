extends SceneTree
## G3 checks: §6 parameter sets, §7 tractor input mapping, robot boustrophedon.

var fails := 0

func ck(label: String, ok: bool, extra := "") -> void:
	if ok:
		print("  ok   ", label)
	else:
		fails += 1
		print("  FAIL ", label, "  ", extra)


func _initialize() -> void:
	print("--- §6 parametre setleri ---")
	var expected := [
		{ "speed": 3.0, "deck": 0.7, "max_turn": 1.7, "body": 0.55, "reverse": 0.0 },
		{ "speed": 4.8, "deck": 1.1, "max_turn": 1.5, "body": 0.85, "reverse": 0.5 },
		{ "speed": 2.1, "deck": 0.7, "max_turn": 2.6, "body": 0.45, "reverse": 0.0 },
	]
	for i in 3:
		var got: Dictionary = GameConfig.MOWER_TYPES[i]
		var want: Dictionary = expected[i]
		var same := true
		for key in want:
			if not is_equal_approx(float(got[key]), float(want[key])):
				same = false
		ck("tip %d (%s) tablosu" % [i, got["label"]], same, str(got))

	print("--- §7 traktor girdi eslemesi ---")
	var turn: float = GameConfig.MOWER_TYPES[1]["max_turn"]
	var rev: float = GameConfig.MOWER_TYPES[1]["reverse"]
	var fwd := TractorMower.map_input(Vector2(0.0, 1.0), turn, rev, 2.0)
	ck("tam ileri -> throttle 1", is_equal_approx(fwd.x, 1.0), str(fwd))
	var back := TractorMower.map_input(Vector2(0.0, -1.0), turn, rev, -1.0)
	ck("tam geri -> throttle -0.5 (0.5x)", is_equal_approx(back.x, -0.5), str(back))
	var right_fwd := TractorMower.map_input(Vector2(1.0, 1.0), turn, rev, 2.0)
	ck("ileri saga -> +maxTurn", is_equal_approx(right_fwd.y, turn), str(right_fwd))
	var right_back := TractorMower.map_input(Vector2(1.0, -1.0), turn, rev, -1.0)
	ck("geri saga -> isaret TERS", is_equal_approx(right_back.y, -turn), str(right_back))
	var idle := TractorMower.map_input(Vector2.ZERO, turn, rev, 0.0)
	ck("birakinca throttle 0 ve steer 0", idle == Vector2.ZERO, str(idle))

	print("--- robot boustrophedon rotasi ---")
	var m := LawnModel.new(4242)
	var robot := RobotMower.new()
	robot.model = m
	robot.plan_route()
	var route: Array[Vector2i] = robot.route
	ck("rota bos degil", route.size() > 0, str(route.size()))

	# Serpentine: row 0 runs west->east, row 1 east->west.
	var row0: Array[int] = []
	var row1: Array[int] = []
	for cell in route:
		if cell.y == 0:
			row0.append(cell.x)
		elif cell.y == 1:
			row1.append(cell.x)
	ck("satir 0 batidan doguya", row0.size() > 2 and row0[0] < row0[row0.size() - 1],
		str(row0.slice(0, 4)))
	ck("satir 1 dogudan batiya", row1.size() > 2 and row1[0] > row1[row1.size() - 1],
		str(row1.slice(0, 4)))

	# No waypoint may sit on an obstacle.
	var on_obstacle := 0
	for cell in route:
		if not m.is_mowable(cell.x, cell.y):
			on_obstacle += 1
	ck("hicbir waypoint engel uzerinde degil", on_obstacle == 0, "%d tane" % on_obstacle)

	# The stone at col 11 row 9 must produce a detour in the same column.
	var detour_found := false
	for cell in route:
		if cell.x == 11 and absi(cell.y - 9) >= 1 and absi(cell.y - 9) <= 4:
			detour_found = true
	ck("tas (11,9) icin ayni sutunda detour var", detour_found)

	# Pool spans cols 10-13 rows 17-19: no waypoint inside it.
	var in_pool := 0
	for cell in route:
		if cell.x >= 10 and cell.x <= 13 and cell.y >= 17 and cell.y <= 19:
			in_pool += 1
	ck("havuzun icinde waypoint yok", in_pool == 0, "%d tane" % in_pool)

	# Every mowable cell should be visited at least once.
	var visited := {}
	for cell in route:
		visited[cell] = true
	var missing := 0
	for row in GameConfig.GRID_ROWS:
		for col in GameConfig.GRID_COLS:
			if m.is_mowable(col, row) and not visited.has(Vector2i(col, row)):
				missing += 1
	ck("her bicilebilir hucre rotada", missing == 0, "%d eksik" % missing)

	print("--- kamera presetleri (§10 / G3-5) ---")
	ck("push mid preset", GameConfig.MOWER_CAMERA[0] == Vector3(5.0, 4.2, 2.2))
	ck("robot geriden/yukaridan", GameConfig.MOWER_CAMERA[2] == Vector3(6.0, 5.0, 2.4))
	ck("traktor lookAhead kazanci 0.6",
		is_equal_approx(GameConfig.TRACTOR_LOOKAHEAD_GAIN, 0.6))

	print("--- §14 motor profilleri ---")
	var robot_profile: Dictionary = GameConfig.ENGINE_PROFILES[2]
	ck("robot volume 0.08-0.13",
		is_equal_approx(float(robot_profile["idle_gain"]), 0.08)
		and is_equal_approx(float(robot_profile["move_gain"]), 0.13))
	ck("robot pitch 1.9", is_equal_approx(float(robot_profile["idle_pitch"]), 1.9))

	robot.free()
	print("--- %s ---" % ("TUM G3 TESTLERI GECTI" if fails == 0 else "%d TEST BASARISIZ" % fails))
	quit(fails)
