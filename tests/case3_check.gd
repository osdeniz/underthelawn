extends TestBase
## G17: Case 03 exists in the data, hangs together, opens when it should, and
## ends on a choice that leads to one of two mornings.

func run() -> void:
	suite = "VAKA 03"
	var chapters := Story.list("case_03.chapters")
	ck("sekiz bolum", chapters.size() == 8, str(chapters.size()))
	var seen := {}
	for chapter: Dictionary in chapters:
		var id := str(chapter.get("variant_id", ""))
		ck("bolum id benzersiz: %s" % id, not seen.has(id)); seen[id] = true
		ck("bolum verisi var: %s" % id, LevelVariant.ids().has(id))
		if not LevelVariant.ids().has(id):
			continue
		var v := LevelVariant.of(id)
		ck("landmark gecerli: %s" % id, GameConfig.LANDMARK_IDS.has(v.landmark_id), v.landmark_id)
		ck("palet gecerli: %s" % id, GameConfig.GRASS_PALETTES.has(v.palette_id), v.palette_id)
		ck("izgara gecerli: %s" % id, GameConfig.GRID_SIZES.has(v.grid_size), v.grid_size)
		ck("iki kanit: %s" % id, v.evidence_count() == 2, str(v.evidence_count()))
		ck("brief var: %s" % id, not Dialogue.conversation(str(chapter.get("brief", ""))).is_empty())
		ck("kismi debrief var: %s" % id, not Dialogue.conversation(str(chapter.get("debrief_partial", ""))).is_empty())
		if id != "ch26_the_visit":
			ck("tam debrief var: %s" % id, not Dialogue.conversation(str(chapter.get("debrief_full", ""))).is_empty())
	ck("ch21'de kirilgan tebesir", LevelVariant.of("ch21_school_field").is_fragile(0))
	ck("ch23 yuruyerek", LevelVariant.of("ch23_the_grave_row").walk_only_evidence)
	ck("finale var", Dialogue.conversation("finale_case03").size() == 6)
	ck("iki sabah var", Story.list("endings.open.cards").size() == 2
		and Story.list("endings.closed.cards").size() == 2)

	# The gate opens on Case 02's close, and the chapter list grows to 26.
	var was: Variant = GameState.get_setting("story", "case02_closed", false)
	GameState.set_setting("story", "case02_closed", false)
	ck("vaka 02 kapanmadan vaka 03 kapali", not ChapterProgress.case_three_open())
	var before := ChapterProgress.chapters().size()
	GameState.set_setting("story", "case02_closed", true)
	ck("vaka 02 kapaninca vaka 03 acik", ChapterProgress.case_three_open())
	ck("liste 26'ya cikiyor", ChapterProgress.chapters().size() == 26,
		"%d -> %d" % [before, ChapterProgress.chapters().size()])
	ck("case_of ch26 -> vaka 03", ChapterProgress.case_of("ch26_the_visit").size() == 8)
	GameState.set_setting("story", "case02_closed", was)

	# The card: two pages by tap, then two buttons, each ending the card with
	# its answer.
	for open: bool in [true, false]:
		var card: Control = load("res://scripts/gate_card.gd").new()
		add_child(card)
		await frames(2)
		card.advance()
		card.advance()
		await frames(1)
		var button: Button = card.find_child("Open" if open else "Close", true, false)
		ck("kapi dugmesi var (%s)" % open, button != null)
		var got := [null]
		card.chosen.connect(func(o: bool) -> void: got[0] = o)
		if button != null:
			button.pressed.emit()
		await settle(0.7)
		ck("secim iletiliyor (%s)" % open, got[0] == open, str(got[0]))
