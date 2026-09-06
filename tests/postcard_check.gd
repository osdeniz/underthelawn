extends TestBase
## The postcard (G27): a finished yard photographs itself, the card is saved
## under user://postcards, the panel shows the door only when there is a card,
## and the Journal's album lists it.

func run() -> void:
	suite = "KARTPOSTAL"
	var path := Postcard.path_for("ch01_aldridge")
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	ck("baslangicta kart yok", not Postcard.has("ch01_aldridge"), "")

	var game := await open("ch01_aldridge")
	await settle(1.0)
	# Cut the whole yard so the card shows stripes, not tall grass.
	for row in GameConfig.GRID_ROWS:
		for col in GameConfig.GRID_COLS:
			if game.model.is_mowable(col, row) and not game.model.is_cut(col, row):
				game.model.mow(col, row, 0)
				if game.lawn.tuft_field != null:
					game.lawn.tuft_field.cut_cell(col, row, 0.0)
	await frames(3)
	var saved: String = await Postcard.make(game, "ch01_aldridge", game._postcard_subtitle())
	ck("kart kaydedildi", saved == path and FileAccess.file_exists(path), saved)
	var img := Image.load_from_file(ProjectSettings.globalize_path(path))
	ck("kart boyutu dogru", img != null and img.get_width() == Postcard.CARD.x
		and img.get_height() == Postcard.CARD.y, "" if img == null else str(img.get_size()))
	if img != null:
		# The photograph is not black and not the parchment: green somewhere.
		var c := img.get_pixel(Postcard.MOUNT + Postcard.PHOTO.x / 2, Postcard.MOUNT + Postcard.PHOTO.y * 2 / 3)
		ck("fotografta cimen var", c.get_luminance() > 0.05 and c.g >= c.r * 0.9, str(c))
		var paper := img.get_pixel(20, Postcard.CARD.y - 20)
		ck("kenar parsomen", paper.r > 0.45 and paper.r > paper.b, str(paper))
	ck("bolum adi kartta", Postcard.title_for("ch01_aldridge") == tr("CH_01_NAME"),
		Postcard.title_for("ch01_aldridge"))
	ck("hasat adi kartta", Postcard.title_for("harvest_woodlot") == tr("HARVEST_FIELD_WOODLOT"),
		Postcard.title_for("harvest_woodlot"))
	ck("saat alt yazisi cevrili", game._postcard_subtitle() != "" and not game._postcard_subtitle().begins_with("POSTCARD_"),
		game._postcard_subtitle())

	# The door: hidden without a card, shown with one, opens the view.
	game.hud.set_postcard("")
	game.hud.show_complete(100, "1:00", [], 2, {"total": 10, "food": 0, "food_eaten": 0, "food_left": 5}, "")
	await frames(2)
	ck("kartsiz dugme gizli", not game.hud._postcard_button.visible, "")
	game.hud.set_postcard(saved)
	ck("kartla dugme gorunur", game.hud._postcard_button.visible, "")
	game.hud._postcard_button.pressed.emit()
	await frames(2)
	var view: Node = game.hud.find_child("PostcardClose", true, false)
	ck("dugme karti acar", view != null, "")
	if view != null:
		(view as Button).pressed.emit()
		await frames(2)
		ck("KAPAT kapatir", game.hud.find_child("PostcardClose", true, false) == null, "")
	close(game)

	# The album lists it.
	var journal := JournalScreen.new()
	add_child(journal)
	await frames(2)
	journal._section = JournalScreen.Section.ALBUM
	journal._refresh()
	await frames(2)
	var thumbs := journal.find_children("*", "TextureButton", true, false)
	ck("albumde en az bir kart", thumbs.size() >= 1, str(thumbs.size()))
	ck("album sayaci", journal._counter.text == tr("JOURNAL_ALBUM_COUNT").format({"count": Postcard.all().size()}),
		journal._counter.text)
	journal.queue_free()
	finish()
