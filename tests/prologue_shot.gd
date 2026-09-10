extends TestBase
## The prologue's own art on the prologue's own cards (G57): each of the six
## pictures with its two lines fully typed over it, so the type can be checked
## against the sky it lands on rather than against a guess.

func run() -> void:
	suite = "PROLOG CEKIM"
	min_checks = 3
	# The phone's exact frame. The cards fill the screen with KEEP_ASPECT_
	# COVERED, so on the desktop's wide window a portrait picture is cropped to
	# a horizontal band and the render says nothing about what a player sees
	# (the same trap Legibility documents).
	get_window().content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	await frames(2)
	GameConfig.text_instant = false
	# The intro deck too (G57.1): its four cards were repainted to match the
	# prologue's six, and the hub's replay-the-intro path is where they show.
	# And both endings (G61) — the game's last two pictures, which until now
	# borrowed older cards through the fallback.
	var cards: Array = Story.list("prologue.cards") + Story.list("prologue.after") \
		+ Story.list("intro.cards") + Story.list("endings.open.cards") \
		+ Story.list("endings.closed.cards")
	var intro := IntroSequence.new()
	intro.cards_key = "prologue.cards"
	add_child(intro)
	await frames(6)
	var drawn := 0
	for any: Variant in cards:
		var card: Dictionary = any
		intro._apply(card)
		intro._typer.finish()
		await frames(3)
		await drawn_frame()
		var name := str(card.get("image", "kart")).get_file()
		var frame := get_viewport().get_visible_rect()
		var shot := get_viewport().get_texture().get_image().get_region(
			Rect2i(Vector2i(frame.position), Vector2i(frame.size)))
		shot.resize(shot.get_width() / 3, shot.get_height() / 3,
			Image.INTERPOLATE_LANCZOS)
		shot.save_png("res://out/prologue_%d_%s.png" % [drawn + 1, name])
		drawn += 1
	print("[cekim] out/prologue_1..%d yazildi" % drawn)
	ck("her kart cizildi", drawn == cards.size(), "%d / %d" % [drawn, cards.size()])
	# The pictures are all there: this is the claim the render is evidence for.
	var missing: Array[String] = []
	for any: Variant in cards:
		var card: Dictionary = any
		if TextureLibrary.find(str(card.get("image", ""))) == null:
			missing.append(str(card.get("image", "")))
	ck("prolog resimleri yuklendi", missing.is_empty(), ", ".join(missing))
	intro.queue_free()
	await frames(2)
	await _reunion_pages()


## The reunion card's own pages (G61). It is not an IntroSequence: it carries
## its own 55% scrim, and the picture behind that scrim has to survive being
## dimmed to 0.45 of itself.
func _reunion_pages() -> void:
	var keep: Variant = GameState.get_setting("story", "dog_name", "")
	GameState.set_setting("story", "dog_name", "")
	var card := ReunionCard.new()
	add_child(card)
	await frames(6)
	card._fade.color.a = 0.0
	# The party page too (G62): it sets its own 0.22 veil, so it is the one
	# page whose picture cannot be judged from the file.
	for page: int in [ReunionCard.PAGE_REUNION, ReunionCard.PAGE_PARTY,
			ReunionCard.PAGE_NAME]:
		card._named = false
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
		shot.save_png("res://out/reunion_page_%d.png" % page)
	print("[cekim] out/reunion_page_0/1/2.png yazildi")
	ck("kavusma resmi yuklendi", card._art.texture != null, "")
	card.queue_free()
	await frames(2)
	GameState.set_setting("story", "dog_name", keep)
