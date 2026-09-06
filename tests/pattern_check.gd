extends TestBase
## Mowing patterns (G28): rows, rings and a crosshatch are read from the stripe
## directions; a free cut and a small cut say nothing; the panel shows the
## chip only when there is one; the count is kept.

func run() -> void:
	suite = "DESEN"
	var model := LawnModel.new(7)
	var cols := GameConfig.GRID_COLS
	var rows := GameConfig.GRID_ROWS

	# Straight rows: every column a pass, alternating north and south.
	_cut(model, func(col: int, _row: int) -> int: return 0 if col % 2 == 0 else 2)
	ck("sutun sutun gidip gelme = duz siralar", MowPattern.classify(model) == MowPattern.ROWS,
		MowPattern.classify(model))
	# Straight rows the other way.
	_cut(model, func(_col: int, row: int) -> int: return 1 if row % 2 == 0 else 3)
	ck("satir satir gidip gelme = duz siralar", MowPattern.classify(model) == MowPattern.ROWS,
		MowPattern.classify(model))
	# One direction only, never turning back: not rows (a tractor's single pass).
	_cut(model, func(_col: int, _row: int) -> int: return 0)
	ck("hep tek yon = desen yok", MowPattern.classify(model) == "", MowPattern.classify(model))
	# Rings: along each cell's nearest edge.
	_cut(model, func(col: int, row: int) -> int:
		var to_side := mini(col, cols - 1 - col)
		var to_end := mini(row, rows - 1 - row)
		return 0 if to_side < to_end else 1)
	ck("cit boyunca donerek = halkalar", MowPattern.classify(model) == MowPattern.RINGS,
		MowPattern.classify(model))
	# Crosshatch: the top half north-south, the bottom half east-west.
	_cut(model, func(col: int, row: int) -> int:
		return (0 if col % 2 == 0 else 2) if row < rows / 2 else (1 if row % 2 == 0 else 3))
	ck("iki eksen yari yariya = capraz", MowPattern.classify(model) == MowPattern.CROSS,
		MowPattern.classify(model))
	# Random: nothing.
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	_cut(model, func(_col: int, _row: int) -> int: return rng.randi_range(0, 3))
	ck("rastgele = desen yok", MowPattern.classify(model) == "", MowPattern.classify(model))
	# Too small to say.
	model.reset()
	for row in 2:
		for col in cols:
			if model.is_mowable(col, row):
				model.mow(col, row, 0 if col % 2 == 0 else 2)
	ck("kucuk kesim = desen yok", MowPattern.classify(model) == "", MowPattern.classify(model))
	ck("isim anahtarlari cevrili", tr(MowPattern.name_key(MowPattern.ROWS)) != "PATTERN_ROWS"
		and tr(MowPattern.stamp_key(MowPattern.RINGS)) != "PATTERN_STAMP_RINGS", "")
	ck("desensiz damga ARANDI", MowPattern.stamp_key("") == "POSTCARD_STAMP", "")
	for id in [MowPattern.ROWS, MowPattern.RINGS, MowPattern.CROSS]:
		ck("ikon var: %s" % id, UiIcons.pattern(id) != null, "")

	var before := MowPattern.count(MowPattern.ROWS)
	MowPattern.record(MowPattern.ROWS)
	ck("sayac artar", MowPattern.count(MowPattern.ROWS) == before + 1, "")
	GameState.set_setting(MowPattern.SECTION, MowPattern.ROWS, before)

	# The chip on the panel.
	var game := await open("ch01_aldridge")
	game.hud.show_complete(100, "1:00", [], 2, {"total": 10, "food": 0, "food_eaten": 0, "food_left": 5}, "")
	await frames(2)
	ck("desensiz panelde desen yazisi yok", _panel_has(game, tr("PATTERN_ROWS")) == false, "")
	game.hud.show_complete(100, "1:00", [], 2, {"total": 10, "food": 0, "food_eaten": 0, "food_left": 5,
		"pattern": MowPattern.ROWS}, "")
	await frames(2)
	ck("desenli panelde desen yazisi var", _panel_has(game, tr("PATTERN_ROWS")), "")
	close(game)
	finish()


func _cut(model: LawnModel, dir_of: Callable) -> void:
	model.reset()
	for row in GameConfig.GRID_ROWS:
		for col in GameConfig.GRID_COLS:
			if model.is_mowable(col, row):
				model.mow(col, row, int(dir_of.call(col, row)))


func _panel_has(game: Node, text: String) -> bool:
	for l in game.hud._payout_list.find_children("*", "Label", true, false):
		if (l as Label).text == text:
			return true
	return false
