extends TestBase
## G19.3: yard shapes. Every yard is still a rectangle of fence, but the
## ground inside is an L, a ring, two halves, a courtyard or a bite. The
## contract, for EVERY variant, is the one the prologue road had: a flood fill
## from the spawn cell through mowable cells reaches every mowable cell — and
## reaches it through lanes two cells wide, because the tractor is 1.7 across
## and a one-cell lane would be a wall to it. Proven falsifiable first.

func run() -> void:
	suite = "SEKIL"
	var ids := LevelVariant.ids()
	var layouts := {}
	var start_fill_proved := false
	for vid: String in ids:
		var v := LevelVariant.of(vid)
		if v.is_harvest():
			continue
		v.apply()
		var model := LawnModel.new(v.decor_seed)
		layouts[LawnModel.layout_id] = layouts.get(LawnModel.layout_id, 0) + 1
		var start := LawnModel.cell_at(Vector3(GameConfig.mower_start().x, 0.0,
			GameConfig.mower_start().y))
		ck("%s spawn hucresi bicilebilir" % vid, model.is_mowable(start.x, start.y), str(start))
		if not start_fill_proved:
			# The fill must be able to say no: wall off the row above the spawn.
			var walled := _fill(model, start, func(c: Vector2i) -> bool:
				return model.is_mowable(c.x, c.y) and c.y != start.y - 1)
			ck("dolgu 'hayir' diyebiliyor", walled < model.mowable_cells,
				"%d / %d" % [walled, model.mowable_cells])
			start_fill_proved = true
		# The one piece reachable only on foot (G15.5) is meant to be outside
		# the machine's reach; it is not a hole in the yard.
		var on_foot := model.walk_only_cell
		var want := model.mowable_cells - (1 if on_foot.x >= 0 else 0)
		var reached := _fill(model, start, func(c: Vector2i) -> bool:
			return model.is_mowable(c.x, c.y) and c != on_foot)
		ck("%s her hucreye ulasilir (%s)" % [vid, LawnModel.layout_id],
			reached == want, "%d / %d" % [reached, want])
		# Lanes: a cell the tractor's body cannot enter is still cut by its
		# deck from the cell beside it, so a one-cell strip along a fence is
		# fine; a one-cell CORRIDOR is not, because its middle cells have no
		# wide cell within a deck's reach. Every mowable cell must be in, or
		# next to (eight ways), a fully mowable 2x2. The road is push-mower
		# only by design and keeps its one-cell weave.
		var narrow := 0
		if not v.is_road():
			for row in GameConfig.GRID_ROWS:
				for col in GameConfig.GRID_COLS:
					if not model.is_mowable(col, row) or Vector2i(col, row) == on_foot:
						continue
					if not _near_wide_lane(model, col, row):
						narrow += 1
		ck("%s dar koridor yok" % vid, narrow == 0, "%d hucre deck erisiminden uzak" % narrow)
		# Still a yard: at least 45% of the grid is grass.
		var share := float(model.mowable_cells) / float(GameConfig.CELL_COUNT)
		ck("%s bahcenin cogu cim" % vid, share >= 0.45, "%.0f%%" % (share * 100.0))
	# Variety: the review counted four layouts, ten of them "open".
	ck("en az sekiz farkli dizilim kullanimda", layouts.size() >= 8, str(layouts))
	var most := 0
	for k: String in layouts:
		most = maxi(most, int(layouts[k]))
	ck("hicbir dizilim yedi bolumden fazla degil", most <= 7, str(layouts))
	print("  [olcum] dizilimler: %s" % str(layouts))


func _near_wide_lane(model: LawnModel, col: int, row: int) -> bool:
	for dc: int in [-1, 0, 1]:
		for dr: int in [-1, 0, 1]:
			if _in_wide_lane(model, col + dc, row + dr):
				return true
	return false


func _in_wide_lane(model: LawnModel, col: int, row: int) -> bool:
	for dc: int in [-1, 0]:
		for dr: int in [-1, 0]:
			var ok := true
			for c: int in [col + dc, col + dc + 1]:
				for r: int in [row + dr, row + dr + 1]:
					if not model.is_mowable(c, r):
						ok = false
			if ok:
				return true
	return false


func _fill(model: LawnModel, start: Vector2i, open: Callable) -> int:
	var seen := {}
	var queue: Array[Vector2i] = [start]
	seen[start] = true
	while not queue.is_empty():
		var at: Vector2i = queue.pop_back()
		for step: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var next := at + step
			if seen.has(next) or not LawnModel.in_bounds(next.x, next.y):
				continue
			if not bool(open.call(next)):
				continue
			seen[next] = true
			queue.append(next)
	return seen.size()
