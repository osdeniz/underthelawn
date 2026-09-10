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
	# Read here, not later: the shot is only taken while the yard is untouched
	# and this suite mows all of it two lines from now (G45).
	var before_photo: Image = game._before_photo
	ck("giriste onceki kare alinmis", before_photo != null
		and before_photo.get_width() == Postcard.INSET.x,
		"" if before_photo == null else str(before_photo.get_size()))
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
	# The before/after inset (G45). The same card composed twice with the same
	# inputs, so the ONLY difference between them is the inset — comparing
	# against the saved card would compare two different compositions.
	var plain: Image = await Postcard.compose(game, img, "Test", "", "", null)
	var with_inset: Image = await Postcard.compose(game, img, "Test", "", "",
		before_photo)
	ck("onceki kare karta basilir", with_inset != null and plain != null, "")
	if with_inset != null and plain != null and before_photo != null:
		var spot := Vector2i(Postcard.MOUNT + Postcard.INSET_MARGIN + Postcard.INSET.x / 2,
			Postcard.MOUNT + Postcard.PHOTO.y - Postcard.INSET_MARGIN - Postcard.INSET.y / 2)
		ck("kose degisti", with_inset.get_pixelv(spot) != plain.get_pixelv(spot),
			"%s vs %s" % [with_inset.get_pixelv(spot), plain.get_pixelv(spot)])
		var away := Vector2i(Postcard.MOUNT + Postcard.PHOTO.x - 60, Postcard.MOUNT + 60)
		ck("fotografin geri kalani ayni",
			with_inset.get_pixelv(away).is_equal_approx(plain.get_pixelv(away)),
			"%s vs %s" % [with_inset.get_pixelv(away), plain.get_pixelv(away)])
	ck("once yazisi cevrili", tr("POSTCARD_BEFORE") != "POSTCARD_BEFORE", "")

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
	# THE PICTURE, not just the buttons around it (G59). Both callers built the
	# view and called setup() on it before adding it to the tree, so the width
	# was measured against a viewport that did not exist yet: it came out
	# negative, Godot clamped the minimum size to nothing, and the card the
	# whole screen exists for was drawn at zero. The device log said so
	# (get_viewport_rect(): "!is_inside_tree()" is true) and no suite looked.
	# find_childREN for a type: find_child takes (pattern, recursive, owned)
	# and no type at all, so the four-argument call I first wrote here was a
	# runtime error that aborted the rest of run() — and the suite still
	# printed a pass, because the claims before it had already cleared
	# min_checks. Exactly the trap TestBase documents.
	var views: Array = game.hud.find_children("*", "PostcardView", true, false)
	var shown: PostcardView = views[0] if not views.is_empty() else null
	ck("kart gorunumu sahnede", shown != null, "")
	if shown != null:
		var card: TextureRect = null
		for any: Variant in shown.find_children("*", "TextureRect", true, false):
			if (any as TextureRect).texture != null:
				card = any as TextureRect
		ck("kartin dokusu var", card != null, "")
		if card != null:
			var room := get_viewport().get_visible_rect().size.x
			ck("kart bir genislik aldi", card.custom_minimum_size.x > 240.0,
				"%.0f (ekran %.0f)" % [card.custom_minimum_size.x, room])
			ck("kart ekrani asmaz", card.custom_minimum_size.x <= room - 80.0,
				"%.0f / %.0f" % [card.custom_minimum_size.x, room - 80.0])
			ck("kart oranini korur",
				absf(card.custom_minimum_size.y / maxf(card.custom_minimum_size.x, 1.0)
					- float(Postcard.CARD.y) / float(Postcard.CARD.x)) < 0.01,
				"%.0fx%.0f" % [card.custom_minimum_size.x, card.custom_minimum_size.y])
			ck("kart cizilecek boyda",
				card.size.x > 240.0 and card.size.y > 240.0,
				"%.0fx%.0f" % [card.size.x, card.size.y])
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
