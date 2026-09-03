class_name TestBase
extends Node
## What every scene test in this project needs and three of them got wrong on
## their own (G16.5). Extend this, implement run(), and the harness lessons of
## G14.26-G15.2 come for free:
##
##   * PROCESS_MODE_ALWAYS and an unpause every frame. A headless window has
##     no focus; the game correctly pauses itself for the background; a paused
##     tree runs neither the mowers nor the TEST's own _process. Three tests
##     hung or failed on exactly this.
##   * settle() waits on the WALL CLOCK, not on frame counts (headless runs at
##     hundreds of frames a second) and not on summed deltas (0 on a paused
##     node). Capped, so it can never spin for ever.
##   * drawn_frame() waits for a frame that was actually rendered, or gives up
##     after a quarter second — a bare await on frame_post_draw never returns
##     when the window is not drawing.
##   * open() builds a chapter the way every test did by hand, unpaused and
##     with the pause sheet closed.
##   * ck()/finish() print the one verdict line the runner greps for. A test
##     with no verdict is reported as "??", never as passed.

var _fails := 0
var _drew := false
## The per-frame unpause is what keeps a headless run alive; a test whose CLAIM
## is that the game pauses (InputMapCheck's background check) turns it off for
## that stretch, or the harness disproves the thing it is testing.
var keep_unpaused := true
## Printed in the verdict line: "TUM <suite> TESTLERI GECTI" / "N <suite> TESTI BASARISIZ".
var suite := "TEST"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = false
	GameState.set_setting("meta", "orientation_done", true)
	# The gate is open for every suite but the one that tests the gate
	# (DemoCheck lowers it itself). Case2FlowB failed three checks the night the
	# gate landed, because its chapters start at ch09 and the card opened
	# instead of the level.
	GameState.set_setting("purchases", "full", true)
	await run()
	finish()


func _process(_delta: float) -> void:
	if keep_unpaused:
		get_tree().paused = false


## Override. Await freely; finish() runs when it returns.
func run() -> void:
	pass


func finish() -> void:
	if _fails > 0:
		push_error("%d %s TESTI BASARISIZ" % [_fails, suite])
		print("--- %d %s TESTI BASARISIZ ---" % [_fails, suite])
	else:
		print("--- TUM %s TESTLERI GECTI ---" % suite)
	get_tree().quit()


func ck(label: String, passed: bool, detail := "") -> void:
	if passed:
		return
	_fails += 1
	print("  FAIL %s  %s" % [label, detail])


func frames(count: int) -> void:
	for _i in count:
		get_tree().paused = false
		await get_tree().process_frame


func settle(seconds: float) -> void:
	var until := Time.get_ticks_msec() + int(seconds * 1000.0)
	var n := 0
	while Time.get_ticks_msec() < until and n < 6000:
		get_tree().paused = false
		await get_tree().process_frame
		n += 1


func drawn_frame() -> void:
	_drew = false
	var mark := func() -> void: _drew = true
	RenderingServer.frame_post_draw.connect(mark, CONNECT_ONE_SHOT)
	var until := Time.get_ticks_msec() + 250
	while not _drew and Time.get_ticks_msec() < until:
		get_tree().paused = false
		await get_tree().process_frame
	if RenderingServer.frame_post_draw.is_connected(mark):
		RenderingServer.frame_post_draw.disconnect(mark)


## A chapter, searching, unpaused, pause sheet closed.
func open(chapter: String, tips_off := true) -> Node:
	if tips_off:
		for key: String in ["money", "food"]:
			GameState.set_setting("tips", key, true)
	var game: Node = load("res://scenes/Main.tscn").instantiate()
	game.variant_id = chapter
	add_child(game)
	await frames(10)
	get_tree().paused = false
	game.hud._close_pause()
	game._begin_search()
	await frames(16)
	return game


func close(game: Node) -> void:
	if game != null and is_instance_valid(game):
		game.queue_free()
	await frames(6)
