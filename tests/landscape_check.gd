extends TestBase
## G18: a 16:9 window. The viewport widens (stretch viewport, keep height) and
## every reading surface keeps to a centred column of UI_MAX_WIDTH instead of
## stretching a line of dialogue across four thousand pixels.

func run() -> void:
	suite = "YATAY"
	get_window().size = Vector2i(1600, 900)
	await frames(4)
	var vp := get_viewport().get_visible_rect().size
	ck("gorunum yatay", vp.x > vp.y, str(vp))
	var margin := GameConfig.wide_margin(vp.x)
	ck("kenar payi pozitif", margin > 100.0, "%.0f" % margin)

	var box := DialogueBox.new()
	add_child(box)
	await frames(3)
	var panel: Control = box._panel
	ck("diyalog paneli sutunda", panel.size.x <= GameConfig.UI_MAX_WIDTH + 2.0, "%.0f genis" % panel.size.x)
	ck("diyalog paneli ortada", absf(panel.position.x - (margin + 40.0)) < 2.0,
		"x=%.0f beklenen %.0f" % [panel.position.x, margin + 40.0])
	var portrait: Control = box._portrait_frame
	ck("portre sutunun icinde", portrait.position.x >= margin - 1.0, "%.0f" % portrait.position.x)
	box.queue_free()

	var intro := IntroSequence.new()
	intro.cards_key = "intro.cards"
	add_child(intro)
	await frames(3)
	ck("kart metni sutunda", intro._lines.size.x <= GameConfig.UI_MAX_WIDTH + 2.0,
		"%.0f" % intro._lines.size.x)
	intro.queue_free()

	var hub := HubScreen.new()
	add_child(hub)
	await frames(3)
	var widest := 0.0
	for page: Control in hub._pages():
		widest = maxf(widest, page.size.x)
	ck("hub sayfalari sutunda", widest <= GameConfig.UI_MAX_WIDTH + 2.0, "%.0f" % widest)
	hub.queue_free()

	var settings := SettingsScreen.new()
	add_child(settings)
	await frames(3)
	ck("ayar satirlari sutunda", settings._rows.size.x <= GameConfig.UI_MAX_WIDTH + 2.0,
		"%.0f" % settings._rows.size.x)
	settings.queue_free()

	# And the yard itself: wider than tall, camera untouched, HUD column centred.
	var game: Node = await open("ch01_aldridge")
	var bar: Control = game.hud.get_node_or_null("TopBar")
	if bar != null:
		ck("HUD ust bari ortada", absf(bar.offset_left - (margin + 56.0)) < 2.0,
			"%.0f" % bar.offset_left)
	var walk: Control = game.hud._walk_button
	if walk != null:
		ck("IN dugmesi sutunun icinde", walk.position.x >= margin - 1.0,
			"x=%.0f pay=%.0f" % [walk.position.x, margin])
	print("  [olcum] yatay gorunum %s, kenar payi %.0f" % [vp, margin])
	await close(game)
	get_window().size = Vector2i(1170, 2532)
