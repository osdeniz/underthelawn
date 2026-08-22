extends SceneTree

var fails := 0

func ck(label: String, ok: bool, extra := "") -> void:
	if ok:
		print("  ok   ", label)
	else:
		fails += 1
		print("  FAIL ", label, "  ", extra)

func _initialize() -> void:
	print("--- LawnModel (REFERENCE.md §3) ---")
	var m := LawnModel.new(12345)

	ck("384 cells", GameConfig.CELL_COUNT == 384, str(GameConfig.CELL_COUNT))
	ck("368 mowable (384 - 16 obstacle)", m.mowable_cells == 368, str(m.mowable_cells))

	ck("flowerbed col4,5 row14",
		m.state_at(4, 14) == LawnModel.CellState.OBSTACLE and m.state_at(5, 14) == LawnModel.CellState.OBSTACLE)
	ck("stone col11 row9", m.state_at(11, 9) == LawnModel.CellState.OBSTACLE)
	ck("pool col10-13 row17-19",
		m.state_at(10, 17) == LawnModel.CellState.OBSTACLE and m.state_at(13, 19) == LawnModel.CellState.OBSTACLE
		and m.state_at(9, 17) != LawnModel.CellState.OBSTACLE and m.state_at(10, 20) != LawnModel.CellState.OBSTACLE)
	ck("sunbed col14 row18", m.state_at(14, 18) == LawnModel.CellState.OBSTACLE)
	ck("4 collision rects", m.collision_rects.size() == 4, str(m.collision_rects.size()))
	ck("pool is ONE rect (2,5,4,3)", m.collision_rects[2] == Rect2(2, 5, 4, 3), str(m.collision_rects[2]))

	ck("cell_center(0,0) = (-7.5,0,-11.5)", LawnModel.cell_center(0, 0) == Vector3(-7.5, 0, -11.5), str(LawnModel.cell_center(0, 0)))
	ck("cell_center(15,23) = (7.5,0,11.5)", LawnModel.cell_center(15, 23) == Vector3(7.5, 0, 11.5), str(LawnModel.cell_center(15, 23)))
	ck("cell_at roundtrip", LawnModel.cell_at(LawnModel.cell_center(9, 20)) == Vector2i(9, 20))
	ck("row0 is north (-Z)", LawnModel.cell_center(0, 0).z < LawnModel.cell_center(0, 23).z)

	ck("stripe N", LawnModel.stripe_bucket(Vector3(0, 0, -1)) == 0)
	ck("stripe E", LawnModel.stripe_bucket(Vector3(1, 0, 0)) == 1)
	ck("stripe S", LawnModel.stripe_bucket(Vector3(0, 0, 1)) == 2)
	ck("stripe W", LawnModel.stripe_bucket(Vector3(-1, 0, 0)) == 3)

	ck("2 secrets", m.secret_cells.size() == 2, str(m.secret_cells))
	var sep := Vector2(m.secret_cells[0] - m.secret_cells[1]).length()
	ck("separation >= 8", sep >= 8.0, "%.2f" % sep)
	var margin_ok := true
	for s in m.secret_cells:
		if s.x < 2 or s.y < 2 or s.x > 13 or s.y > 21:
			margin_ok = false
	ck("secrets >=2 from every edge", margin_ok, str(m.secret_cells))

	# mowing + re-striping
	ck("mow TALL -> MOWED", m.mow(0, 0, 0) == LawnModel.MowResult.MOWED)
	ck("count incremented", m.mowed_count == 1, str(m.mowed_count))
	ck("mow again same dir -> NONE", m.mow(0, 0, 0) == LawnModel.MowResult.NONE)
	ck("count unchanged", m.mowed_count == 1, str(m.mowed_count))
	ck("tint = north tone", m.tint_for(0, 0) == GameConfig.TINT_STRIPE[0], str(m.tint_for(0, 0)))
	ck("re-stripe south -> NONE but tone changes", m.mow(0, 0, 2) == LawnModel.MowResult.NONE and m.tint_for(0, 0) == GameConfig.TINT_STRIPE[2])
	ck("count still unchanged", m.mowed_count == 1, str(m.mowed_count))
	ck("mow obstacle -> NONE", m.mow(11, 9, 0) == LawnModel.MowResult.NONE)
	ck("uncut cell tint = TALL", m.tint_for(1, 1) == GameConfig.TINT_TALL)
	ck("pool cell tint = pool floor", m.tint_for(11, 18) == GameConfig.TINT_POOL_FLOOR)

	# secret reveal + completion
	var sc: Vector2i = m.secret_cells[0]
	ck("mow secret -> SECRET_REVEALED", m.mow(sc.x, sc.y, 1) == LawnModel.MowResult.SECRET_REVEALED)
	ck("revealed secret tint = soil", m.tint_for(sc.x, sc.y) == GameConfig.TINT_SOIL)

	for row in GameConfig.GRID_ROWS:
		for col in GameConfig.GRID_COLS:
			m.mow(col, row, 0)
	ck("all mown -> complete", m.is_complete() and m.mowed_count == 368, "%d" % m.mowed_count)
	ck("ratio = 1.0", is_equal_approx(m.completion_ratio(), 1.0))

	# reset redistributes
	var before: Array = m.secret_cells.duplicate()
	var differs := false
	for i in 20:
		m.reset()
		if m.secret_cells != before:
			differs = true
			break
	ck("reset redistributes secrets", differs, str(before) + " -> " + str(m.secret_cells))
	ck("reset clears counter", m.mowed_count == 0 and m.mowable_cells == 368)

	print("--- %s ---" % ("TUM TESTLER GECTI" if fails == 0 else "%d TEST BASARISIZ" % fails))
	quit(fails)
