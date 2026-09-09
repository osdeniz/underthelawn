extends TestBase
## The page the Marshal writes when a case closes (G52): his own file, with
## the player's own deductions in it.

func run() -> void:
	suite = "SERIF SAYFASI"
	var kept_dog: Variant = GameState.get_setting("story", "dog_name", "")
	DogName.store("Duman")
	ChapterProgress.reset()
	DeductionLog.reset()

	# Case 01 finished, with two of its deductions worked out and one from
	# Case 02 that must NOT appear on this page.
	var chapters: Array = Story.list("chapters")
	for any: Variant in chapters:
		var vid := str((any as Dictionary).get("variant_id", ""))
		var count := LevelVariant.of(vid).evidence_count()
		ChapterProgress.record(vid, count, count)
	var mine: Array = []
	var theirs := {}
	for any: Variant in DeductionLog.links():
		var link: Dictionary = any
		var chapter := DeductionLog.chapter_of(str(link.get("a", "")))
		var in_case_one := false
		for c: Variant in chapters:
			if str((c as Dictionary).get("variant_id", "")) == chapter:
				in_case_one = true
		if in_case_one and mine.size() < 2:
			mine.append(link)
			DeductionLog.make(str(link.get("a", "")), str(link.get("b", "")))
		elif not in_case_one and theirs.is_empty():
			theirs = link
			DeductionLog.make(str(link.get("a", "")), str(link.get("b", "")))
	ck("kurulum: iki vaka-1 bagi", mine.size() == 2, str(mine.size()))
	ck("kurulum: bir yabanci bag", not theirs.is_empty(), "")

	var page := MarshalPage.open(self, "case_01")
	await frames(4)
	ck("sayfa parsomen uzerinde", page.find_child("Paper", true, false) != null, "")
	ck("sayfa yaziyor", page._typer.typing(), "")
	ck("yazarken ipucu gizli", not page._hint.visible, "")
	page._typer.finish()
	await frames(2)
	ck("bitince ipucu gorunur", page._hint.visible, "")

	var text := _text_of(page)
	ck("vakayi adiyla acar",
		text.contains(tr("CASE_01_ID")) and text.contains(tr("CASE_01_TITLE")), "")
	ck("ne bulundugunu sayar", text.contains(tr("PAGE_FOUND").format({
		"found": page._evidence_found(), "total": page._evidence_total(),
		"yards": page._yards_done()})), "")
	ck("butun bahceler sayildi", page._yards_done() == chapters.size(),
		"%d / %d" % [page._yards_done(), chapters.size()])
	ck("oyuncunun kendi cikarimlari sayfada",
		text.contains(tr(str((mine[0] as Dictionary).get("note", ""))))
		and text.contains(tr(str((mine[1] as Dictionary).get("note", "")))), "")
	ck("baska vakanin cikarimi sayfada YOK",
		not text.contains(tr(str(theirs.get("note", "")))), "")
	ck("kopegin adi gecer", text.contains("Duman"), "")
	ck("imzali", text.contains(tr("PAGE_SIGNED")), "")
	ck("yer tutucu kalmadi", not text.contains("{"), "")

	# The two taps, then it closes.
	var done := [false]
	page.finished.connect(func() -> void: done[0] = true)
	page._lock = 0.0
	page._gui_input(_tap())
	await settle(MarshalPage.FADE + 0.3)
	ck("dokunus sayfayi kapatir", done[0], "")

	# With nothing worked out, the page says so plainly instead of listing.
	DeductionLog.reset()
	var bare := MarshalPage.open(self, "case_01")
	await frames(4)
	bare._typer.finish()
	await frames(1)
	var bare_text := _text_of(bare)
	ck("cikarim yoksa duz soyler", bare_text.contains(tr("PAGE_NO_LINKS")), "")
	ck("cikarim yoksa baslik da yok", not bare_text.contains(tr("PAGE_LINKS")), "")
	bare.queue_free()
	await frames(2)

	# Each case has its own closing line, and each page uses its own.
	for key: String in ["case_01", "case_02", "case_03"]:
		var closing := key.to_upper() + "_PAGE_CLOSE"
		ck("kapanis satiri yazili: %s" % key, tr(closing) != closing, closing)
		var one := MarshalPage.open(self, key)
		await frames(3)
		one._typer.finish()
		await frames(1)
		ck("%s sayfasi kendi satirini kullanir" % key,
			_text_of(one).contains(DogName.fill(tr(closing))), key)
		one.queue_free()
		await frames(2)

	DeductionLog.reset()
	ChapterProgress.reset()
	GameState.set_setting("story", "dog_name", kept_dog)
	finish()


func _text_of(page: Node) -> String:
	var out := ""
	for any: Variant in page.find_children("*", "Label", true, false):
		out += (any as Label).text + "\n"
	return out


func _tap() -> InputEventMouseButton:
	var tap := InputEventMouseButton.new()
	tap.pressed = true
	tap.button_index = MOUSE_BUTTON_LEFT
	return tap
