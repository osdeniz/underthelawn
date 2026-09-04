extends Node
## G14.2: sky decoration has to be ON SCREEN, and this is the only way to know.
##
## The first pass put a cloud ring around the town and flocks above it. Both
## looked right in the scene tree and neither was ever visible: the hub camera
## stands at (0, 28, 28.5) looking north and down 39 degrees, so a ring centred
## on the plate is mostly beside and behind it, and its top edge is 2.8 degrees
## BELOW the horizon, so anything in the actual sky is off the top of the frame.
## A probe found 0 of 11 clouds and 0 of 30 birds on screen.

var _fails := 0


func _ready() -> void:
	# Headless has no window, so the root viewport comes back SQUARE (2532 x
	# 2532). The camera keeps its width, so a square frame has a far taller
	# field of view than the phone does and everything measures as off-screen.
	# Pin it to the real portrait viewport before measuring anything.
	var want := Vector2i(
		int(ProjectSettings.get_setting("display/window/size/viewport_width", 1170)),
		int(ProjectSettings.get_setting("display/window/size/viewport_height", 2532)))
	get_window().size = want
	get_window().content_scale_size = want
	# The desktop default is a landscape window with KEEP_HEIGHT (G18), and the
	# OS clamps a 2532-tall window to the screen, so the viewport came back
	# 1534 wide and the KEEP_WIDTH camera lost the sky off the top. Letterbox
	# to the phone's exact frame: this test is about the phone.
	get_window().content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	await get_tree().process_frame
	await get_tree().process_frame

	var town: TownDiorama = load("res://scenes/TownDiorama.tscn").instantiate()
	add_child(town)
	for _i in 20:
		await get_tree().process_frame

	var cam: Camera3D = null
	for any: Variant in town.find_children("*", "Camera3D", true, false):
		var c := any as Camera3D
		if c != null and c.current:
			cam = c
	ck("diyorama kamerasi var", cam != null, "")
	if cam == null:
		_finish()
		return

	var sky := town.get_node_or_null("SkyLife")
	ck("gokyuzu dugumu var", sky != null, "")
	if sky == null:
		_finish()
		return

	var clouds := _on_screen(cam, sky, false)
	print("  [olcum] viewport %s pencere %s kamera %s fov %.1f" % [cam.get_viewport().get_visible_rect().size,
		get_window().size, cam.global_position, cam.fov])
	var shown := 0
	for any2: Variant in sky.get_children():
		var mi2 := any2 as MeshInstance3D
		if mi2 != null and shown < 4:
			shown += 1
			print("  [olcum] bulut %s -> %s arkada=%s" % [mi2.global_position, cam.unproject_position(mi2.global_position),
				cam.is_position_behind(mi2.global_position)])
	ck("bulutlarin cogu ekranda", clouds[1] * 2 >= clouds[0],
		"%d / %d" % [clouds[1], clouds[0]])
	ck("bulut var", clouds[0] > 0, "0 bulut")

	var flocks := sky.find_children("Birds", "", true, false)
	ck("kuslar var", flocks.size() > 0, "")
	if flocks.size() > 0:
		var birds := _on_screen(cam, flocks[0] as Node, true)
		ck("kuslarin cogu ekranda", birds[1] * 2 >= birds[0],
			"%d / %d" % [birds[1], birds[0]])
	# Cheap, and it has to stay cheap: the hub was cut from 752 draws to 226.
	var extra := sky.find_children("*", "MeshInstance3D", true, false).size()
	ck("gokyuzu ucuz kaliyor", extra <= 40, "%d cizim" % extra)
	_finish()


## [total, on screen] for the MeshInstance3Ds under `root`.
func _on_screen(cam: Camera3D, root: Node, deep: bool) -> Array:
	# The camera's OWN viewport, not this node's: headless reports a different
	# size for the root and the numbers come out as "nothing is on screen".
	var size := cam.get_viewport().get_visible_rect().size
	if size.x < 1.0 or size.y < 1.0:
		size = Vector2(ProjectSettings.get_setting("display/window/size/viewport_width", 1170),
			ProjectSettings.get_setting("display/window/size/viewport_height", 2532))
	var frame := Rect2(Vector2.ZERO, size)
	var total := 0
	var seen := 0
	var list: Array = root.find_children("*", "MeshInstance3D", true, false) if deep \
		else root.get_children()
	for any: Variant in list:
		var mi := any as MeshInstance3D
		if mi == null:
			continue
		total += 1
		if cam.is_position_behind(mi.global_position):
			continue
		if frame.has_point(cam.unproject_position(mi.global_position)):
			seen += 1
	return [total, seen]


func _finish() -> void:
	if _fails > 0:
		push_error("%d GOKYUZU HAYATI TESTI BASARISIZ" % _fails)
		print("--- %d GOKYUZU HAYATI TESTI BASARISIZ ---" % _fails)
	else:
		print("--- TUM GOKYUZU HAYATI TESTLERI GECTI ---")
	get_tree().quit()


func ck(label: String, passed: bool, detail: String) -> void:
	if passed:
		return
	_fails += 1
	print("  FAIL %s  %s" % [label, detail])
