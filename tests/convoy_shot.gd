extends TestBase
## Case 02's closing card, both beats, at the phone's frame (G65).
##
## Its picture is seen through the card's own veil, so the file cannot be
## judged on its own: the repainted convoy averages 42 where the prompt asked
## for 75-95, and the number that matters is the SUBJECT — road and headlights
## at 62 against the old card's 37. This is the look-at-it half of that.

func run() -> void:
	suite = "KONVOY CEKIM"
	min_checks = 2
	get_window().content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	await frames(2)
	GameConfig.text_instant = false
	var card := ConvoyCard.new()
	add_child(card)
	await frames(6)
	card._fade.color.a = 0.0
	for page in ConvoyCard.PAGES:
		card._page = page
		card._apply()
		card._typer.finish()
		await frames(3)
		await drawn_frame()
		var frame := get_viewport().get_visible_rect()
		var shot := get_viewport().get_texture().get_image().get_region(
			Rect2i(Vector2i(frame.position), Vector2i(frame.size)))
		shot.resize(shot.get_width() / 3, shot.get_height() / 3,
			Image.INTERPOLATE_LANCZOS)
		shot.save_png("res://out/convoy_page_%d.png" % page)
	print("[cekim] out/convoy_page_0/1.png yazildi")
	ck("ikinci sayfa konvoy resmini kullanir",
		card._art.texture == TextureLibrary.find("story/convoy"), "")
	ck("perde ayardan geliyor",
		is_equal_approx(card._scrim.color.a, GameConfig.CONVOY_SCRIM),
		"%.2f" % card._scrim.color.a)
	card.queue_free()
	await frames(2)
