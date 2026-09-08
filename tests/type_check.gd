extends TestBase
## Typed-out text (G37): the machine, driven by hand so the counts are exact,
## then the screens that use it — story cards, the reunion card and the
## dialogue box — plus the switch that turns the whole thing off.

func run() -> void:
	suite = "YAZI"
	GameConfig.text_instant = false
	_machine()
	await _story_card()
	await _reunion()
	await _dialogue()
	await _radio()
	_switch()
	GameConfig.text_instant = false
	finish()


## No wall clock: advance() is called with the delta this test chooses, so the
## letter counts are arithmetic rather than timing.
func _machine() -> void:
	ck("Godot substr harf sayar, bayt saymaz", "ğş".substr(0, 1) == "ğ",
		"ğş".substr(0, 1))
	var a := Label.new()
	var b := Label.new()
	add_child(a)
	add_child(b)
	var full_a := "Salgın yıllar önce bitti."
	var full_b := "Dünya onunla birlikte bitmedi."
	a.text = full_a
	b.text = full_b
	var t := Typewriter.new()
	t.play([a, b])
	ck("iki etikette harf gorunmez", a.visible_characters == 0 and b.visible_characters == 0,
		"%d|%d" % [a.visible_characters, b.visible_characters])
	ck("metin yerinde duruyor: duzen zilamaz", a.text == full_a and b.text == full_b, "")
	ck("tam metin once sekillenir",
		a.visible_characters_behavior == TextServer.VC_CHARS_AFTER_SHAPING, "")
	ck("yaziyor", t.typing(), "")
	t.advance(0.5)
	ck("yarim saniye = 21 harf", a.visible_characters == int(GameConfig.TEXT_CPS * 0.5),
		str(a.visible_characters))
	ck("sira sirayla: ikinci satir hic gorunmez", b.visible_characters == 0,
		str(b.visible_characters))
	t.advance(0.5)
	ck("ilk satir tamamlandi", a.visible_characters == -1, str(a.visible_characters))
	ck("ilk satir bitince ikincisi baslamaz", b.visible_characters == 0,
		str(b.visible_characters))
	t.advance(0.3)
	ck("ikinci satir baslar",
		b.visible_characters > 0 and b.visible_characters < full_b.length(),
		str(b.visible_characters))
	ck("hala yaziyor", t.typing(), "")
	t.finish()
	ck("finish ikisini de tamamlar",
		a.visible_characters == -1 and b.visible_characters == -1, "")
	ck("finish sonrasi yazmiyor", not t.typing(), "")

	# The delay: a card sets its text under a black fade, and typing nobody
	# can see is typing that never happened.
	t.play([a], 1.0)
	t.advance(0.5)
	ck("gecikme boyunca harf gorunmez", a.visible_characters == 0, str(a.visible_characters))
	t.advance(0.6)
	ck("gecikme bitince yazar", a.visible_characters > 0, str(a.visible_characters))

	# An empty label is not a line.
	var empty := Label.new()
	add_child(empty)
	t.play([empty])
	ck("bos etiket siraya girmez", not t.typing(), "")

	# Off: the text is simply there.
	GameConfig.text_instant = true
	t.play([a], 1.0)
	ck("kapaliyken metin duruyor",
		a.visible_characters == -1 and a.text == full_a and not t.typing(), a.text)
	GameConfig.text_instant = false
	a.queue_free()
	b.queue_free()
	empty.queue_free()


## A story card: blank while the fade runs, the hint held back, and the two
## taps — one finishes the words, the next turns the page.
func _story_card() -> void:
	var intro := IntroSequence.new()
	intro.cards_key = "intro.cards"
	add_child(intro)
	await frames(6)
	var labels := intro._lines.get_children()
	ck("kartta iki satir var", labels.size() == 2, str(labels.size()))
	var first := labels[0] as Label
	ck("kart satirinda harf gorunmez", first.visible_characters == 0,
		str(first.visible_characters))
	ck("kart metni yine de yerinde", first.text != "", first.text)
	ck("kart yaziyor", intro._typer.typing(), "")
	ck("yazarken 'dokun' ipucu gizli", not intro._hint.visible, "")

	intro._tap_lock = 0.0
	var page := intro._index
	intro._gui_input(_tap())
	ck("ilk dokunus satirlari tamamlar",
		first.visible_characters == -1 and not intro._typer.typing(),
		str(first.visible_characters))
	ck("ilk dokunus sayfayi cevirmez", intro._index == page, str(intro._index))
	ck("tamamlaninca ipucu gorunur", intro._hint.visible, "")
	ck("tamamlayan dokunus kilit kurar", intro._tap_lock > 0.0, str(intro._tap_lock))
	intro._tap_lock = 0.0
	intro._gui_input(_tap())
	ck("ikinci dokunus sayfayi cevirir", intro._index == page + 1, str(intro._index))
	intro.queue_free()
	await frames(2)


## The reunion card's naming page: Ellie asks, and only when she has finished
## asking is there somewhere to answer.
func _reunion() -> void:
	var keep: Variant = GameState.get_setting("story", "dog_name", "")
	GameState.set_setting("story", "dog_name", "")
	var card := ReunionCard.new()
	add_child(card)
	await frames(3)
	card._named = false
	card._page = ReunionCard.PAGE_NAME
	card._apply()
	await frames(2)
	ck("soru yazilirken kutu gizli", not card._name_box.visible, "")
	ck("soru yazilirken ipucu gizli", not card._hint.visible, "")
	card._typer.finish()
	card._reveal_after_typing()
	ck("soru bitince kutu gorunur", card._name_box.visible, "")
	card._name_ok.pressed.emit()
	await frames(2)
	ck("Ellie ismi yazarak soyler",
		card._line.text != tr("REUNION_NAME_LINE") and card._typer.typing()
		and card._line.visible_characters != -1, card._line.text)
	card._typer.finish()
	ck("isim satiri tamamlanir", card._line.text.contains(DogName.current()),
		card._line.text)
	card.queue_free()
	await frames(2)
	GameState.set_setting("story", "dog_name", keep)


## The dialogue box has typed since G6; the claim here is that it now types at
## the shared speed and obeys the same switch.
func _dialogue() -> void:
	var box := DialogueBox.new()
	add_child(box)
	await frames(3)
	var lines := Dialogue.conversation("brief_ch01")
	ck("brifing satirlari var", lines.size() > 0, str(lines.size()))
	box.play(lines, "")
	ck("diyalog bos baslar", box._text_label.text == "", box._text_label.text)
	ck("diyalog yaziyor", box._typing, "")
	await frames(2)
	ck("diyalog harf harf ilerler",
		box._text_label.text.length() > 0
		and box._text_label.text.length() < DogName.fill(tr("DLG_BRIEF_CH01_1")).length(),
		box._text_label.text)
	ck("diyalog ortak hizi kullanir", DialogueBox.TYPE_CPS == GameConfig.TEXT_CPS,
		"%f" % DialogueBox.TYPE_CPS)
	GameConfig.text_instant = true
	box.play(lines, "")
	await frames(2)
	ck("kapaliyken diyalog bir anda gelir",
		box._text_label.text.length() > 0 and not box._typing, box._text_label.text)
	GameConfig.text_instant = false
	box.queue_free()
	await frames(2)


## The Marshal on the radio (G39): the toast types, its marker blinks while it
## does, and the toast lives long enough to be read after the last letter.
func _radio() -> void:
	var game := await open("ch01_aldridge")
	game.hud.show_scent("SCENT_OAK")
	await frames(2)
	var toast: Node = game.hud.find_child("ScentToast", true, false)
	ck("koku bildirimi acilir", toast != null, "")
	var line: Label = null
	for any: Variant in toast.find_children("*", "Label", true, false):
		if (any as Label).text.length() > 3:
			line = any as Label
	ck("telsiz satiri yaziyor", line != null and line.visible_characters != -1,
		"" if line == null else str(line.visible_characters))
	ck("satirin tam metni yerinde", line != null and line.text == tr("SCENT_OAK"),
		"" if line == null else line.text)
	ck("yazarken isaret yanip soner",
		game.hud._scent_mark != null and game.hud._scent_mark.modulate.a < 1.0,
		"%.2f" % game.hud._scent_mark.modulate.a)
	# It must outlive its own typing by the usual read.
	var typing := float(tr("SCENT_OAK").length()) / GameConfig.TEXT_CPS
	await settle(typing + 0.5)
	ck("yazma bitince bildirim hala duruyor",
		game.hud.find_child("ScentToast", true, false) != null, "")
	ck("bitince isaret sabit", game.hud._scent_mark.modulate.a >= 0.99,
		"%.2f" % game.hud._scent_mark.modulate.a)

	# The panel's sentence.
	game.hud.show_complete(100, "1:00", [], 2, {"total": 10}, "")
	await frames(2)
	ck("panel cumlesi yaziyor", game.hud._notes_progress.visible_characters != -1,
		str(game.hud._notes_progress.visible_characters))
	ck("panel cumlesinin metni tam", game.hud._notes_progress.text.length() > 0, "")
	close(game)


## The settings row drives the same flag the machine reads.
func _switch() -> void:
	var screen := SettingsScreen.new()
	add_child(screen)
	var toggle: Button = screen.find_child("Toggle_" + tr("SET_TYPING_TITLE"), true, false)
	ck("ayarlarda harf harf satiri var", toggle != null, "")
	ck("satir varsayilan olarak acik", toggle == null or toggle.button_pressed, "")
	if toggle != null:
		toggle.button_pressed = false
	ck("satir bayragi cevirir", GameConfig.text_instant, "")
	ck("ayar kaydedilir",
		bool(GameState.get_setting("display", "text_instant", false)), "")
	GameState.set_setting("display", "text_instant", false)
	screen.queue_free()


func _tap() -> InputEventMouseButton:
	var tap := InputEventMouseButton.new()
	tap.pressed = true
	tap.button_index = MOUSE_BUTTON_LEFT
	return tap
