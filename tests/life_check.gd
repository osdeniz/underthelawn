extends Node
## G14.22: the head turns toward what the driver has noticed, and a standing
## figure does not stand perfectly level.

var _fails := 0


func _ready() -> void:
	GameState.set_setting("meta", "orientation_done", true)
	var game: Node = load("res://scenes/Main.tscn").instantiate()
	game.variant_id = "ch01_aldridge"
	add_child(game)
	for _i in 12:
		await get_tree().process_frame
	get_tree().paused = false
	game.hud._close_pause()
	game._begin_search()
	for _i in 20:
		get_tree().paused = false
		await get_tree().process_frame
	var who: Character = game.character
	ck("surucu var", who != null, "")
	if who == null:
		_finish()
		return

	# --- the head turns, and turns the RIGHT way
	who.look_has = true
	# A point hard to the driver's left, in world space.
	var left := who.global_position \
		+ who.global_transform.basis.x * -4.0 + Vector3.UP * 0.4
	who.look_target = left
	# LOOK_LERP is 5 per second, so half a second is most of the way there.
	await _settle(0.6)
	var yaw_left := who._head.rotation.y
	who.look_target = who.global_position \
		+ who.global_transform.basis.x * 4.0 + Vector3.UP * 0.4
	await _settle(0.6)
	var yaw_right := who._head.rotation.y
	ck("kafa iki yana da donuyor", absf(yaw_left - yaw_right) > 0.4,
		"%.2f vs %.2f" % [yaw_left, yaw_right])
	ck("kafa donusu insan araliginda",
		absf(yaw_left) <= GameConfig.LOOK_YAW_MAX + 0.05
		and absf(yaw_right) <= GameConfig.LOOK_YAW_MAX + 0.05,
		"%.2f / %.2f" % [yaw_left, yaw_right])
	# Nothing to look at: the head comes back.
	who.look_has = false
	await _settle(1.0)
	ck("bakacak sey yokken kafa duzeliyor", absf(who._head.rotation.y) < 0.25,
		"%.2f" % who._head.rotation.y)

	# --- and the game picks a target by itself when something is out there
	ck("bahcede bakilacak sey var",
		game.scrap_field.pending_cells().size() > 0,
		"%d" % game.scrap_field.pending_cells().size())

	# --- standing still is not standing LEVEL
	#
	# The first version of this sampled a 1.5 second window and asked for
	# movement inside it, then failed at 0.0007. The shift is a slow swap every
	# five seconds: sampled inside a settled stretch there is nothing to see.
	# The claim is that the weight is ON one leg, and that it changes legs.
	await _settle(1.0)
	var loaded: float = who._hip_l.position.y
	ck("agirlik bir bacakta", absf(loaded) > 0.01,
		"%.4f" % loaded)
	# And the lean stays a LEAN. Adding the shift to a decaying rotation every
	# frame settled it at constant/fraction — a 3 degree intent came out as 30.
	ck("egilme insan olcusunde",
		absf(who._torso.rotation.z) < GameConfig.IDLE_TORSO_ROLL * 2.0,
		"%.1f derece" % rad_to_deg(who._torso.rotation.z))
	# Force the swap rather than waiting five seconds for it.
	who._shift_timer = GameConfig.IDLE_SHIFT_PERIOD
	await _settle(1.5)
	ck("agirlik obur bacaga geciyor",
		signf(who._hip_l.position.y) != signf(loaded)
		and absf(who._hip_l.position.y) > 0.01,
		"%.4f -> %.4f" % [loaded, who._hip_l.position.y])

	game.queue_free()
	_finish()


func _finish() -> void:
	if _fails > 0:
		push_error("%d CANLILIK TESTI BASARISIZ" % _fails)
		print("--- %d CANLILIK TESTI BASARISIZ ---" % _fails)
	else:
		print("--- TUM CANLILIK TESTLERI GECTI ---")
	get_tree().quit()


## Yields frames until `seconds` of PROCESS TIME have gone by, not until a
## frame count is reached. Every assertion below is about something that decays
## or swings at a rate per SECOND, and a frame count is not a duration: run
## headless the scene reaches several hundred frames a second, so forty frames
## was sixty milliseconds and the head had barely started coming back. This
## test failed and passed on identical code depending on how fast the machine
## happened to be that run, which is worse than not having it.
func _settle(seconds: float) -> void:
	var spent := 0.0
	while spent < seconds:
		get_tree().paused = false
		await get_tree().process_frame
		spent += get_process_delta_time()


func ck(label: String, passed: bool, detail: String) -> void:
	if passed:
		return
	_fails += 1
	print("  FAIL %s  %s" % [label, detail])
