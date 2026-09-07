extends TestBase
## The quiet loop lines (G30-G32): the thorough streak counts and speaks from
## two; the Journal header carries a percentage; the hub greets by the hour.

func run() -> void:
	suite = "DONGU"
	ThoroughStreak.reset()
	ck("seri sifirdan", ThoroughStreak.current() == 0, "")
	ck("titiz bahce +1", ThoroughStreak.bump(true) == 1, "")
	ck("ikinci titiz bahce 2", ThoroughStreak.bump(true) == 2, "")
	ck("kacirilan bahce sifirlar", ThoroughStreak.bump(false) == 0, "")
	ThoroughStreak.reset()

	var game := await open("ch01_aldridge")
	game.hud.show_complete(100, "1:00", [], 2, {"total": 10}, "")
	await frames(1)
	ck("seri yokken satir yok", not game.hud._notes_progress.text.contains(
		tr("THOROUGH_STREAK_LINE").format({"n": 3})), game.hud._notes_progress.text)
	game.hud.show_complete(100, "1:00", [], 2, {"total": 10, "streak": 3}, "")
	await frames(1)
	ck("seri 3 satiri var", game.hud._notes_progress.text.contains(
		tr("THOROUGH_STREAK_LINE").format({"n": 3})), game.hud._notes_progress.text)
	close(game)

	var pct := JournalScreen.completion_percent()
	ck("gunluk yuzdesi 0..100", pct >= 0 and pct <= 100, str(pct))
	var journal := JournalScreen.new()
	add_child(journal)
	await frames(2)
	var header := journal.find_child("JournalHeader", true, false) as Label
	ck("gunluk basligi yuzdeyi yazar", header != null and header.text.contains("%"),
		"" if header == null else header.text)
	journal.queue_free()

	for pair in [[8, "GREET_MORNING"], [14, "GREET_AFTERNOON"], [20, "GREET_EVENING"], [2, "GREET_NIGHT"]]:
		var text := HubScreen.greeting_text(int(pair[0]))
		ck("saat %d selami" % int(pair[0]), text.begins_with(tr(str(pair[1]))), text)
	ck("selam kalan bahceyi soyler", HubScreen.greeting_text(8).length() > tr("GREET_MORNING").length() + 3, "")
	finish()
