extends TestBase
## Two captures of the hub showed the town black behind the menu (G19.1
## review). Measured, it was the CAPTURE: the hub opens on the tiles page, the
## town is photographed during an eight-frame warm-up and shown as a still, and
## both shots were taken inside that warm-up. This test opens the hub the way
## root does and checks what the SCREEN shows, on the clock: a lit still
## within a second, and a top half of the screen that is not black.

func run() -> void:
	suite = "HUB KARE"
	var host := Control.new()
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(host)
	var hub := HubScreen.new()
	host.add_child(hub)
	hub.set_diorama_active(true)
	hub.refresh()
	var first_lit := -1.0
	var series := PackedStringArray()
	var t0 := Time.get_ticks_msec()
	var screen_top := 0.0
	while Time.get_ticks_msec() - t0 < 2000:
		await settle(0.25)
		await drawn_frame()
		var at := float(Time.get_ticks_msec() - t0) / 1000.0
		var still: TextureRect = hub._diorama_still
		var still_lum := -1.0
		if still != null and still.texture != null and still.visible:
			still_lum = _mean_lum(still.texture.get_image())
		var screen := get_viewport().get_texture().get_image()
		screen_top = _mean_lum(screen.get_region(
			Rect2i(0, 0, screen.get_width(), int(screen.get_height() * 0.4))))
		series.append("%.2fs still=%.2f ekran=%.2f" % [at, still_lum, screen_top])
		if still_lum > 0.04 and first_lit < 0.0:
			first_lit = at
	print("  [olcum] hub: %s" % " | ".join(series))
	ck("kasaba stili 1 s icinde isikli", first_lit >= 0.0 and first_lit <= 1.0,
		"ilk isik %.2f s" % first_lit)
	# A black town behind the wash measures about 0.02; the lit still measured
	# 0.19 on the first run.
	ck("ekranin ust yarisi siyah degil", screen_top > 0.10, "%.3f" % screen_top)
	ck("acilis sayfasi kasaba degil, still gosteriliyor",
		hub._diorama_still != null and hub._diorama_still.visible)
	hub.queue_free()
	await frames(4)


func _mean_lum(img: Image) -> float:
	if img == null or img.is_empty():
		return 0.0
	var total := 0.0
	var n := 0
	var step := maxi(img.get_width() / 60, 1)
	for y in range(0, img.get_height(), step):
		for x in range(0, img.get_width(), step):
			total += img.get_pixel(x, y).get_luminance()
			n += 1
	return total / maxf(float(n), 1.0)
