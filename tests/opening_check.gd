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
	# The trial belongs to the flow, not to the level, so it is set here rather
	# than read: without this the claim passed or failed on whatever the SAVE
	# happened to have unlocked, which is no claim at all.
	Garage.trial = true
	ck("denemede traktor acik", Garage.is_unlocked(GameConfig.MOWER_TRACTOR), "")
	ck("denemede robot kapali", not Garage.is_unlocked(GameConfig.MOWER_ROBOT), "")
	Garage.trial = false
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
	await _hold_to_skip()
	finish()


## Holding to skip (G40): a tap does not, a short press does not, a long one
## ends the whole sequence — and the bar shows it filling on the way.
func _hold_to_skip() -> void:
	var intro := IntroSequence.new()
	intro.cards_key = "prologue.cards"
	add_child(intro)
	var done := [false]
	intro.finished.connect(func() -> void: done[0] = true)
	await frames(6)
	var track: ColorRect = intro.find_child("SkipTrack", true, false)
	ck("atlama cubugu basta gizli", track != null and not track.visible, "")
	ck("atlama ipucu var",
		intro.find_child("SkipHint", true, false) != null
		and tr("INTRO_HOLD_SKIP") != "INTRO_HOLD_SKIP", "")

	# A tap: press then release, nothing skipped.
	intro._tap_lock = 0.0
	intro._gui_input(_press(true))
	intro._gui_input(_press(false))
	# Long enough to cover the hold AND the fade a skip would run: a hold left
	# counting by a swallowed release would have finished the sequence by now.
	await settle(GameConfig.INTRO_SKIP_HOLD + IntroSequence.FADE_TIME + 0.4)
	ck("dokunus atlamaz", not done[0], "")
	ck("dokunus sonrasi sayac durdu", intro._hold < 0.0, str(intro._hold))
	ck("birakinca cubuk gizlenir", not track.visible, "")

	# Half a hold: the bar shows, nothing skips.
	intro._tap_lock = 0.0
	intro._gui_input(_press(true))
	await settle(GameConfig.INTRO_SKIP_HOLD * 0.45)
	ck("yarim basisla atlamaz", not done[0], "")
	ck("basarken cubuk gorunur", track.visible, "")
	ck("cubuk doluyor", intro._skip_fill.size.x > 1.0 and intro._skip_fill.size.x < track.size.x,
		"%.1f / %.1f" % [intro._skip_fill.size.x, track.size.x])
	intro._gui_input(_press(false))
	ck("birakinca sifirlanir", intro._hold < 0.0, str(intro._hold))

	# The full hold.
	intro._tap_lock = 0.0
	intro._gui_input(_press(true))
	# The skip fires at INTRO_SKIP_HOLD and then fades out before it reports.
	await settle(GameConfig.INTRO_SKIP_HOLD + IntroSequence.FADE_TIME + 0.4)
	ck("uzun basis tum kartlari atlar", done[0], "")
	if is_instance_valid(intro):
		intro.queue_free()
	await frames(2)


func _press(down: bool) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.pressed = down
	event.button_index = MOUSE_BUTTON_LEFT
	return event
