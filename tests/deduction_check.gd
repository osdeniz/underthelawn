extends TestBase
## Two finds that mean one thing (G48): the link table, and the Journal that
## lets a player put two discoveries together.

func run() -> void:
	suite = "CIKARIM"
	DeductionLog.reset()

	# --- the table itself
	var links := DeductionLog.links()
	ck("bag tablosu var", links.size() >= 8, str(links.size()))
	var seen := {}
	var ok_sides := true
	var ok_text := true
	for any: Variant in links:
		var link: Dictionary = any
		var a := str(link.get("a", ""))
		var b := str(link.get("b", ""))
		var note := str(link.get("note", ""))
		if a == "" or b == "" or note == "":
			continue
		# Both sides must name a real piece of evidence in a real chapter, or
		# the Journal would offer a link nobody can ever make.
		if DeductionLog.name_of(a) == DeductionLog.evidence_of(a) \
				or DeductionLog.name_of(b) == DeductionLog.evidence_of(b):
			ok_sides = false
			print("  [olcum] eksik kanit: %s + %s" % [a, b])
		if tr(note) == note:
			ok_text = false
		seen[DeductionLog.key(a, b)] = true
	ck("her bagin iki yani gercek kanit", ok_sides, "")
	ck("her bagin metni cevrili", ok_text, "")
	ck("ayni cift iki kez yazilmamis", seen.size() == links.size(),
		"%d / %d" % [seen.size(), links.size()])

	# --- order does not matter, and a wrong pair is simply not a link
	var first: Dictionary = links[0]
	var a1 := str(first.get("a", ""))
	var b1 := str(first.get("b", ""))
	ck("sira onemsiz", not DeductionLog.find_link(b1, a1).is_empty(), "")
	ck("olmayan cift bag degil",
		DeductionLog.find_link(a1, "ch01_aldridge/radio_yok").is_empty(), "")
	ck("basta hicbiri kurulmamis", DeductionLog.made_count() == 0, "")
	DeductionLog.make(a1, b1)
	ck("kurulan bag hatirlanir", DeductionLog.is_made(b1, a1), "")
	ck("sayac artar", DeductionLog.made_count() == 1, "")
	ck("kayit bunu gorur", Achievements._holds("deduction"), "")
	DeductionLog.reset()
	ck("sifirlanir", DeductionLog.made_count() == 0, "")

	# --- the Journal: two taps ask the question
	# Everything found, so every discovery is on the list.
	ChapterProgress.reset()
	for chapter: Dictionary in ChapterProgress.chapters():
		var vid := str(chapter.get("variant_id", ""))
		ChapterProgress.record(vid, LevelVariant.of(vid).evidence_count(),
			LevelVariant.of(vid).evidence_count())
	var journal := JournalScreen.new()
	add_child(journal)
	await frames(3)
	journal._section = JournalScreen.Section.DISCOVERIES
	journal._refresh()
	await frames(2)
	ck("bulgular sekmesi ipucu veriyor", _has_text(journal, tr("LINK_HINT")), "")
	var pick_a: Button = journal.find_child(DeductionLog.node_name(a1), true, false)
	var pick_b: Button = journal.find_child(DeductionLog.node_name(b1), true, false)
	ck("bulgular dokunulabilir", pick_a != null and pick_b != null,
		"%s / %s" % [a1, b1])
	if pick_a == null or pick_b == null:
		journal.queue_free()
		finish()
		return
	pick_a.pressed.emit()
	await frames(1)
	ck("ilk dokunus parcayi tutar", journal._picked == a1, journal._picked)
	pick_a.pressed.emit()
	await frames(1)
	ck("ayni parcaya tekrar dokunmak birakir", journal._picked == "", journal._picked)

	pick_a.pressed.emit()
	pick_b.pressed.emit()
	await frames(2)
	ck("dogru cift bagi kurar", DeductionLog.is_made(a1, b1), "")
	ck("Serif cikarimi soyler",
		journal._answer_card.visible
		and journal._answer.text == tr(str(first.get("note", ""))),
		journal._answer.text)
	ck("cevap listenin ustunde durur", journal._answer_card.z_index > 0,
		str(journal._answer_card.z_index))
	ck("cift kurulunca tutulan parca birakilir", journal._picked == "", "")
	ck("sayac cikarimi sayar",
		journal._counter.text.contains(tr("LINK_COUNT").format({"done": 1,
			"total": DeductionLog.total()})), journal._counter.text)

	# The same pair again says so rather than counting twice.
	journal.find_child(DeductionLog.node_name(a1), true, false).pressed.emit()
	journal.find_child(DeductionLog.node_name(b1), true, false).pressed.emit()
	await frames(2)
	ck("ayni bag iki kez sayilmaz", DeductionLog.made_count() == 1,
		str(DeductionLog.made_count()))
	ck("zaten defterde diyor", journal._answer.text == tr("LINK_ALREADY"),
		journal._answer.text)

	# A wrong pair costs nothing but a flat answer.
	var other := str((links[1] as Dictionary).get("a", ""))
	if other != a1 and other != b1:
		journal.find_child(DeductionLog.node_name(a1), true, false).pressed.emit()
		journal.find_child(DeductionLog.node_name(other), true, false).pressed.emit()
		await frames(2)
		var flat := journal._answer.text == tr("LINK_NO_1") \
			or journal._answer.text == tr("LINK_NO_2") \
			or journal._answer.text == tr("LINK_NO_3")
		ck("yanlis cift duz bir cevap alir", flat, journal._answer.text)
		ck("yanlis cift bir sey kaybettirmez", DeductionLog.made_count() == 1, "")

	# The deduction is in the notes, in the Marshal's own words.
	# Changing tab through the tab button, as a player does: the answer is put
	# away with the tap that asked for it.
	for any: Variant in journal._tabs.get_children():
		var tab := any as Button
		if int(tab.get_meta("section", -1)) == int(JournalScreen.Section.NOTES):
			tab.pressed.emit()
	await frames(2)
	ck("sekme degisince cevap kalkar", not journal._answer_card.visible, "")
	ck("cikarim notlara gecer", _has_text(journal, tr(str(first.get("note", "")))), "")
	ck("cikarim basligi var", _has_text(journal, tr("LINK_HEADER").to_upper()), "")
	journal.queue_free()
	DeductionLog.reset()
	ChapterProgress.reset()
	finish()


func _has_text(journal: Node, wanted: String) -> bool:
	for any: Variant in journal.find_children("*", "Label", true, false):
		if (any as Label).text == wanted:
			return true
	return false
