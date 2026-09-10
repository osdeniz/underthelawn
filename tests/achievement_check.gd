extends TestBase
## The records (G33): every id has a name and a line; nothing is earned on a
## blank save; each condition flips its record and only its record; the panel
## writes one line per fresh record; the Journal tab lists earned and open.

func run() -> void:
	suite = "KAYIT"
	Achievements.reset()
	for id in Achievements.ids():
		ck("adi var: %s" % id, tr(Achievements.name_key(id)) != Achievements.name_key(id), "")
		ck("satiri var: %s" % id, tr(Achievements.line_key(id)) != Achievements.line_key(id), "")
	var keep_dog := str(GameState.get_setting("story", "dog_name", ""))
	var keep_rings := MowPattern.count(MowPattern.RINGS)
	var keep_best := ThoroughStreak.best()
	GameState.set_setting("story", "dog_name", "")
	GameState.set_setting(MowPattern.SECTION, MowPattern.RINGS, 0)
	GameState.set_setting(ThoroughStreak.SECTION, ThoroughStreak.KEY_BEST, 0)
	var before := Achievements.evaluate()
	ck("temiz durumda halka/kopek/titiz yok", not Achievements.is_earned("rings_1")
		and not Achievements.is_earned("dog_named") and not Achievements.is_earned("thorough_3"), str(before))

	DogName.store("Duman")
	var fresh := Achievements.evaluate()
	ck("isim kaydi gelir", fresh.has("dog_named") and Achievements.is_earned("dog_named"), str(fresh))
	ck("tarih yazilir", Achievements.earned_on("dog_named").length() >= 8, Achievements.earned_on("dog_named"))
	ck("ikinci degerlendirme tekrar vermez", not Achievements.evaluate().has("dog_named"), "")

	MowPattern.record(MowPattern.RINGS)
	ck("halka kaydi gelir", Achievements.evaluate().has("rings_1"), "")
	ThoroughStreak.reset()
	ThoroughStreak.bump(true); ThoroughStreak.bump(true)
	ck("iki titiz yetmez", not Achievements.evaluate().has("thorough_3"), "")
	ThoroughStreak.bump(true)
	ck("uc titiz kaydi gelir", Achievements.evaluate().has("thorough_3"), "")
	ThoroughStreak.bump(false)
	ck("seri kirilsa da kayit kalir", Achievements.is_earned("thorough_3"), "")
	ck("sayac dogru", Achievements.earned_count() >= 3, str(Achievements.earned_count()))

	# The panel line.
	var game := await open("ch01_aldridge")
	game.hud.show_complete(100, "1:00", [], 2, {"total": 10, "records": ["rings_1"]}, "")
	await frames(1)
	ck("panel kaydi yazar", game.hud._notes_progress.text.contains(
		tr("ACH_WRITTEN_LINE").format({"name": tr("ACH_RINGS_1")})), game.hud._notes_progress.text)
	close(game)

	# The Journal tab.
	var journal := JournalScreen.new()
	add_child(journal)
	await frames(2)
	journal._section = JournalScreen.Section.RECORDS
	journal._refresh()
	await frames(1)
	var labels := journal._list.find_children("*", "Label", true, false)
	var has_earned := false
	var has_open := false
	for l in labels:
		if (l as Label).text == tr("ACH_RINGS_1"):
			has_earned = true
		# LocaleSupport.upper, not to_upper: the journal shouts its headings in
		# the reader's language now, so "Henüz değil" is HENÜZ DEĞİL (G67).
		if (l as Label).text == LocaleSupport.upper(tr("JOURNAL_RECORDS_OPEN")):
			has_open = true
	ck("kayitlar sekmesi kazanilani listeler", has_earned, "")
	ck("kayitlar sekmesi henuz olmayanlari da gosterir", has_open, "")
	ck("sayac satiri", journal._counter.text.contains(str(Achievements.ids().size())), journal._counter.text)
	journal.queue_free()

	# Restore.
	Achievements.reset()
	GameState.set_setting("story", "dog_name", keep_dog)
	GameState.set_setting(MowPattern.SECTION, MowPattern.RINGS, keep_rings)
	GameState.set_setting(ThoroughStreak.SECTION, ThoroughStreak.KEY_BEST, keep_best)
	ThoroughStreak.reset()
	finish()
