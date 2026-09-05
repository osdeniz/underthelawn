extends Node
## G14.4/G14.7: is the lawn still readable under each light, wet and dry?
##
## The whole game is telling cut grass from uncut. Eyeballing a screenshot is
## not evidence, so this mows a band in front of the camera and measures the
## mean brightness of the cut patch against standing grass, under every preset.
##
## It has caught three things nothing else would have:
##   * Night measured the same as afternoon. The presets where the lawn had
##     genuinely stopped reading were "golden" and "dusk", at 0.001 and 0.004.
##   * The fix was AZIMUTH, not brightness: the camera looks north, so a sun
##     near azimuth 0 lights from behind it and flattens everything.
##   * Rain in the dark. A downpour at night flattened the lawn to 0.000, and
##     no amount of thinning the drops got it over the floor — which is why the
##     game now refuses to rain in the last two hours of the day.
##
## ONE yard for both passes, with the weather as the only variable. Reading the
## wet pass off the flooded chapter and the dry pass off Aldridge measured the
## two LAYOUTS instead: the flooded yard's pool sits under the sample bands and
## reported 0.001 at night with the rain switched off entirely.
##
## The numbers are only comparable WITHIN one run: they shift with how far the
## opening camera has descended when the frame is taken. UTL_WET picks the pass
## (0 dry, 1 wet) and UTL_HOURS narrows it, because sixteen scene builds do not
## fit in one run.

## Below this, cut and uncut grass are the same colour and the game stops being
## playable, whatever the screenshot looks like.
const FLOOR := 0.030

var _fails := 0


func _ready() -> void:
	# The desktop default is a landscape window with KEEP_HEIGHT (G18) and the
	# OS clamps a 2532-tall window to the screen, so the viewport came back
	# 1534 wide and the two sample bands no longer lay over the rows they were
	# written for: dawn measured 0.003 where it had measured 0.059 (G19.1).
	# Letterbox to the phone's exact frame; this is a phone measurement.
	get_window().content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	await get_tree().process_frame
	GameState.set_setting("meta", "orientation_done", true)
	var only := str(OS.get_environment("UTL_WET"))
	var passes: Array = [false, true]
	if only == "1":
		passes = [true]
	elif only == "0":
		passes = [false]
	for wet: bool in passes:
		await _sweep(wet)
	if _fails > 0:
		push_error("%d ISIK OKUNMUYOR" % _fails)
		print("--- %d OKUNABILIRLIK TESTI BASARISIZ ---" % _fails)
	else:
		print("--- TUM ISIKLARDA CIM OKUNUYOR ---")
	get_tree().quit()


func _sweep(wet: bool) -> void:
	var only_hours := str(OS.get_environment("UTL_HOURS")).split(",", false)
	for id: String in GameConfig.TIME_OF_DAY:
		if only_hours.size() > 0 and not only_hours.has(id):
			continue
		SkyTime.set_mode(GameConfig.SKY_MODE_AUTO)
		var game: Node = load("res://scenes/Main.tscn").instantiate()
		game.variant_id = "ch01_aldridge"
		add_child(game)
		for _i in 8:
			await get_tree().process_frame
		get_tree().paused = false
		game.hud._close_pause()

		# The hour goes ON THE VARIANT, not just into the environment:
		# everything else asks the variant what time it is, and writing "night"
		# to the lights while the chapter still said "dawn" left the rain
		# falling in an hour the game forbids it in.
		if LevelVariant.current != null:
			LevelVariant.current.time_of_day = id
			LevelVariant.current.weather = GameConfig.WEATHER_RAIN if wet \
				else GameConfig.WEATHER_CLEAR
		for any: Variant in game.find_children("Rain", "", true, false):
			var drops := any as Rain
			if drops != null:
				drops.refresh()
		SkyTime.apply(game.get_node("WorldEnvironment") as WorldEnvironment,
			game.get_node("Sun") as DirectionalLight3D, id)
		# Whether it is ACTUALLY raining, which is not the same as being asked
		# to: the game refuses the last two hours of the day.
		var raining := Rain.is_wet()

		game._begin_search()
		for row in range(GameConfig.GRID_ROWS - 6, GameConfig.GRID_ROWS):
			for col in GameConfig.GRID_COLS:
				game.model.mow(col, row, 0)
		# On the WALL CLOCK, not on sixty frames (G19.2): the camera is still
		# descending from the opening shot during those frames, and how far it
		# had got depended on the frame rate of the run — so the two sample
		# bands lay over different rows each time and the colour-blind gaps
		# swung threefold between two runs of the same hour (0.027 / 0.082).
		# Until the camera has STOPPED, not for a fixed time: the first sky of
		# the process compiles the shaders and its frames stall, so 2.6 s of
		# wall clock still caught dawn mid-descent (0.021 against 0.058 on the
		# same sky an hour later). Capped, so it can never spin for ever.
		var cam: Camera3D = game.get_viewport().get_camera_3d()
		var t0 := Time.get_ticks_msec()
		var last := cam.global_position if cam != null else Vector3.ZERO
		var still := 0
		while Time.get_ticks_msec() - t0 < 8000:
			get_tree().paused = false
			await get_tree().process_frame
			if cam == null or not is_instance_valid(cam):
				cam = game.get_viewport().get_camera_3d()
				continue
			var now := cam.global_position
			still = still + 1 if now.distance_to(last) < 0.0005 else 0
			last = now
			if still >= 20 and Time.get_ticks_msec() - t0 > 1200:
				break
		await _drawn()

		var img := get_viewport().get_texture().get_image()
		var w := img.get_width()
		var h := img.get_height()
		var cut := _mean(img, Rect2i(int(w * 0.12), int(h * 0.74),
			int(w * 0.76), int(h * 0.10)))
		var tall := _mean(img, Rect2i(int(w * 0.12), int(h * 0.42),
			int(w * 0.76), int(h * 0.10)))
		var gap := absf(cut - tall)
		# The same two bands through a colour-blind eye (G16.4). Luminance is
		# what the game relies on, and luminance survives a missing cone; but
		# "relies on" is a claim, and this is the measurement of it: Machado's
		# severity-1.0 deuteranopia and protanopia matrices applied to the mean
		# colours, and the gap read again.
		var cut_rgb := _mean_rgb(img, Rect2i(int(w * 0.12), int(h * 0.74),
			int(w * 0.76), int(h * 0.10)))
		var tall_rgb := _mean_rgb(img, Rect2i(int(w * 0.12), int(h * 0.42),
			int(w * 0.76), int(h * 0.10)))
		var gap_deutan := absf(_cvd(cut_rgb, DEUTAN).get_luminance()
			- _cvd(tall_rgb, DEUTAN).get_luminance())
		var gap_protan := absf(_cvd(cut_rgb, PROTAN).get_luminance()
			- _cvd(tall_rgb, PROTAN).get_luminance())
		print("          renk korlugu: deutan=%.3f protan=%.3f" % [gap_deutan, gap_protan])
		if gap_deutan < FLOOR or gap_protan < FLOOR:
			_fails += 1
			print("  FAIL %s renk korlugunde okunmuyor (deutan %.3f, protan %.3f, taban %.3f)"
				% [id, gap_deutan, gap_protan, FLOOR])
		var label := ("yagmur" if raining else "kuru-*") if wet else "kuru  "
		print("%-9s %s bicilmis=%.3f  uzun=%.3f  fark=%.3f"
			% [id, label, cut, tall, gap])
		if gap < FLOOR:
			_fails += 1
			print("  FAIL %s (%s) okunmuyor  %.3f < %.3f"
				% [id, label.strip_edges(), gap, FLOOR])
		game.queue_free()
		for _i in 6:
			await get_tree().process_frame


## A frame that was actually drawn, or a quarter second — never a bare await on
## frame_post_draw, which hangs for good once the window loses focus and the
## game pauses itself (the trap TestBase.drawn_frame exists for; this test
## predates TestBase and took 400 s of a limiter to remind us).
var _drew := false
func _drawn() -> void:
	_drew = false
	var mark := func() -> void: _drew = true
	RenderingServer.frame_post_draw.connect(mark, CONNECT_ONE_SHOT)
	var until := Time.get_ticks_msec() + 250
	while not _drew and Time.get_ticks_msec() < until:
		get_tree().paused = false
		await get_tree().process_frame
	if RenderingServer.frame_post_draw.is_connected(mark):
		RenderingServer.frame_post_draw.disconnect(mark)


## Machado, Oliveira & Fernandes (2009), severity 1.0. Rows of the RGB matrix.
const DEUTAN: Array = [Vector3(0.367322, 0.860646, -0.227968),
	Vector3(0.280085, 0.672501, 0.047413), Vector3(-0.011820, 0.042940, 0.968881)]
const PROTAN: Array = [Vector3(0.152286, 1.052583, -0.204868),
	Vector3(0.114503, 0.786281, 0.099216), Vector3(-0.003882, -0.048116, 1.051998)]


func _cvd(c: Color, m: Array) -> Color:
	var v := Vector3(c.r, c.g, c.b)
	return Color(clampf((m[0] as Vector3).dot(v), 0.0, 1.0),
		clampf((m[1] as Vector3).dot(v), 0.0, 1.0),
		clampf((m[2] as Vector3).dot(v), 0.0, 1.0))


func _mean_rgb(img: Image, area: Rect2i) -> Color:
	var total := Vector3.ZERO
	var count := 0
	for y in range(area.position.y, area.end.y, 4):
		for x in range(area.position.x, area.end.x, 4):
			var c := img.get_pixel(x, y)
			total += Vector3(c.r, c.g, c.b)
			count += 1
	total /= maxf(float(count), 1.0)
	return Color(total.x, total.y, total.z)


func _mean(img: Image, area: Rect2i) -> float:
	var total := 0.0
	var count := 0
	for y in range(area.position.y, area.end.y, 4):
		for x in range(area.position.x, area.end.x, 4):
			var c := img.get_pixel(x, y)
			total += c.get_luminance()
			count += 1
	return total / maxf(float(count), 1.0)
