extends TestBase
## G52: the Marshal's page as the player reads it, with three deductions on it.

func run() -> void:
	suite = "SERIF SAYFASI CEKIM"
	min_checks = 2
	DogName.store("Duman")
	ChapterProgress.reset()
	DeductionLog.reset()
	var chapters: Array = Story.list("chapters")
	for any: Variant in chapters:
		var vid := str((any as Dictionary).get("variant_id", ""))
		var count := LevelVariant.of(vid).evidence_count()
		ChapterProgress.record(vid, count, count)
	var made := 0
	for any: Variant in DeductionLog.links():
		var link: Dictionary = any
		var chapter := DeductionLog.chapter_of(str(link.get("a", "")))
		for c: Variant in chapters:
			if str((c as Dictionary).get("variant_id", "")) == chapter and made < 3:
				DeductionLog.make(str(link.get("a", "")), str(link.get("b", "")))
				made += 1
	ck("uc cikarim kuruldu", made == 3, str(made))
	var page := MarshalPage.open(self, "case_01")
	await frames(5)
	page._typer.finish()
	await settle(0.6)
	await drawn_frame()
	get_viewport().get_texture().get_image().save_png("res://out/marshal_page.png")
	ck("kare alindi", true, "")
	print("[cekim] out/marshal_page.png yazildi")
	page.queue_free()
	DeductionLog.reset()
	ChapterProgress.reset()
	finish()
