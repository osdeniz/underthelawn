extends Node
## G14.25: the animals at the size the PLAYER sees them, placed by the GAME's
## own rule — a reference shot at a metre and a half proves nothing about a
## thirty-pixel rabbit on a mown edge behind a mower.

func _ready() -> void:
	GameState.set_setting("meta", "orientation_done", true)
	# The pickup tips and the evidence card would fill the frame. They are not
	# what this shot is looking at.
	for key: String in ["money", "food"]:
		GameState.set_setting("tips", key, true)
	var game: Node = load("res://scenes/Main.tscn").instantiate()
	game.variant_id = "ch01_aldridge"
	add_child(game)
	for _i in 8:
		await get_tree().process_frame
	get_tree().paused = false
	game.hud._close_pause()
	game._begin_search()
	for _i in 14:
		get_tree().paused = false
		await get_tree().process_frame

	# A mown strip in front of the machine, leaving long grass either side, so
	# there is a real EDGE for a rabbit to come out onto.
	# Through BOTH halves of a cut. Calling model.mow alone leaves the grass
	# mesh standing: the first two attempts at this shot did exactly that, and
	# showed a rabbit correctly placed on a "cut" cell with 0.9 units of tuft
	# still drawn over the top of it. The shot was lying, not the placement.
	for row in range(8, 22):
		for col in range(3, 13):
			if game.model.is_mowable(col, row):
				game.model.mow(col, row, 0)
	# refresh_all, not cut_cell per cell: cut_cell starts a topple ANIMATION
	# that has to be ticked, and refresh_all just brings every tuft into line
	# with the model. Two earlier attempts at this shot skipped this entirely
	# and rendered a rabbit correctly placed on a "cut" cell with 0.9 units of
	# grass still standing over it. The shot was lying, not the placement.
	game.lawn.tuft_field.refresh_all()
	print("  [tani] bicilme orani=%.3f" % game.model.completion_ratio())
	for _i in 14:
		get_tree().paused = false
		await get_tree().process_frame

	# Placed by the game's own rule, not by hand: that is the point of this one.
	var animals := game._animals as Animals
	for entry: Dictionary in animals._entries:
		entry["timer"] = 0.0
		entry["settle"] = 0.0
	for _i in 24:
		get_tree().paused = false
		await get_tree().process_frame
	animals.set_process(false)
	(game.get_node("UI") as CanvasLayer).visible = false
	for entry: Dictionary in animals._entries:
		var node := entry["node"] as Node3D
		if not node.visible:
			continue
		var c := LawnModel.cell_at(node.position)
		print("  [yer] %s durum=%d hucre=%s bicilmis=%s konum=%s" % [node.name,
			int(entry["state"]), c,
			game.model.is_cut(c.x, c.y) if int(entry["kind"]) != Animals.Kind.DOG else "-",
			node.position])

	# The game's chase camera is behind the MOWER, and the mown edge a rabbit
	# picks can be anywhere on the yard. So the shot uses the push mower's own
	# offsets (5.0 back, 4.2 up, 2.2 look-ahead) aimed at the rabbit instead:
	# same distance, same field of view, same pixels on the animal.
	var subject := Vector3(0.0, 0.0, 0.0)
	for entry: Dictionary in animals._entries:
		var node := entry["node"] as Node3D
		if int(entry["kind"]) == Animals.Kind.RABBIT and node.visible:
			subject = node.position
			break
	var offsets: Vector3 = GameConfig.MOWER_CAMERA[GameConfig.MOWER_PUSH]
	var shot := Camera3D.new()
	shot.fov = GameConfig.CAMERA_FOV
	shot.keep_aspect = Camera3D.KEEP_WIDTH
	shot.position = subject + Vector3(0.0, offsets.y, offsets.x)
	shot.current = true
	game.add_child(shot)
	shot.look_at(subject + Vector3(0.0, 0.25, -offsets.z * 0.35))
	for _i in 10:
		get_tree().paused = false
		await get_tree().process_frame
	# Where everything landed in THIS camera, so the crop check can look at the
	# right pixels rather than at wherever the chase camera happened to point.
	for entry: Dictionary in animals._entries:
		var node := entry["node"] as Node3D
		if node.visible:
			print("  [kare] %s %s" % [node.name,
				shot.unproject_position(node.global_position)])
	print("  [kare] gorunum %s" % get_viewport().get_visible_rect().size)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://out/animals_yard.png")
	print("[cekim] out/animals_yard.png yazildi")
	get_tree().quit()
