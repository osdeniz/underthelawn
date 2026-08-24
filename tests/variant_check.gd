extends SceneTree
## G9: the variation system and the scrap economy, checked on the real data.

var _fails := 0


func _initialize() -> void:
	_check_variants()
	_check_grid_follows_data()
	_check_layouts()
	_check_economy()
	if _fails > 0:
		push_error("%d VARYANT TESTI BASARISIZ" % _fails)
		print("--- %d VARYANT TESTI BASARISIZ ---" % _fails)
	else:
		print("--- TUM VARYANT TESTLERI GECTI ---")
	quit()


func _check_variants() -> void:
	var ids := LevelVariant.ids()
	ck("8 varyant", ids.size() == 8, str(ids.size()))
	var palettes := {}
	var landmarks := {}
	for id: String in ids:
		var v := LevelVariant.of(id)
		ck("palet tanimli: %s" % v.palette_id,
			GameConfig.GRASS_PALETTES.has(v.palette_id), v.palette_id)
		ck("grid boyutu tanimli: %s" % v.grid_size,
			GameConfig.GRID_SIZES.has(v.grid_size), v.grid_size)
		ck("engel duzeni tanimli: %s" % v.obstacle_layout_id,
			LawnModel.OBSTACLE_LAYOUTS.has(v.obstacle_layout_id),
			v.obstacle_layout_id)
		ck("ev varyanti tanimli: %s" % v.house_variant,
			GameConfig.HOUSE_VARIANTS.has(v.house_variant), v.house_variant)
		if v.landmark_id != "":
			ck("landmark tanimli: %s" % v.landmark_id,
				GameConfig.LANDMARK_IDS.has(v.landmark_id), v.landmark_id)
			landmarks[v.landmark_id] = true
		ck("%s iki kanit tasiyor" % id, v.evidence_count() == 2,
			str(v.evidence_count()))
		ck("%s scrap butcesi makul" % id,
			v.scrap_budget >= 7 and v.scrap_budget <= 12, str(v.scrap_budget))
		# decor_seed is what makes a yard look the same on every visit.
		ck("%s decor_seed sifir degil" % id, v.decor_seed != 0, str(v.decor_seed))
		palettes[v.palette_id] = true
	# Eight chapters must not reuse one palette, or they read as one place.
	ck("her bolumun kendi paleti", palettes.size() == 8, str(palettes.size()))
	ck("dort landmark kullanilmis", landmarks.size() == 4, str(landmarks.keys()))


## The whole point of the sprint: the grid comes from data, and everything that
## reads the grid follows it.
func _check_grid_follows_data() -> void:
	for id: String in LevelVariant.ids():
		var v := LevelVariant.of(id)
		v.apply()
		var expected: Vector2i = GameConfig.GRID_SIZES[v.grid_size]
		ck("%s grid uyuyor" % id,
			GameConfig.GRID_COLS == expected.x and GameConfig.GRID_ROWS == expected.y,
			"%dx%d" % [GameConfig.GRID_COLS, GameConfig.GRID_ROWS])
		ck("%s hucre sayisi tutarli" % id,
			GameConfig.CELL_COUNT == expected.x * expected.y,
			str(GameConfig.CELL_COUNT))
		ck("%s yari genislik tutarli" % id,
			is_equal_approx(GameConfig.HALF_X, float(expected.x) * 0.5)
			and is_equal_approx(GameConfig.HALF_Z, float(expected.y) * 0.5), "")
		ck("%s palet uygulandi" % id,
			GameConfig.active_grass_palette == v.palette_id,
			GameConfig.active_grass_palette)

		var model := LawnModel.new(v.decor_seed)
		ck("%s model gridi dolu" % id,
			model.states.size() == expected.x * expected.y,
			str(model.states.size()))
		# Enough mowable ground to be a level at all, and the robot's route
		# planner must cover it without running off the grid.
		ck("%s bicilebilir alan var" % id, model.mowable_cells > 40,
			str(model.mowable_cells))
		var route := MowerMath.build_robot_route(model)
		ck("%s robot rotasi grid icinde" % id, route.size() > 0, str(route.size()))
		for cell: Vector2i in route:
			if not LawnModel.in_bounds(cell.x, cell.y):
				ck("%s rota grid disina cikti" % id, false, str(cell))
				break
		# Both evidence slots must land on real cells.
		ck("%s iki kanit yerlesti" % id, model.secret_cells.size() == 2,
			str(model.secret_cells.size()))
	# Leave the engine on the default yard for anything that runs after.
	GameConfig.set_grid_named("medium")
	GameConfig.active_grass_palette = "GREEN"


func _check_layouts() -> void:
	for id: String in LawnModel.OBSTACLE_LAYOUTS:
		for size_id: String in GameConfig.GRID_SIZES:
			GameConfig.set_grid_named(size_id)
			var resolved := LawnModel.resolve_layout(id)
			for ob: Dictionary in resolved:
				var grid: Rect2i = ob["grid"]
				# A layout authored for a medium yard must still fit the cellar.
				ck("%s/%s engel grid icinde" % [id, size_id],
					grid.position.x >= 0 and grid.position.y >= 0
					and grid.end.x <= GameConfig.GRID_COLS
					and grid.end.y <= GameConfig.GRID_ROWS, str(grid))
	GameConfig.set_grid_named("medium")


func _check_economy() -> void:
	# An early exit must not read as a punishment: it has to pay a clear
	# majority of what a full mow pays.
	var early := ScrapField.payout(10, 0.45, 9)
	var full := ScrapField.payout(10, 1.0, 9)
	ck("erken cikis bir sey odiyor", int(early["total"]) > 0, str(early))
	ck("%100 en karli", int(full["total"]) > int(early["total"]),
		"%d vs %d" % [int(full["total"]), int(early["total"])])
	var share := float(early["total"]) / float(full["total"])
	ck("erken cikis payi %60-90 arasi", share >= 0.60 and share <= 0.90,
		"%.2f" % share)
	ck("eksiksiz arama primi yalniz %100'de",
		int(full["thorough"]) > 0 and int(early["thorough"]) == 0,
		"%d / %d" % [int(full["thorough"]), int(early["thorough"])])
	# The ground haul is meant to be the smaller half of the payout.
	ck("yerden toplama kucuk pay",
		float(full["ground"]) / float(full["total"]) < 0.5,
		"%.2f" % (float(full["ground"]) / float(full["total"])))

	# Scrap actually gets buried, and only on mowable cells.
	for id: String in LevelVariant.ids():
		var v := LevelVariant.of(id)
		v.apply()
		var model := LawnModel.new(v.decor_seed)
		var field := ScrapField.new()
		field.setup(model, v.scrap_budget, v.decor_seed)
		ck("%s butce kadar scrap gomuldu" % id,
			field.remaining() == v.scrap_budget,
			"%d/%d" % [field.remaining(), v.scrap_budget])
		for cell: Vector2i in field.cells():
			if not model.is_mowable(cell.x, cell.y):
				ck("%s scrap bicilemez hucrede" % id, false, str(cell))
				break
		# Placement must be repeatable: same seed, same spots.
		var again := ScrapField.new()
		again.setup(model, v.scrap_budget, v.decor_seed)
		ck("%s scrap yerlesimi tekrarlanabilir" % id,
			again.cells() == field.cells(), "")
	GameConfig.set_grid_named("medium")
	GameConfig.active_grass_palette = "GREEN"


func ck(label: String, passed: bool, detail: String) -> void:
	if passed:
		return
	_fails += 1
	print("  FAIL %s  %s" % [label, detail])
