extends TestBase
## G15.5: three chapters that change what the thumb does. Each claim is driven
## the way the player would drive it — a pass over a cell, a walker stepping
## in, time going by — and read back off the model.



func run() -> void:
	suite = "MEKANIK"
	GameState.set_setting("meta", "orientation_done", true)
	await _fragile()
	await _walk_only()
	await _time_lapse()
	await _observer()
	await _harvest_settler()


## ch08: the drawing is fragile. Cut beside it and it comes up whole; drive
## over it and it comes up torn.
func _fragile() -> void:
	var game: Node = await open("ch08_cellar")
	var model: LawnModel = game.model
	var fragile := -1
	for k in game.variant.evidence_defs.size():
		if game.variant.is_fragile(k):
			fragile = k
	ck("ch08'de kirilgan kanit var", fragile >= 0, "yok")
	if fragile < 0 or model.secret_cells.size() <= fragile:
		game.queue_free(); await frames(4); return
	var cell: Vector2i = model.secret_cells[fragile]
	# A cuttable neighbour, mown: the piece is revealed without a pass over it.
	var side := Vector2i(-1, -1)
	for step: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var n := cell + step
		if LawnModel.in_bounds(n.x, n.y) \
				and model.states[LawnModel.index_of(n.x, n.y)] == LawnModel.CellState.TALL:
			side = n
			break
	ck("kirilganin yaninda bicilebilir hucre var", side.x >= 0, "yok")
	if side.x >= 0:
		model.mow(side.x, side.y, 0)
		await frames(3)
		ck("yanindan bicince ortaya cikiyor",
			model.states[LawnModel.index_of(cell.x, cell.y)] == LawnModel.CellState.SECRET_REVEALED,
			"durum %d" % model.states[LawnModel.index_of(cell.x, cell.y)])
		ck("yanindan bicince ezilmiyor", game.crushed_count == 0, "%d" % game.crushed_count)
	# The OTHER piece is not fragile: a pass over it is the ordinary find.
	var other := -1
	for k in model.secret_cells.size():
		if k != fragile:
			other = k
	if other >= 0:
		var oc: Vector2i = model.secret_cells[other]
		model.mow(oc.x, oc.y, 0)
		await frames(3)
		ck("kirilgan olmayan ezilmiyor", game.crushed_count == 0, "%d" % game.crushed_count)
	game.queue_free(); await frames(4)

	# And a fresh cellar where the drawing IS driven over.
	game = await open("ch08_cellar")
	model = game.model
	var cell2: Vector2i = model.secret_cells[fragile]
	model.mow(cell2.x, cell2.y, 0)
	await frames(3)
	ck("ustunden gecince ezilmis sayiliyor", game.crushed_count == 1, "%d" % game.crushed_count)
	ck("ezilmis de olsa bulunmus",
		model.states[LawnModel.index_of(cell2.x, cell2.y)] == LawnModel.CellState.SECRET_REVEALED, "")
	var crushed_conv := Dialogue.conversation("debrief_ch08_cellar_full_crushed")
	ck("ezilmis debrief'i var", crushed_conv.size() >= 2, "%d satir" % crushed_conv.size())
	game.queue_free(); await frames(4)


## ch12: one piece is ringed with reeds. The machine is kept out of the ring;
## the walker steps in and the piece is found.
func _walk_only() -> void:
	var game: Node = await open("ch12_river_crossing")
	var model: LawnModel = game.model
	var cell: Vector2i = model.walk_only_cell
	ck("ch12'de yuruyerek bulunan kanit var", cell.x >= 0, "yok")
	if cell.x < 0:
		game.queue_free(); await frames(4); return
	var ring_ok := true
	for dr in range(-1, 2):
		for dc in range(-1, 2):
			if dr == 0 and dc == 0:
				continue
			var c := cell.x + dc
			var r := cell.y + dr
			if LawnModel.in_bounds(c, r) \
					and model.states[LawnModel.index_of(c, r)] != LawnModel.CellState.OBSTACLE:
				ring_ok = false
	ck("sazlik halkasi engel", ring_ok, "acik hucre var")
	ck("sazliklar cizildi", game.find_children("Reeds", "", true, false).size() == 1, "")
	# The machine, placed on the piece, is pushed back out of the ring.
	var at := LawnModel.cell_center(cell.x, cell.y)
	var mower: MowerController = game.mower
	mower.global_position = Vector3(at.x, mower.global_position.y, at.z)
	mower._resolve_obstacles()
	var gap := Vector2(mower.position.x - at.x, mower.position.z - at.z).length()
	ck("makine halkanin disina itiliyor", gap > 1.4, "%.2f birim" % gap)
	ck("makineyle bulunmadi",
		model.states[LawnModel.index_of(cell.x, cell.y)] == LawnModel.CellState.SECRET, "")
	# On foot: step onto it.
	game.toggle_walk()
	await frames(4)
	var walker: Node3D = game.get_node("Walker")
	walker.position = Vector3(at.x, 0.0, at.z)
	await frames(4)
	ck("yuruyerek bulunuyor",
		model.states[LawnModel.index_of(cell.x, cell.y)] == LawnModel.CellState.SECRET_REVEALED, "")
	game.queue_free(); await frames(4)


## ch06: the light moves from sunset to night over the search.
func _time_lapse() -> void:
	var game: Node = await open("ch06_watertower")
	var sun: DirectionalLight3D = game.get_node("Sun")
	var start_elev := sun.rotation_degrees.x
	ck("ch06'nin gun batimi akisi var", not game.variant.time_lapse.is_empty(), "yok")
	game._search_seconds = float(game.variant.time_lapse.get("seconds", 150)) * 1.05
	game._tick_lapse()
	await frames(2)
	var night: Dictionary = GameConfig.TIME_OF_DAY["night"]
	ck("sure dolunca gunes gece konumunda",
		absf(sun.rotation_degrees.x - (-float(night["elev"]))) < 0.5,
		"%.1f, baslangic %.1f" % [sun.rotation_degrees.x, start_elev])
	ck("saat kovasi geceye dondu", game._lapse_bucket == "night", game._lapse_bucket)
	# And halfway is genuinely between: not one preset snapped to the other.
	game._search_seconds = float(game.variant.time_lapse.get("seconds", 150)) * 0.5
	game._tick_lapse()
	var sunset: Dictionary = GameConfig.TIME_OF_DAY["sunset"]
	var mid := -lerpf(float(sunset["elev"]), float(night["elev"]), 0.5)
	ck("yarida isik ikisinin arasinda", absf(sun.rotation_degrees.x - mid) < 0.5,
		"%.1f vs %.1f" % [sun.rotation_degrees.x, mid])
	print("  [olcum] gunes: baslangic %.1f, yari %.1f, gece %.1f" % [start_elev, mid, -float(night["elev"])])
	# G18.1: the dark costs speed. Measured on the mower, not on the formula.
	var full: float = game.mower.max_speed() / game.mower.speed_scale
	ck("gun batimindan once hiz tam", is_equal_approx(game.mower.speed_scale, 1.0),
		"%.2f" % game.mower.speed_scale)
	game._search_seconds = float(game.variant.time_lapse.get("seconds", 150)) * 0.75
	game._tick_lapse()
	var mid_scale: float = game.mower.speed_scale
	ck("gece cokerken hiz ikisinin arasinda",
		mid_scale < 0.99 and mid_scale > GameConfig.DARK_SPEED_MIN + 0.01, "%.2f" % mid_scale)
	game._search_seconds = float(game.variant.time_lapse.get("seconds", 150)) * 1.2
	game._tick_lapse()
	ck("sure dolunca hiz tabanda",
		is_equal_approx(game.mower.speed_scale, GameConfig.DARK_SPEED_MIN),
		"%.2f" % game.mower.speed_scale)
	ck("makinenin azami hizi gercekten dustu",
		absf(game.mower.max_speed() - full * GameConfig.DARK_SPEED_MIN) < 0.001,
		"%.2f vs %.2f" % [game.mower.max_speed(), full])
	ck("HUD karanlik satirina gecti", game.hud._case_line.text == tr("HUD_DARK_LINE"),
		game.hud._case_line.text)
	# What it costs: the second half of the yard at the average dark speed.
	var avg := (1.0 + GameConfig.DARK_SPEED_MIN) * 0.5
	var extra_days := (0.5 / avg - 0.5) * float(game.variant.time_lapse.get("seconds", 150)) \
		/ GameConfig.FOOD_DAY_SECONDS
	print("  [olcum] karanlik cezasi: ikinci yari %.0f%% daha uzun, ~%.1f gun daha yemek" \
		% [(1.0 / avg - 1.0) * 100.0, extra_days])
	game.queue_free(); await frames(4)


## ch14: a man on the ridge as the yard opens; gone once the machine is near.
func _observer() -> void:
	var game: Node = await open("ch14_listening_post")
	var who: Node3D = game.find_child("Observer", true, false)
	ck("sirtta gozlemci var", who != null and who.visible, "yok")
	if who == null:
		game.queue_free(); await frames(4); return
	var far: float = game.mower.global_position.distance_to(who.global_position)
	ck("baslangicta uzakta", far > GameConfig.OBSERVER_VANISH_RANGE, "%.1f" % far)
	game.mower.global_position = who.global_position + Vector3(0.0, 0.0, 3.0)
	await frames(3)
	ck("yaklasinca kayboluyor", not who.visible, "hala gorunur")
	ck("bir kez konusuyor", game._observer_gone, "")
	ck("gozlemci satiri var", Dialogue.conversation("chat_ch14_observer").size() == 1, "")
	game.queue_free(); await frames(4)


## A harvest: nobody by the barn until somebody has been taken in; then the
## newest settler, and two lines with their name written in.
func _harvest_settler() -> void:
	Settlers.reset()
	var game: Node = await open("harvest_field")
	ck("yerlesimci yokken figur yok", game.find_child("HarvestSettler", true, false) == null, "var")
	ck("yerlesimci yokken sohbet yok",
		game._settler_lines(Dialogue.conversation("chat_harvest"))[0]["text"] == "DLG_CHAT_HARVEST_1",
		"degistirilmis")
	game.queue_free(); await frames(4)
	var first: Dictionary = Settlers.all()[0]
	Settlers.accept(str(first["id"]))
	game = await open("harvest_field")
	ck("yerlesimci gelince figur var", game.find_child("HarvestSettler", true, false) != null, "yok")
	var lines: Array = game._settler_lines(Dialogue.conversation("chat_harvest"))
	var who := tr(str(first["name"]))
	ck("satirda yerlesimcinin adi var", str(lines[0]["text"]).find(who) >= 0,
		"%s icinde %s yok" % [lines[0]["text"], who])
	ck("harvest sohbeti bagli", game.variant.mid_chat_key(0) == GameConfig.HARVEST_CHAT_KEY, "")
	print("  [olcum] hasat satiri: %s" % lines[0]["text"])
	Settlers.reset()
	game.queue_free(); await frames(4)


