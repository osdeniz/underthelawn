extends TestBase
## G67: Ellie's four drawings — the art, the gate, the once, the strip.
##
## What can go wrong here is not rendering, it is bookkeeping. A drawing that
## plays on every replay of its chapter, or one that appears before its chapter
## is finished, or four that all resolve to the same texture because the table
## is mis-keyed — each of those is silent on screen and obvious to a claim.

func _init() -> void:
	suite = "CIZIM"
	min_checks = 26


func run() -> void:
	# Start from nothing seen and no chapter done, whatever the borrowed save
	# state on this machine says (the lesson MenuReturnCheck learned in G60).
	for i in Drawings.total():
		GameState.set_setting(Drawings.SECTION, Drawings.id_of(i) + "_seen", false)
		GameState.set_setting(ChapterProgress.SECTION,
			Drawings.chapter_of(i) + "_done", false)

	ck("dort cizim tanimli", Drawings.total() == 4, str(Drawings.total()))

	# The art itself: four distinct files, all present, all 4:3 landscape.
	var seen_sizes: Array[String] = []
	for i in Drawings.total():
		var tex := Drawings.texture(i)
		ck("%s dosyasi yuklendi" % Drawings.id_of(i), tex != null)
		if tex == null:
			continue
		var size := tex.get_size()
		var aspect := size.x / maxf(size.y, 1.0)
		ck("%s 4:3 yatay" % Drawings.id_of(i),
			absf(aspect - GameConfig.DRAWING_ASPECT) < 0.02, "%s -> %.3f" % [size, aspect])
		seen_sizes.append("%s@%s" % [tex.resource_path, size])
	# Four DIFFERENT pictures: a copy-paste in the table would give one texture
	# four names and nobody would notice on screen.
	var unique := {}
	for entry in seen_sizes:
		unique[entry] = true
	ck("dort ayri dosya", unique.size() == Drawings.total(), str(unique.keys()))

	# Every drawing has both of its lines in the player's language.
	for i in Drawings.total():
		var id := Drawings.id_of(i)
		ck("%s basligi cevrildi" % id,
			Drawings.title(i) != "" and Drawings.title(i) != id.to_upper() + "_TITLE",
			Drawings.title(i))
		ck("%s notu cevrildi" % id,
			Drawings.line(i) != "" and Drawings.line(i) != id.to_upper() + "_LINE",
			Drawings.line(i).substr(0, 24))

	# The gate: nothing is unlocked and nothing is pending until the chapter
	# that earns it is finished.
	ck("bolum bitmeden kilitli", Drawings.found_count() == 0,
		str(Drawings.found_count()))
	ck("bolum bitmeden gosterilecek cizim yok",
		Drawings.pending_for(Drawings.chapter_of(0)) == -1)

	GameState.set_setting(ChapterProgress.SECTION, Drawings.chapter_of(0) + "_done", true)
	ck("ch09 bitince ilk cizim acildi", Drawings.is_unlocked(0) and Drawings.found_count() == 1,
		str(Drawings.found_count()))
	ck("ikinci cizim hala kilitli", not Drawings.is_unlocked(1))
	ck("ilk cizim gosterilmeyi bekliyor", Drawings.pending_for(Drawings.chapter_of(0)) == 0)
	ck("cizimi olmayan bolum hicbir sey beklemiyor",
		Drawings.pending_for("ch13_roadside_camp") == -1)

	# The once: the card marks itself shown when it is put down, and the same
	# chapter played again does not hand it over a second time.
	var card := DrawingCard.new()
	add_child(card)
	card.play(0)
	await frames(4)
	var paper := card.find_child("DrawingPaper", true, false) as TextureRect
	ck("kart kagidi cizdi", paper != null and paper.texture != null)
	ck("kagit ekranda bir boyut aldi",
		paper != null and paper.custom_minimum_size.x > 240.0
			and paper.custom_minimum_size.y > 180.0,
		"" if paper == null else str(paper.custom_minimum_size))
	ck("kartta baslik ve not var",
		(card.find_child("DrawingTitle", true, false) as Label).text != ""
			and (card.find_child("DrawingLine", true, false) as Label).text != "")
	var close := card.find_child("DrawingClose", true, false) as Button
	ck("kapatma dugmesi var", close != null)
	if close != null:
		close.pressed.emit()
	await frames(4)
	ck("kapatilan cizim gorulmus sayildi", Drawings.is_seen(0))
	ck("tekrar oynanan bolum cizimi bir daha vermiyor",
		Drawings.pending_for(Drawings.chapter_of(0)) == -1)

	# The strip: the journal's Discoveries tab lists what is earned and only
	# what is earned, under a heading that counts.
	var journal := JournalScreen.new()
	add_child(journal)
	await frames(6)
	journal.set("_section", JournalScreen.Section.DISCOVERIES)
	journal.call("_refresh")
	await frames(4)
	var strip := journal.find_child("DrawingStrip", true, false)
	ck("gunlukte cizim seridi var", strip != null)
	ck("seritte yalnizca kazanilan cizim var",
		strip != null and strip.get_child_count() == 1,
		"" if strip == null else str(strip.get_child_count()))
	ck("kazanilan cizimin kucuk hali seritte",
		journal.find_child("Drawing_" + Drawings.id_of(0), true, false) != null)
	ck("kazanilmayan cizim seritte yok",
		journal.find_child("Drawing_" + Drawings.id_of(1), true, false) == null)

	# And with none earned there is no strip at all: before ch09 the tab has to
	# look exactly as it did before this sprint.
	GameState.set_setting(ChapterProgress.SECTION, Drawings.chapter_of(0) + "_done", false)
	journal.call("_refresh")
	await frames(4)
	ck("hic cizim yokken serit hic kurulmuyor",
		journal.find_child("DrawingStrip", true, false) == null)

	# The card is NOT freed here: it freed itself when its close button was
	# pressed, and asking again is a "previously freed instance" error that
	# the harness would print after a pass line.
	# The wiring: the chapter flow itself hands the card over. Everything above
	# proves the model and the card; this proves ROOT asks for them, which is
	# where a drawing that is never seen would hide.
	GameState.set_setting(ChapterProgress.SECTION, Drawings.chapter_of(1) + "_done", true)
	var flow := RootFlow.new()
	flow.call("_show_drawing", Drawings.chapter_of(1))
	ck("akis cizim kartini kurdu",
		flow.find_children("*", "DrawingCard", true, false).size() == 1,
		str(flow.get_child_count()))
	flow.call("_show_drawing", "ch13_roadside_camp")
	ck("cizimi olmayan bolum kart kurmuyor",
		flow.find_children("*", "DrawingCard", true, false).size() == 1,
		str(flow.find_children("*", "DrawingCard", true, false).size()))
	flow.free()

	# The heading shouts in the language being read (G67). The drawings strip is
	# where this was caught, but it was wrong for every heading in the journal
	# and the settings screen before it.
	var was := TranslationServer.get_locale()
	TranslationServer.set_locale("tr")
	ck("turkce noktali i buyurken noktali kaliyor",
		LocaleSupport.upper("çizimleri") == "ÇİZİMLERİ",
		LocaleSupport.upper("çizimleri"))
	ck("turkce noktasiz i noktasiz buyuyor",
		LocaleSupport.upper("Telsiz Odası") == "TELSİZ ODASI",
		LocaleSupport.upper("Telsiz Odası"))
	# Ellie is a name, not a Turkish word: it keeps its own I while the Turkish
	# around it takes the dotted one. Author's decision, so it is a claim.
	ck("Ellie kuralin disinda",
		LocaleSupport.upper("Ellie'nin çizimleri") == "ELLIE'NİN ÇİZİMLERİ",
		LocaleSupport.upper("Ellie'nin çizimleri"))
	ck("isim satirin sonunda da korunuyor",
		LocaleSupport.upper("çizim: ellie") == "ÇİZİM: ELLIE",
		LocaleSupport.upper("çizim: ellie"))
	ck("isim gecmeyen baslik etkilenmiyor",
		LocaleSupport.upper("Henüz değil") == "HENÜZ DEĞİL",
		LocaleSupport.upper("Henüz değil"))
	TranslationServer.set_locale("en")
	ck("ingilizce degismiyor", LocaleSupport.upper("the lawn") == "THE LAWN",
		LocaleSupport.upper("the lawn"))
	TranslationServer.set_locale(was)

	# The card is NOT freed here: it freed itself when its close button was
	# pressed, and asking again is a "previously freed instance" error that
	# the harness would print after a pass line.
	journal.queue_free()
	await frames(3)
