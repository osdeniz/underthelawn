extends Node
## G14.5: the fireflies are there at night, gone at noon, and cost nothing.

var _fails := 0


func _ready() -> void:
	GameState.set_setting("meta", "orientation_done", true)
	var readings := {}
	for mode: String in [GameConfig.SKY_MODE_DAY, GameConfig.SKY_MODE_NIGHT]:
		SkyTime.set_mode(mode)
		var game: Node = load("res://scenes/Main.tscn").instantiate()
		game.variant_id = "ch04_flooded"
		add_child(game)
		for _i in 10:
			await get_tree().process_frame
		get_tree().paused = false
		game.hud._close_pause()
		game._begin_search()
		for _i in 40:
			get_tree().paused = false
			await get_tree().process_frame
		var swarms: Array = game.find_children("Fireflies", "", true, false)
		ck("%s: suru kuruldu" % mode, swarms.size() == 1, "%d" % swarms.size())
		var swarm := swarms[0] as Fireflies
		var lit: bool = mode == GameConfig.SKY_MODE_NIGHT
		ck("%s: dogru saatte yaniyor" % mode, swarm.emitting == lit,
			str(swarm.emitting))
		# One system, one draw, however many sparks are in it.
		ck("%s: tek dugum" % mode,
			swarm.get_child_count() == 0 and swarm is GPUParticles3D, "")
		readings[mode] = RenderingServer.get_rendering_info(
			RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
		print("  [olcum] %s cizim=%d parcacik=%d" % [mode, readings[mode],
			swarm.amount if swarm.emitting else 0])
		game.queue_free()
		for _i in 8:
			await get_tree().process_frame

	# The cost question has to be asked of ONE scene with the swarm switched off
	# and on. Comparing a day scene against a night scene measures the whole
	# night — a different sky, different shadows, different culling — and the
	# first attempt did exactly that and blamed the fireflies for 166 draws.
	SkyTime.set_mode(GameConfig.SKY_MODE_NIGHT)
	var game: Node = load("res://scenes/Main.tscn").instantiate()
	game.variant_id = "ch04_flooded"
	add_child(game)
	for _i in 10:
		await get_tree().process_frame
	get_tree().paused = false
	game.hud._close_pause()
	game._begin_search()
	for _i in 40:
		get_tree().paused = false
		await get_tree().process_frame
	var swarm := game.find_children("Fireflies", "", true, false)[0] as Fireflies
	# The animals have to be STILLED for this measurement (G14.25). They appear,
	# vanish and move between rounds, and a rabbit blinking in or out is a
	# handful of draws — measured, it turned a 9-draw firefly reading into a
	# failure of a 4-draw budget. Same lesson as the note above: leave one
	# variable in the frame, not two.
	var animals := game._animals as Animals
	if animals != null and is_instance_valid(animals):
		animals.set_process(false)
		animals.visible = false
	# Alternated, not measured once each: the opening camera is still descending
	# while this runs, so what is culled changes from second to second and a
	# single on-then-off comparison reads that drift as a cost. Four rounds of
	# off/on cancel it.
	var on_total := 0
	var off_total := 0
	for round_index in 4:
		off_total += await _draws(false, swarm)
		on_total += await _draws(true, swarm)
	var on := int(round(float(on_total) / 4.0))
	var off := int(round(float(off_total) / 4.0))
	print("  [olcum] ayni sahne: acik=%d kapali=%d fark=%d" % [on, off, on - off])
	# Headless has no renderer and reports zero draw calls for everything, so
	# this assertion would pass by measuring nothing at all. Say so instead:
	# a check that cannot fail is worse than no check.
	if on == 0 and off == 0:
		print("  ATLANDI maliyet olcumu: headless'ta cizim sayaci yok"
			+ " - pencereli calistir")
	else:
		ck("suru bedava sayilir", absi(on - off) <= 4,
			"%d cizim fark" % (on - off))
	game.queue_free()

	SkyTime.set_mode(GameConfig.SKY_MODE_AUTO)
	if _fails > 0:
		push_error("%d ATESBOCEGI TESTI BASARISIZ" % _fails)
		print("--- %d ATESBOCEGI TESTI BASARISIZ ---" % _fails)
	else:
		print("--- TUM ATESBOCEGI TESTLERI GECTI ---")
	get_tree().quit()


## Draw calls with the swarm in the given state, averaged over a few frames so
## a single odd frame cannot decide it.
func _draws(on: bool, swarm: Fireflies) -> int:
	swarm.emitting = on
	swarm.visible = on
	for _i in 10:
		await get_tree().process_frame
	var total := 0
	for _i in 8:
		await get_tree().process_frame
		total += RenderingServer.get_rendering_info(
			RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
	return int(round(float(total) / 8.0))


func ck(label: String, passed: bool, detail: String) -> void:
	if passed:
		return
	_fails += 1
	print("  FAIL %s  %s" % [label, detail])
