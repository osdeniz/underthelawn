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
	await _watchers()
	finish()


## The town notices how you cut (G50): from the second patterned yard on,
## neighbours are at the side fence when you arrive.
func _watchers() -> void:
	var kept := {}
	for id in [MowPattern.ROWS, MowPattern.RINGS, MowPattern.CROSS]:
		kept[id] = MowPattern.count(id)
		GameState.set_setting(MowPattern.SECTION, id, 0)
	var kept_tip: Variant = GameState.get_setting("tips", "watchers", false)

	ck("desensiz kimse gelmez", MowPattern.watchers() == 0, str(MowPattern.watchers()))
	MowPattern.record(MowPattern.ROWS)
	ck("ilk desenli bahceden sonra hala kimse yok", MowPattern.watchers() == 0,
		str(MowPattern.watchers()))
	MowPattern.record(MowPattern.RINGS)
	ck("ikincisinden sonra bir izleyici", MowPattern.watchers() == 1,
		str(MowPattern.watchers()))
	for i in 8:
		MowPattern.record(MowPattern.CROSS)
	ck("sayi ustte durur", MowPattern.watchers() == GameConfig.WATCHERS_MAX,
		str(MowPattern.watchers()))

	# Two patterned yards' worth, and a yard to see them in.
	for id in [MowPattern.ROWS, MowPattern.RINGS, MowPattern.CROSS]:
		GameState.set_setting(MowPattern.SECTION, id, 0)
	MowPattern.record(MowPattern.ROWS)
	MowPattern.record(MowPattern.RINGS)
	GameState.set_setting("tips", "watchers", false)
	var yard := await open("ch01_aldridge", false)
	await settle(0.5)
	var root: Node3D = yard.find_child("Watchers", true, false)
	ck("bahcede izleyiciler var", root != null and root.get_child_count() == 1,
		"" if root == null else str(root.get_child_count()))
	if root != null:
		var who := root.get_child(0) as Node3D
		ck("citin disinda duruyorlar",
			absf(who.position.x) > GameConfig.fence_side_x(),
			"%.2f > %.2f" % [absf(who.position.x), GameConfig.fence_side_x()])
		# Facing in. Read off the node's own forward axis rather than
		# re-deriving it: every model in this project faces -Z, so -basis.z IS
		# forward, and writing the trigonometry out again just invites a sign
		# error (it did — the first version of this claim had one).
		var facing := -who.global_transform.basis.z
		ck("bahceye bakiyorlar", signf(facing.x) == -signf(who.position.x),
			"%.2f / %.2f" % [facing.x, who.position.x])
		var lean := who.rotation.z
		await settle(0.6)
		ck("kipirdiyorlar", not is_equal_approx(who.rotation.z, lean),
			"%.4f -> %.4f" % [lean, who.rotation.z])
	ck("ilk gelislerinde bir kez soylenir",
		bool(GameState.get_setting("tips", "watchers", false)), "")
	close(yard)

	# A road has no side fence with a lane behind it.
	var road := await open("ch00_the_long_walk", false)
	await settle(0.3)
	ck("yolda izleyici yok", road.find_child("Watchers", true, false) == null, "")
	close(road)

	for id in [MowPattern.ROWS, MowPattern.RINGS, MowPattern.CROSS]:
		GameState.set_setting(MowPattern.SECTION, id, kept[id])
	GameState.set_setting("tips", "watchers", kept_tip)


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
