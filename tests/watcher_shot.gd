extends TestBase
## G50: the neighbours at the fence, from the play camera and from above.

func run() -> void:
	suite = "IZLEYICI CEKIM"
	min_checks = 2
	var kept := {}
	for id in [MowPattern.ROWS, MowPattern.RINGS, MowPattern.CROSS]:
		kept[id] = MowPattern.count(id)
		GameState.set_setting(MowPattern.SECTION, id, 0)
	# Enough patterned yards for a full row of them.
	for i in 6:
		MowPattern.record(MowPattern.RINGS)
	var game := await open("ch01_aldridge")
	await settle(1.2)
	var root: Node3D = game.find_child("Watchers", true, false)
	ck("izleyiciler kuruldu", root != null and root.get_child_count() >= 2,
		"" if root == null else str(root.get_child_count()))
	# Stand the machine near them so the play camera holds the fence.
	var who := root.get_child(0) as Node3D
	game.mower.position = Vector3(signf(who.position.x) * (GameConfig.HALF_X - 1.5),
		game.mower.position.y, who.position.z)
	game.mower.yaw = PI * 0.5 * signf(who.position.x)
	game.cam.snap_to_target()
	await settle(1.0)
	# TestBase's own bounded wait, not a bare `await frame_post_draw`: that
	# signal never comes when the window is not drawing (occluded, or another
	# app in front), and this shot hung for thirteen minutes on it.
	await drawn_frame()
	get_viewport().get_texture().get_image().save_png("res://out/watchers.png")
	ck("kare alindi", true, "")
	print("[cekim] out/watchers.png yazildi")
	close(game)
	for id in [MowPattern.ROWS, MowPattern.RINGS, MowPattern.CROSS]:
		GameState.set_setting(MowPattern.SECTION, id, kept[id])
	finish()
