extends TestBase
## The dog's name (G26): "the dog" until Ellie asks, the card's third page asks,
## a chip or the box answers, and every {dog} in the game says it afterwards.

func run() -> void:
	suite = "KOPEK ISMI"
	GameState.set_setting("story", "dog_name", "")

	ck("isimsizken 'the dog'", DogName.current() == tr("DOG_UNNAMED"), DogName.current())
	ck("isimsizken END_OPEN_2 cumlesi bas harfi buyuk",
		DogName.fill(tr("END_OPEN_2")).find("{") < 0
		and DogName.fill("{Dog} x").begins_with(DogName.current().substr(0, 1).to_upper()),
		DogName.fill("{Dog} x"))
	ck("uc oneri var ve anahtar degil",
		DogName.suggestions().size() == 3 and DogName.suggestions()[0] != "DOG_SUGGEST_1",
		str(DogName.suggestions()))
	ck("uzun isim kesilir", DogName.clean_name("abcdefghijklmnopqrstu\nz").length() <= DogName.MAX_CHARS,
		DogName.clean_name("abcdefghijklmnopqrstu\nz"))

	# The card: page 2 asks, a tap anywhere does NOT skip the question, the
	# button with an empty box picks the first chip.
	var card := ReunionCard.new()
	add_child(card)
	await frames(3)
	card._page = ReunionCard.PAGE_NAME
	card._apply()
	await frames(2)
	ck("isim sayfasinda kutu gorunur", card._name_box.visible, "")
	ck("isim sayfasinda ipucu gizli", not card._hint.visible, "")
	card._lock = 0.0
	var tap := InputEventMouseButton.new()
	tap.pressed = true
	tap.button_index = MOUSE_BUTTON_LEFT
	card._gui_input(tap)
	ck("dokunma soruyu atlamaz", card._page == ReunionCard.PAGE_NAME, str(card._page))
	card._name_ok.pressed.emit()
	await frames(2)
	ck("bos kutu = ilk oneri", DogName.current() == DogName.suggestions()[0], DogName.current())
	ck("Ellie ismi soyler", card._line.text.contains(DogName.current()), card._line.text)
	ck("kutu kapanir, ipucu doner", not card._name_box.visible and card._hint.visible, "")
	card._lock = 0.0
	card._gui_input(tap)
	ck("onaydan sonra dokunma vaka 2 sayfasina gecer", card._page == ReunionCard.PAGE_CASE2, str(card._page))
	card.queue_free()
	await frames(2)

	# The typed path, and the name everywhere it should be.
	var card2 := ReunionCard.new()
	add_child(card2)
	await frames(2)
	GameState.set_setting("story", "dog_name", "")
	card2._named = false
	card2._page = ReunionCard.PAGE_NAME
	card2._apply()
	card2._name_edit.text = "  Fındık  "
	card2._name_ok.pressed.emit()
	ck("yazilan isim kaydedilir (kirpilmis)", DogName.current() == "Fındık", DogName.current())
	card2.queue_free()
	ck("bitis karti ismi soyler", DogName.fill(tr("END_OPEN_2")).contains("Fındık"),
		DogName.fill(tr("END_OPEN_2")))
	ck("bitis karti 2 ismi soyler", DogName.fill(tr("END_CLOSED_2")).contains("Fındık"), "")
	ck("koku satiri ismi soyler", DogName.fill(tr("DOG_POINT_LINE")).begins_with("Fındık"),
		DogName.fill(tr("DOG_POINT_LINE")))

	# Replaying the ending: the page states the name and does not ask again.
	var card3 := ReunionCard.new()
	add_child(card3)
	await frames(2)
	card3._page = ReunionCard.PAGE_NAME
	card3._apply()
	ck("isim varsa tekrar sormaz", not card3._name_box.visible and card3._named, "")
	card3.queue_free()

	# The HUD toast runs its line through the name.
	var game := await open("ch01_aldridge")
	game.hud.show_scent("DOG_POINT_LINE")
	await frames(2)
	var toast: Node = game.hud.find_child("ScentToast", true, false)
	var said := ""
	if toast != null:
		for l in toast.find_children("*", "Label", true, false):
			if (l as Label).text.length() > 3:
				said = (l as Label).text
	ck("HUD kokusu ismi soyler", said.begins_with("Fındık"), said)
	ck("Animals'da pointing bayragi var", "dog_pointing" in game._animals, "")
	close(game)

	GameState.set_setting("story", "dog_name", "")
	finish()
