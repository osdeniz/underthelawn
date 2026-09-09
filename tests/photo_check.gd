extends TestBase
## The player's own camera (G47): the interface gets out of the way, the yard
## holds still, the drag swings round it within limits, and closing hands
## everything back exactly as it was.

func run() -> void:
	suite = "FOTOGRAF"
	var game := await open("ch01_aldridge")
	await settle(0.4)
	var before_camera := get_viewport().get_camera_3d()
	ck("acilmadan once oyun kamerasi", before_camera != null, "")

	var mode := PhotoMode.open(game, game.hud)
	# Read before a frame passes: this harness unpauses the tree every frame,
	# so the pause can only be seen the moment it is asked for.
	ck("bahce durdu", get_tree().paused, "")
	await frames(3)
	ck("fotograf modu acildi", mode != null and is_instance_valid(mode), "")
	ck("arayuz cekildi", not game.hud.visible, "")
	ck("kendi kamerasi devrede",
		get_viewport().get_camera_3d() == mode._camera, "")
	ck("mod duraklamada da calisir", mode.process_mode == Node.PROCESS_MODE_ALWAYS, "")
	ck("deklansor ve kapat dugmeleri var",
		mode.find_child("PhotoShutter", true, false) != null
		and mode.find_child("PhotoClose", true, false) != null, "")
	ck("ipucu cevrili", tr("PHOTO_HINT") != "PHOTO_HINT", "")
	# The frame guide: what is outside the card's band is dimmed, and the band
	# itself is the card's own shape.
	var band_top: ColorRect = mode.find_child("PhotoBandTop", true, false)
	var band_bottom: ColorRect = mode.find_child("PhotoBandBottom", true, false)
	ck("cerceve kilavuzu var", band_top != null and band_bottom != null, "")
	if band_top != null and band_bottom != null:
		var view: Vector2 = get_viewport().get_visible_rect().size
		var band: float = view.y - band_top.size.y - band_bottom.size.y
		var want: float = view.x * float(Postcard.PHOTO.y) / float(Postcard.PHOTO.x)
		ck("kilavuz kartin oraninda", absf(band - want) < 2.0,
			"%.1f / %.1f" % [band, want])
		ck("kilavuz ortalanmis", absf(band_top.size.y - band_bottom.size.y) < 2.0,
			"%.1f / %.1f" % [band_top.size.y, band_bottom.size.y])
	ck("kamera genisligi koruyor",
		mode._camera.keep_aspect == Camera3D.KEEP_WIDTH, "")

	# The camera looks at the middle of the yard from outside it.
	var at := mode._camera.position
	ck("kamera bahcenin ortasina bakiyor", at.length() > GameConfig.HALF_X
		and at.y > 0.0, "%s" % at)

	# Dragging swings it round without leaving the sphere.
	var yaw_before := mode._yaw
	mode.swing(Vector2(200.0, 0.0))
	ck("yana surukleme cevirir", not is_equal_approx(mode._yaw, yaw_before),
		"%.2f -> %.2f" % [yaw_before, mode._yaw])
	ck("mesafe korunuyor",
		absf(mode._camera.position.length() - at.length()) < 0.01,
		"%.2f / %.2f" % [mode._camera.position.length(), at.length()])
	# Up and down is clamped short of the ground and short of straight down.
	mode.swing(Vector2(0.0, -9000.0))
	ck("asagi sinirli", mode._pitch >= PhotoMode.PITCH_LIMIT.x - 0.001,
		"%.2f" % mode._pitch)
	mode.swing(Vector2(0.0, 9000.0))
	ck("yukari sinirli", mode._pitch <= PhotoMode.PITCH_LIMIT.y + 0.001,
		"%.2f" % mode._pitch)

	# Zoom, also clamped.
	var reach := mode._camera.position.length()
	(mode.find_child("PhotoIn", true, false) as Button).pressed.emit()
	ck("yakinlastirma yaklastirir", mode._camera.position.length() < reach,
		"%.2f < %.2f" % [mode._camera.position.length(), reach])
	for i in 40:
		mode._set_zoom(mode._zoom - PhotoMode.ZOOM_STEP)
	ck("en yakin sinirda durur", is_equal_approx(mode._zoom, PhotoMode.ZOOM_LIMIT.x),
		"%.2f" % mode._zoom)
	for i in 40:
		mode._set_zoom(mode._zoom + PhotoMode.ZOOM_STEP)
	ck("en uzak sinirda durur", is_equal_approx(mode._zoom, PhotoMode.ZOOM_LIMIT.y),
		"%.2f" % mode._zoom)

	# Closing puts everything back.
	var done := [false]
	mode.closed.connect(func() -> void: done[0] = true)
	(mode.find_child("PhotoClose", true, false) as Button).pressed.emit()
	await frames(4)
	ck("kapaninca haber verir", done[0], "")
	ck("kapaninca arayuz doner", game.hud.visible, "")
	ck("kapaninca oyun kamerasi geri",
		get_viewport().get_camera_3d() == before_camera,
		str(get_viewport().get_camera_3d()))
	ck("katman temizlendi", game.find_child("PhotoLayer", false, false) == null
		or not is_instance_valid(mode), "")

	# The pause sheet is the way in.
	ck("duraklama sayfasinda fotograf satiri var",
		game.hud.find_child("PhotoRow", true, false) != null, "")
	var opened := [false]
	game.hud.photo_requested.connect(func() -> void: opened[0] = true)
	(game.hud.find_child("PhotoRow", true, false) as Button).pressed.emit()
	await frames(2)
	ck("satir modu ister", opened[0], "")
	if game._photo != null and is_instance_valid(game._photo):
		game._photo.close()
		await frames(3)
	ck("albumde fotograf adi var", Postcard.title_for("photo_1") == tr("POSTCARD_PHOTO"),
		Postcard.title_for("photo_1"))
	close(game)
	finish()
