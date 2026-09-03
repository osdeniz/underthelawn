extends Node
## G16: the memory budget, and the proof that chapters do not accumulate.
##
## The app was measured at 939 MB on device. Three things were paying for it:
## one emoji character pulling in the OS colour-emoji font (184 MB), the story
## and portrait art imported uncompressed (~100 MB of VRAM), and the hub's
## diorama holding a full-screen framebuffer through every chapter (~87 MB).
## This test is the fence around all three — it asserts the budget rather than
## the fixes, so any future change that spends the saving is caught here.
##
## The numbers are Godot's own accounting, not the OS footprint, and they are
## resolution-dependent: the harness runs at the shipping 1170x2532.

## Peak, with the hub built AND a chapter running on top of it.
const PEAK_TEXTURE_MB := 230.0
const PEAK_STATIC_MB := 150.0
## What a chapter may leave behind once it has been closed and settled. The
## hub's own cost is the floor here, so this is the leak detector.
const SETTLED_STATIC_MB := 120.0
## The colour-emoji font is 184 MB in one allocation, so anything near that is
## the regression this budget exists to catch.
const CHAPTERS := ["ch01_aldridge", "ch02_neighbor", "ch03_playground"]

var _fails := 0


func mb(v: float) -> float:
	return v / 1048576.0


func texture_mb() -> float:
	return mb(float(RenderingServer.get_rendering_info(
		RenderingServer.RENDERING_INFO_TEXTURE_MEM_USED)))


func static_mb() -> float:
	return mb(Performance.get_monitor(Performance.MEMORY_STATIC))


## Seconds, not frames: root fades between screens on a 0.35 s tween and frees
## the old scene in its callback, so a frame count races the transition on a
## machine whose frame rate the test does not control.
func settle(seconds: float) -> void:
	# The chapter scene pauses the whole tree when the window loses focus, on
	# purpose (Game._notification), and does not lift it on return. A test run
	# does not own the window, so that pause can land at any moment and would
	# stall the fades this harness waits on. Nothing here measures pausing.
	get_tree().paused = false
	await get_tree().create_timer(seconds).timeout
	await get_tree().process_frame


func _ready() -> void:
	GameState.set_setting("purchases", "full", true)  # gate open: tests test the game, DemoCheck tests the gate (G16.6)
	await settle(0.5)
	GameState.set_setting("story", "intro_seen", true)
	var root: Node = load("res://scenes/Root.tscn").instantiate()
	add_child(root)
	# The main menu is the first thing Root shows now; every test that builds
	# it directly has to get past it the way a player's CONTINUE tap does.
	await root.dismiss_main_menu()
	# The hub keeps building for a while after it appears — the diorama grows
	# its town over several frames — so sampling too early records a baseline
	# the rest of the run can only exceed. Waited out rather than guessed at.
	await settle(1.5)
	var hub_nodes := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	while true:
		await settle(0.6)
		var now := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
		if now <= hub_nodes:
			break
		hub_nodes = now

	var peak_tex := 0.0
	var peak_static := 0.0
	var settled_static := 0.0
	var settled_nodes := 0
	for id in CHAPTERS:
		root.set("_pending_variant", id)
		root.call("_start_chapter")
		await settle(2.0)
		peak_tex = maxf(peak_tex, texture_mb())
		peak_static = maxf(peak_static, static_mb())
		root.call("return_to_hub")
		# Waits for the condition, not for a stopwatch: the first chapter of a
		# cold run compiles shaders, so any fixed delay is either flaky or slow.
		await _wait_until_closed(root)
		settled_static = static_mb()
		settled_nodes = int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))

	# Godot's texture-memory counter under-counts once render targets have been
	# freed — it can read zero or go negative — so a plain "under budget" check
	# passes for the wrong reason exactly when the number is broken. Assert only
	# on a reading that is physically possible, and say so when it is not.
	if peak_tex > 1.0:
		ck("doku belleği bütçede", peak_tex <= PEAK_TEXTURE_MB,
			"%.1f MB > %.1f MB" % [peak_tex, PEAK_TEXTURE_MB])
	else:
		print("  [not] doku sayaci okunamadi (%.1f MB) - bu kosuda atlandi"
			% peak_tex)
	ck("statik bellek bütçede", peak_static <= PEAK_STATIC_MB,
		"%.1f MB > %.1f MB" % [peak_static, PEAK_STATIC_MB])
	ck("bölüm kapaninca bellek geri veriliyor",
		settled_static <= SETTLED_STATIC_MB,
		"%.1f MB > %.1f MB" % [settled_static, SETTLED_STATIC_MB])
	# Three chapters opened and closed: the node count has to come back to the
	# hub's own, or something is being kept alive per run.
	ck("bölüm düğüm sızdırmıyor", settled_nodes <= hub_nodes + 20,
		"hub %d -> %d" % [hub_nodes, settled_nodes])
	ck("öksüz düğüm yok",
		int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)) == 0,
		str(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)))

	print("  [ölçüm] tepe doku=%.1f MB  tepe statik=%.1f MB  kapanista=%.1f MB" % [
		peak_tex, peak_static, settled_static])
	if _fails > 0:
		push_error("%d BELLEK TESTI BASARISIZ" % _fails)
		print("--- %d BELLEK TESTI BASARISIZ ---" % _fails)
	else:
		print("--- TUM BELLEK TESTLERI GECTI ---")

	# On a phone this test is read through Xcode's Memory gauge, and a gauge
	# needs a living process. So on device it does NOT quit: it reopens a
	# chapter, parks at the peak, and keeps printing, which is the state the
	# gauge should be photographed in. On desktop it quits as a test should,
	# so the suite still runs to completion.
	if OS.has_feature("mobile"):
		await _hold_at_peak(root)
		return
	get_tree().quit()


## Device mode: sit at the peak — hub built, chapter running on top of it —
## and report every two seconds, so Xcode's gauge has something to show and the
## console carries the same numbers the desktop run prints.
func _hold_at_peak(root: Node) -> void:
	print("--- CIHAZ MODU: tepe durumda bekleniyor, Xcode bellek olcegini oku ---")
	root.set("_pending_variant", CHAPTERS[0])
	root.call("_start_chapter")
	await settle(3.0)
	while true:
		print("  [tepe] doku=%.1f MB  statik=%.1f MB  fps=%d  cizim=%d" % [
			texture_mb(), static_mb(),
			int(Performance.get_monitor(Performance.TIME_FPS)),
			int(Performance.get_monitor(
				Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))])
		await settle(2.0)


## Polls for the chapter scene itself to go, rather than for a stopwatch: root
## frees it inside a fade tween, and the first chapter of a cold run spends
## seconds compiling shaders before that tween ever starts.
func _wait_until_closed(root: Node) -> void:
	var waited := 0.0
	while waited < 15.0:
		get_tree().paused = false
		await get_tree().create_timer(0.25).timeout
		waited += 0.25
		var game := root.get_node_or_null("Main")
		if game == null or not is_instance_valid(game):
			break
	# One more beat so what the scene held is actually released.
	await get_tree().create_timer(0.75).timeout


func ck(what: String, passed: bool, detail: String) -> void:
	if passed:
		print("  ok   %s" % what)
		return
	_fails += 1
	print("  FAIL %s  %s" % [what, detail])
