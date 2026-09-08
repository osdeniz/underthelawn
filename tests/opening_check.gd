extends TestBase
## The first five minutes (G36): the first-run flag survives the road and the
## sheet shows on the first yard; the road ends at the fence; the trial has
## no robot; the corridor after the road is shorter; no card line runs long.

func run() -> void:
	suite = "ACILIS"
	var keep: Variant = GameState.get_setting("meta", "orientation_done", false)

	# The road does not burn the flag.
	GameState.set_setting("meta", "orientation_done", false)
	var road := await open("ch00_the_long_walk", false)
	ck("yolda ilk-kosu bayragi kapali", not road._first_run, "")
	await settle(GameConfig.FIRST_RUN_MODAL_AFTER + 1.0)
	ck("yol bayragi yakmaz", GameState.is_first_run(), "")
	ck("yolda yonlendirme sayfasi yok", road.hud.find_child("OrientationDim", true, false) == null, "")
	ck("denemede traktor acik", Garage.is_unlocked(GameConfig.MOWER_TRACTOR), "")
	ck("denemede robot kapali", not Garage.is_unlocked(GameConfig.MOWER_ROBOT), "")
	# A lane up the road: the level ends when the far rows are reached.
	var col := GameConfig.GRID_COLS / 2
	for row in range(GameConfig.GRID_ROWS - 1, 1, -1):
		if road.model.is_mowable(col, row):
			road.model.mow(col, row, 0)
	await frames(2)
	ck("serit acilirken bitmez", not road._complete_shown, "")
	ck("ilerleme seritle artar", road._road_progress() > 0.8, str(road._road_progress()))
	var top := 1 if road.model.is_mowable(col, 1) else 0
	if not road.model.is_mowable(col, top):
		for c in GameConfig.GRID_COLS:
			if road.model.is_mowable(c, 1):
				col = c
				top = 1
				break
	road.model.mow(col, top, 0)
	await frames(3)
	ck("cite varinca yol biter", road._complete_shown, "")
	close(road)

	# The first yard shows the sheet, pauses, and the OK button lets go.
	GameState.set_setting("meta", "orientation_done", false)
	var yard := await open("ch01_aldridge", false)
	ck("bahcede ilk-kosu bayragi acik", yard._first_run, "")
	ck("bahce modeli kendi izgarasinda", yard.model.states.size() == GameConfig.CELL_COUNT,
		"%d / %d" % [yard.model.states.size(), GameConfig.CELL_COUNT])
	await settle(GameConfig.FIRST_RUN_MODAL_AFTER + 1.0)
	var dim: Node = yard.hud.find_child("OrientationDim", true, false)
	ck("ilk bahcede yonlendirme sayfasi cikar", dim != null, "")
	# The harness unpauses every frame, so the pause itself cannot be read
	# here; the sheet's own process mode is what lets its button work paused.
	ck("sayfa duraklamada da calisir", dim == null or dim.process_mode == Node.PROCESS_MODE_ALWAYS, "")
	if dim != null:
		var go: Button = null
		for b in dim.find_children("*", "Button", true, false):
			go = b as Button
		ck("sayfada ARAMAYA BASLA var", go != null and go.text == tr("FIRST_OK"), "" if go == null else go.text)
		if go != null:
			go.pressed.emit()
			await frames(2)
			ck("dugme sayfayi kapatir", yard.hud.find_child("OrientationDim", true, false) == null, "")
			ck("gomulerin etrafi isaretli", yard.lawn.hint_count() > 0, str(yard.lawn.hint_count()))
	ck("bayrak artik sonmus", not GameState.is_first_run(), "")
	close(yard)
	GameState.set_setting("meta", "orientation_done", keep)

	# The corridor after the road.
	ck("yol sonrasi tek kart", Story.list("intro.after_prologue").size() == 1, "")
	ck("yol diyalogu 5 satir", Dialogue.conversation("pro_road").size() == 5, str(Dialogue.conversation("pro_road").size()))
	ck("brifing 3 girdi", Dialogue.conversation("brief_ch01").size() == 3, str(Dialogue.conversation("brief_ch01").size()))
	var longest := 0
	var where := ""
	for path in ["prologue.cards", "prologue.after", "intro.cards", "intro.after_prologue"]:
		for card: Dictionary in Story.list(path):
			for key in card.get("lines", []):
				for locale in ["en", "tr"]:
					var tobj: Translation = TranslationServer.get_translation_object(locale)
					var text: String = str(tobj.get_message(str(key))) if tobj != null else ""
					var n := text.split(" ", false).size()
					if n > longest:
						longest = n
						where = "%s %s" % [locale, key]
	ck("kart satirlari 16 kelimeyi asmaz", longest <= 16, "%d @ %s" % [longest, where])
	ck("ve oncesi virgul yok", not tr("PRO_05_L1").contains(", ve "), tr("PRO_05_L1"))
	finish()
