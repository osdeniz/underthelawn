extends Node
## G14.4: is the lawn still readable under each light?
##
## The whole game is telling cut grass from uncut. Eyeballing a screenshot is
## not evidence, so this mows a band in front of the camera and measures the
## mean brightness of the cut patch against standing grass, under every preset.
##
## It caught two things nothing else would have. Night — the preset everyone
## expected to be the problem — measured the same as afternoon. The real
## offenders were "golden" and "dusk" at 0.001 and 0.004 apart, meaning the
## lawn had stopped reading AT ALL under two of the story's own hours. And the
## fix was not brightness but AZIMUTH: the camera looks north, so a sun near
## azimuth 0 shines from behind it and flattens everything into one tone.
##
## The numbers are only comparable WITHIN one run: they shift with how far the
## opening camera has descended when the frame is taken. The floor is set well
## under the spread that leaves.

## Below this, cut and uncut grass are the same colour and the game stops
## being playable, whatever the screenshot looks like.
const FLOOR := 0.030

var _fails := 0


func _ready() -> void:
	GameState.set_setting("meta", "orientation_done", true)
	for id: String in GameConfig.TIME_OF_DAY:
		SkyTime.set_mode(GameConfig.SKY_MODE_AUTO)
		var game: Node = load("res://scenes/Main.tscn").instantiate()
		game.variant_id = "ch04_flooded"
		add_child(game)
		for _i in 8:
			await get_tree().process_frame
		get_tree().paused = false
		game.hud._close_pause()
		SkyTime.apply(game.get_node("WorldEnvironment") as WorldEnvironment,
			game.get_node("Sun") as DirectionalLight3D, id)
		game._begin_search()
		# Mow a band right in front of the camera, leaving the rest standing.
		for row in range(GameConfig.GRID_ROWS - 6, GameConfig.GRID_ROWS):
			for col in GameConfig.GRID_COLS:
				game.model.mow(col, row, 0)
		for _i in 110:
			get_tree().paused = false
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		var w := img.get_width()
		var h := img.get_height()
		# Cut band low in the frame, standing grass in the middle of it.
		var cut := _mean(img, Rect2i(int(w * 0.12), int(h * 0.74),
			int(w * 0.76), int(h * 0.10)))
		var tall := _mean(img, Rect2i(int(w * 0.12), int(h * 0.42),
			int(w * 0.76), int(h * 0.10)))
		var gap := absf(cut - tall)
		print("%-9s bicilmis=%.3f  uzun=%.3f  fark=%.3f" % [id, cut, tall, gap])
		if gap < FLOOR:
			_fails += 1
			print("  FAIL %s okunmuyor  %.3f < %.3f" % [id, gap, FLOOR])
		game.queue_free()
		for _i in 6:
			await get_tree().process_frame
	if _fails > 0:
		push_error("%d ISIK OKUNMUYOR" % _fails)
		print("--- %d OKUNABILIRLIK TESTI BASARISIZ ---" % _fails)
	else:
		print("--- TUM ISIKLARDA CIM OKUNUYOR ---")
	get_tree().quit()


func _mean(img: Image, area: Rect2i) -> float:
	var total := 0.0
	var count := 0
	for y in range(area.position.y, area.end.y, 4):
		for x in range(area.position.x, area.end.x, 4):
			var c := img.get_pixel(x, y)
			total += c.get_luminance()
			count += 1
	return total / maxf(float(count), 1.0)
