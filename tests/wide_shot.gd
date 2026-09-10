extends TestBase
## The same card on a landscape screen, before/after fit_card (G65 evidence).

func run() -> void:
	suite = "GENIS KART"
	min_checks = 1
	# The desktop's own window: no letterboxing to the phone frame this time.
	await frames(2)
	var intro := IntroSequence.new()
	intro.cards_key = "prologue.cards"
	add_child(intro)
	await frames(6)
	intro._apply(Story.list("prologue.cards")[2])
	intro._typer.finish()
	# COVERED, the way it shipped.
	intro._image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	await frames(3)
	await drawn_frame()
	var a := get_viewport().get_texture().get_image()
	a.resize(a.get_width() / 4, a.get_height() / 4, Image.INTERPOLATE_LANCZOS)
	a.save_png("res://out/wide_covered.png")
	# And fitted.
	GameConfig.fit_card(intro._image)
	await frames(3)
	await drawn_frame()
	var b := get_viewport().get_texture().get_image()
	b.resize(b.get_width() / 4, b.get_height() / 4, Image.INTERPOLATE_LANCZOS)
	b.save_png("res://out/wide_fitted.png")
	var view := get_viewport().get_visible_rect().size
	print("[olcum] gorunum %.0fx%.0f oran %.2f" % [view.x, view.y, view.x / view.y])
	ck("genis ekranda mektup kutusu",
		intro._image.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_CENTERED,
		str(intro._image.stretch_mode))
	intro.queue_free()
	await frames(2)
