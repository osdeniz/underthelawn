extends TestBase
## G27: a card from ch01 (midday, green) and one from ch06 (the big grid), so
## the camera's framing can be read rather than assumed.

func run() -> void:
	suite = "KARTPOSTAL CEKIM"
	min_checks = 3
	for vid in ["ch01_aldridge", "ch06_watertower"]:
		var game := await open(vid)
		await settle(1.2)
		# The yard as found, for the finished card's corner (G45).
		var before: Image = game._before_photo
		for row in GameConfig.GRID_ROWS:
			for col in GameConfig.GRID_COLS:
				if game.model.is_mowable(col, row) and not game.model.is_cut(col, row):
					game.model.mow(col, row, 0)
					if game.lawn.tuft_field != null:
						game.lawn.tuft_field.cut_cell(col, row, 0.0)
		await frames(3)
		var saved: String = await Postcard.make(game, vid, game._postcard_subtitle(),
			"", before)
		ck("kart var: %s" % vid, saved != "", saved)
		if saved != "":
			var img := Image.load_from_file(ProjectSettings.globalize_path(saved))
			img.save_png("res://out/postcard_%s.png" % vid)
			print("[cekim] out/postcard_%s.png yazildi" % vid)
		close(game)
	# The SCREEN the card is shown on, at the phone's frame — the half that was
	# broken (G59): a negative width made the picture zero pixels tall while
	# the scrim, the caption and the button all looked right, which is why
	# nothing but the device log noticed.
	await _view()
	finish()


func _view() -> void:
	var cards: Array = Postcard.all()
	if cards.is_empty():
		return
	get_window().content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	await frames(2)
	var path := str((cards[0] as Dictionary).get("path", ""))
	var tex := Postcard.load_texture(path)
	if tex == null:
		return
	var view := PostcardView.new()
	add_child(view)
	view.setup(tex, path)
	await settle(0.5)
	await drawn_frame()
	var frame := get_viewport().get_visible_rect()
	get_viewport().get_texture().get_image().get_region(
		Rect2i(Vector2i(frame.position), Vector2i(frame.size))).save_png(
		"res://out/postcard_view.png")
	print("[cekim] out/postcard_view.png yazildi (%dx%d)" % [frame.size.x, frame.size.y])
	var card: TextureRect = null
	for any: Variant in view.find_children("*", "TextureRect", true, false):
		if (any as TextureRect).texture != null:
			card = any as TextureRect
	if card != null:
		print("[olcum] kart %s" % str(card.get_global_rect()))
	ck("gosterilen kart cizilmis", card != null and card.size.x > 240.0
		and card.size.y > 240.0,
		"" if card == null else "%.0fx%.0f" % [card.size.x, card.size.y])
	view.queue_free()
	await frames(2)
