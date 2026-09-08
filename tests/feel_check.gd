extends TestBase
## How the interface answers a finger (G41): every button gives under a press,
## and the reduced-motion switch stops the movement nobody asked for while
## keeping the movement that carries meaning.

func run() -> void:
	suite = "HIS"
	var keep := GameConfig.reduced_motion
	GameConfig.reduced_motion = false

	# The hook, not forty call sites: a button added anywhere gets it.
	PressFeel.install(get_tree())
	var button := Button.new()
	button.text = "Dene"
	button.custom_minimum_size = Vector2(220, 96)
	add_child(button)
	await frames(3)
	ck("agaca eklenen dugme kendiliginden alir", button.has_meta(PressFeel.META), "")
	ck("dugme normal olcekte", is_equal_approx(button.scale.x, 1.0), str(button.scale))
	button.button_down.emit()
	await frames(4)
	ck("basinca kuculur", button.scale.x < 1.0, str(button.scale.x))
	ck("merkezinden kuculur",
		is_equal_approx(button.pivot_offset.x, button.size.x * 0.5), str(button.pivot_offset))
	button.button_up.emit()
	await settle(0.3)
	ck("birakinca geri gelir", is_equal_approx(button.scale.x, 1.0), str(button.scale.x))
	# Drumming on it must not stack tweens and drift the scale.
	for _i in 5:
		button.button_down.emit()
		button.button_up.emit()
	await settle(0.4)
	ck("ust uste basmak olcegi kaydirmaz", is_equal_approx(button.scale.x, 1.0),
		str(button.scale.x))
	# Applying twice must not connect a second pair of handlers.
	var before := button.button_down.get_connections().size()
	PressFeel.apply(button)
	ck("iki kez uygulanmaz", button.button_down.get_connections().size() == before,
		"%d" % button.button_down.get_connections().size())

	# Reduced motion: the give stops.
	GameConfig.reduced_motion = true
	button.scale = Vector2.ONE
	button.button_down.emit()
	await frames(4)
	ck("azaltilmis hareket basmayi durdurur", is_equal_approx(button.scale.x, 1.0),
		str(button.scale.x))
	button.button_up.emit()
	button.queue_free()

	# Reduced motion: the cards stop drifting.
	var intro := IntroSequence.new()
	intro.cards_key = "intro.cards"
	add_child(intro)
	await settle(0.8)
	ck("azaltilmis hareket kart kaymasini durdurur",
		is_equal_approx(intro._image.scale.x, 1.0), str(intro._image.scale))
	intro.queue_free()
	await frames(2)

	# Reduced motion: a bump is still heard and felt, but the camera holds.
	var game := await open("ch01_aldridge")
	game.cam._kick = Vector3.ZERO
	game._on_bumped(GameConfig.BUMP_HARD_IMPACT, Vector3.FORWARD)
	ck("azaltilmis hareket kamerayi sabit tutar", game.cam._kick.length() < 0.0001,
		"%.4f" % game.cam._kick.length())
	# …and the counter does not pop.
	game.hud._pulse(game.hud._scrap_label)
	ck("azaltilmis hareket sayaci ziplatmaz",
		is_equal_approx(game.hud._scrap_label.scale.x, 1.0), str(game.hud._scrap_label.scale))
	close(game)

	# A refusal still answers, in colour instead of position.
	var row := Button.new()
	row.custom_minimum_size = Vector2(200, 90)
	add_child(row)
	await frames(2)
	var home := row.position
	HubScreen.shake(row)
	await frames(4)
	ck("kilitli satir azaltilmis hareketle yerinden oynamaz",
		row.position.is_equal_approx(home), str(row.position))
	ck("kilitli satir renkle cevap verir", not row.modulate.is_equal_approx(Color.WHITE),
		str(row.modulate))
	await settle(0.5)
	ck("renk geri oturur", row.modulate.is_equal_approx(Color.WHITE), str(row.modulate))
	# With motion on, it moves.
	GameConfig.reduced_motion = false
	HubScreen.shake(row)
	await frames(3)
	ck("hareket acikken kilitli satir sarsilir", not row.position.is_equal_approx(home),
		str(row.position))
	row.queue_free()

	# The settings rows.
	var screen := SettingsScreen.new()
	add_child(screen)
	var toggle: Button = screen.find_child("Toggle_" + tr("SET_MOTION_TITLE"), true, false)
	ck("ayarlarda azaltilmis hareket satiri var", toggle != null, "")
	if toggle != null:
		toggle.button_pressed = true
		ck("satir bayragi cevirir", GameConfig.reduced_motion, "")
		ck("ayar kaydedilir",
			bool(GameState.get_setting("display", "reduced_motion", false)), "")
	GameState.set_setting("display", "reduced_motion", false)
	screen.queue_free()
	GameConfig.reduced_motion = keep
	finish()
