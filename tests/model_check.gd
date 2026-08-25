extends Node

var fails := 0

func ck(label: String, ok: bool, extra := "") -> void:
	if ok:
		print("  ok   ", label)
	else:
		fails += 1
		print("  FAIL ", label, "  ", extra)

func _ready() -> void:
	# §3's numbers describe the ORIGINAL yard: medium grid, pool layout. G9 made
	# both of those data, and the default is now the pool-free "beds" layout, so
	# this suite states the world it is checking instead of assuming it.
	GameConfig.set_grid_named("medium")
	LawnModel.layout_id = "pool"
	print("--- LawnModel (REFERENCE.md §3) ---")
	var m := LawnModel.new(12345)

	ck("384 cells", GameConfig.CELL_COUNT == 384, str(GameConfig.CELL_COUNT))
	var blocked := 0
	for ob: Dictionary in m.obstacles:
		blocked += (ob["grid"] as Rect2i).get_area()
	ck("bicilebilir = hucre - engel",
		m.mowable_cells == GameConfig.CELL_COUNT - blocked,
		"%d, engel %d" % [m.mowable_cells, blocked])

	var by_name := {}
	for ob: Dictionary in m.obstacles:
		by_name[str(ob["name"])] = ob["grid"] as Rect2i
	var bed_rect: Rect2i = by_name.get("flowerbed", Rect2i())
	var bed_ok := by_name.has("flowerbed")
	for c in range(bed_rect.position.x, bed_rect.end.x):
		if m.state_at(c, bed_rect.position.y) != LawnModel.CellState.OBSTACLE:
			bed_ok = false
	ck("tarh engeli var", bed_ok, str(bed_rect))
	var pool_rect: Rect2i = by_name.get("pool", Rect2i())
	var pool_ok := by_name.has("pool")
	for r in range(pool_rect.position.y, pool_rect.end.y):
		for c in range(pool_rect.position.x, pool_rect.end.x):
			if m.state_at(c, r) != LawnModel.CellState.OBSTACLE:
				pool_ok = false
	ck("havuz engeli var", pool_ok, str(pool_rect))
	var sunbed_cell := (by_name.get("sunbed", Rect2i()) as Rect2i).position
	ck("sunbed engeli var", by_name.has("sunbed")
		and m.state_at(sunbed_cell.x, sunbed_cell.y) == LawnModel.CellState.OBSTACLE)
	ck("engel sayisi kadar collision rect",
		m.collision_rects.size() == m.obstacles.size(),
		"%d / %d" % [m.collision_rects.size(), m.obstacles.size()])
	# The point of §18 trap 3: a multi-cell obstacle is ONE rect, so the mower
	# slides along its edge instead of rattling cell to cell.
	var pool_world := LawnModel.grid_rect_to_world(pool_rect)
	ck("havuz TEK rect", m.collision_rects.has(pool_world), str(pool_world))

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
	ck("tint = north tone", m.tint_for(0, 0) == GameConfig.stripe_tint(0), str(m.tint_for(0, 0)))
	ck("re-stripe south -> NONE but tone changes", m.mow(0, 0, 2) == LawnModel.MowResult.NONE and m.tint_for(0, 0) == GameConfig.stripe_tint(2))
	ck("count still unchanged", m.mowed_count == 1, str(m.mowed_count))
	ck("mow obstacle -> NONE",
		m.mow(bed_rect.position.x, bed_rect.position.y, 0)
		== LawnModel.MowResult.NONE)
	ck("uncut cell tint = TALL", m.tint_for(1, 1) == GameConfig.ground_tall_tint())
	ck("pool cell tint = pool floor",
		m.tint_for(pool_rect.position.x, pool_rect.position.y)
		== GameConfig.TINT_POOL_FLOOR)

	# The stone only exists in the layouts that place one, so it is checked on a
	# model built from one of those rather than asserted into this yard.
	LawnModel.layout_id = "stones"
	var sm := LawnModel.new(999)
	var stone_found := false
	for ob: Dictionary in sm.obstacles:
		if str(ob["name"]) == "stone":
			var cell := (ob["grid"] as Rect2i).position
			stone_found = sm.state_at(cell.x, cell.y) == LawnModel.CellState.OBSTACLE
			break
	ck("tasli duzende tas engeli var", stone_found, str(sm.obstacles.size()))
	LawnModel.layout_id = "pool"

	# secret reveal + completion
	var sc: Vector2i = m.secret_cells[0]
	ck("mow secret -> SECRET_REVEALED", m.mow(sc.x, sc.y, 1) == LawnModel.MowResult.SECRET_REVEALED)
	ck("revealed secret tint = soil", m.tint_for(sc.x, sc.y) == GameConfig.TINT_SOIL)

	for row in GameConfig.GRID_ROWS:
		for col in GameConfig.GRID_COLS:
			m.mow(col, row, 0)
	ck("all mown -> complete",
		m.is_complete() and m.mowed_count == m.mowable_cells,
		"%d / %d" % [m.mowed_count, m.mowable_cells])
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
	ck("reset clears counter",
		m.mowed_count == 0 and m.mowable_cells > 0, str(m.mowable_cells))

	print("--- %s ---" % ("TUM TESTLER GECTI" if fails == 0 else "%d TEST BASARISIZ" % fails))
	quit(fails)
