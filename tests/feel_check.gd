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
	await _dog_at_ease()
	await _portrait_and_cut()
	finish()


## The dog when nobody has moved for a while (G44): the head lowers, the body
## settles, and both come straight back when the player moves.
func _dog_at_ease() -> void:
	GameState.set_setting("story", "prologue_done", true)
	var game := await open("ch01_aldridge")
	await settle(0.6)
	var dog: Node3D = game._animals.find_child("Dog", false, false)
	ck("kopek yanimizda", dog != null, "")
	if dog == null:
		close(game)
		return
	dog.position = game.mower.position + Vector3(1.2, 0.0, 0.8)
	await settle(0.6)
	var body: Node3D = dog.get_node_or_null("Body")
	var head: Node3D = body.get_node_or_null("Head") if body != null else null
	ck("beklerken bas yukarda", head != null and head.rotation.x < 0.1,
		"%.2f" % (0.0 if head == null else head.rotation.x))
	# Set after the frame that noticed the machine move, or the tick zeroes it.
	game._animals._player_still = GameConfig.DOG_SIT_AFTER + 1.0
	await settle(1.4)
	ck("uzun duraklamada bas duser", head != null and head.rotation.x > 0.12,
		"%.2f" % (0.0 if head == null else head.rotation.x))
	ck("uzun duraklamada govde coker", body != null and body.position.y < -0.015,
		"%.3f" % (0.0 if body == null else body.position.y))
	ck("kuyruk yavaslar", game._animals._resting, "")
	# And it lifts its head the moment the player moves.
	game.mower.position += Vector3(1.5, 0.0, 0.0)
	await settle(0.9)
	ck("oyuncu kimildayinca bas kalkar", head != null and head.rotation.x < 0.1,
		"%.2f" % (0.0 if head == null else head.rotation.x))
	close(game)


## The portrait answers a line, and the cut answers the yard (G44).
func _portrait_and_cut() -> void:
	var box := DialogueBox.new()
	add_child(box)
	await frames(3)
	var home := box._portrait_image.position.y
	box.play(Dialogue.conversation("brief_ch01"), "")
	ck("portre satir baslarken yukselir", box._portrait_image.position.y > home,
		"%.1f -> %.1f" % [home, box._portrait_image.position.y])
	await settle(GameConfig.PORTRAIT_SETTLE + 0.3)
	ck("portre yerine oturur",
		absf(box._portrait_image.position.y - home) < 1.0,
		"%.1f" % box._portrait_image.position.y)
	GameConfig.reduced_motion = true
	box.play(Dialogue.conversation("brief_ch01"), "")
	ck("azaltilmis hareket portreyi oynatmaz",
		absf(box._portrait_image.position.y - home) < 0.01, "")
	GameConfig.reduced_motion = false
	box.queue_free()
	await frames(2)

	# Thick grass reads lower than a lawn that is nearly finished. Averaged:
	# each cut carries a random variant on top, and one sample proves nothing.
	var thick := 0.0
	var thin := 0.0
	for i in 8:
		AudioDirector.play_cut(1.0)
		thick += AudioDirector._cut_players[AudioDirector._cut_index - 1].pitch_scale
		await frames(1)
	for i in 8:
		AudioDirector.play_cut(0.0)
		thin += AudioDirector._cut_players[AudioDirector._cut_index - 1].pitch_scale
		await frames(1)
	ck("dolu bahce daha kalin biciliyor", thick / 8.0 < thin / 8.0,
		"%.3f < %.3f" % [thick / 8.0, thin / 8.0])
