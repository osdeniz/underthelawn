extends TestBase
## G68: the three tour steps as the player sees them, at the phone's own frame.

func run() -> void:
	suite = "TUR CEKIM"
	min_checks = 6
	get_window().content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	await frames(2)
	GameState.set_setting(Guide.SECTION, Guide.TOUR_KEY, false)
	var hub := HubScreen.new()
	add_child(hub)
	await settle(1.2)
	hub.run_tour_if_new()
	for i in Guide.tour().size():
		await settle(0.8)
		await drawn_frame()
		var frame := get_viewport().get_visible_rect()
		get_viewport().get_texture().get_image().get_region(
			Rect2i(Vector2i(frame.position), Vector2i(frame.size))).save_png(
			"res://out/tour_%d.png" % i)
		var ring := hub.find_child("TourRing", true, false) as Control
		var view := frame.size
		if ring != null:
			var box := ring.get_global_rect()
			print("[olcum] adim %d halkasi: y %%%.0f-%%%.0f, x %%%.0f-%%%.0f" % [i,
				box.position.y / view.y * 100.0, box.end.y / view.y * 100.0,
				box.position.x / view.x * 100.0, box.end.x / view.x * 100.0])
		var note := hub.find_child("GuideNote", true, false) as Control
		# The one thing a phone cannot forgive, and the one G56 got wrong: the
		# note and the ring must not sit on top of each other, or the tour
		# covers its own subject.
		ck("adim %d halkasi ve notu ayri duruyor" % i,
			ring != null and note != null
				and not ring.get_global_rect().intersects(note.get_global_rect()),
			"halka %s / not %s" % ["-" if ring == null else str(ring.get_global_rect()),
				"-" if note == null else str(note.get_global_rect())])
		if note != null:
			var nb := note.get_global_rect()
			print("[olcum] adim %d notu: y %%%.0f-%%%.0f, yuksekligi %.0fpx" % [i,
				nb.position.y / view.y * 100.0, nb.end.y / view.y * 100.0, nb.size.y])
			# The longest sentence in the tour is the wallet's three numbers; a
			# note that grows past the top of the frame is G56's bug upside
			# down, and only the real string at the real width can show it.
			ck("adim %d notu ekrana siginiyor" % i,
				nb.position.y >= 0.0 and nb.end.y <= view.y + 1.0,
				"%.0f - %.0f / %.0f" % [nb.position.y, nb.end.y, view.y])
		var go := hub.find_child("GuideGo", true, false) as Button
		if go != null:
			go.pressed.emit()
	print("[cekim] out/tour_0..2.png yazildi")
	hub.queue_free()
	await frames(2)
