extends Node
## G14.16: stepping off the machine, and what each machine does about it.

var _fails := 0


func _ready() -> void:
	GameState.set_setting("meta", "orientation_done", true)
	# --- a DRIVEN machine parks while you walk
	var game := await _open(GameConfig.MOWER_PUSH)
	ck("basta yurumuyoruz", not game.walking(), "")
	var mower_at: Vector3 = game.mower.position
	game.toggle_walk()
	await get_tree().process_frame
	ck("indik", game.walking(), "")
	ck("surulen makine durdu", not game.mower.is_active, "")
	var walker: Walker = game.get_node_or_null("Walker")
	ck("yurüyücü sahnede", walker != null, "")
	ck("makinenin yaninda indik",
		walker != null and walker.position.distance_to(mower_at) < 2.0,
		"%.2f" % (walker.position.distance_to(mower_at) if walker else -1.0))
	ck("kamera yurüyücüde", game.cam.target == walker, "")

	# Walking must not cut anything: that is the whole rule.
	var mown_before: int = game.model.mowed_count
	if walker != null:
		for _i in 40:
			walker.position += Vector3(0.0, 0.0, -0.1)
			await get_tree().process_frame
	ck("yurürken cim bicilmiyor", game.model.mowed_count == mown_before,
		"%d -> %d" % [mown_before, game.model.mowed_count])

	# Out of reach, the button refuses rather than teleporting.
	ck("uzaktan binilemiyor", not walker.in_reach(), "")
	game.toggle_walk()
	await get_tree().process_frame
	ck("uzaktayken yurumeye devam", game.walking(), "")
	# Walk back and it works.
	walker.position = game.mower.position
	await get_tree().process_frame
	game.toggle_walk()
	await get_tree().process_frame
	ck("yaninda binildi", not game.walking(), "")
	ck("makine tekrar aktif", game.mower.is_active, "")
	ck("kamera makinede", game.cam.target == game.mower, "")
	game.queue_free()
	await get_tree().process_frame

	# --- an AUTONOMOUS machine keeps working
	var robot := await _open(GameConfig.MOWER_ROBOT)
	robot.toggle_walk()
	await get_tree().process_frame
	ck("robot yururken calismaya devam", robot.mower.is_active, "")
	ck("robotta da yuruyoruz", robot.walking(), "")
	robot.queue_free()

	if _fails > 0:
		push_error("%d YURUME TESTI BASARISIZ" % _fails)
		print("--- %d YURUME TESTI BASARISIZ ---" % _fails)
	else:
		print("--- TUM YURUME TESTLERI GECTI ---")
	get_tree().quit()


func _open(index: int) -> Node:
	var game: Node = load("res://scenes/Main.tscn").instantiate()
	game.variant_id = "ch01_aldridge"
	add_child(game)
	for _i in 12:
		await get_tree().process_frame
	get_tree().paused = false
	game.hud._close_pause()
	game.select_mower(index)
	game._begin_search()
	for _i in 10:
		get_tree().paused = false
		await get_tree().process_frame
	return game


func ck(label: String, passed: bool, detail: String) -> void:
	if passed:
		return
	_fails += 1
	print("  FAIL %s  %s" % [label, detail])
