extends TestBase
## G19.6: Case 03's two new places from the player's low camera.

const SHOTS := {"ch24_the_gate_line": "gate_line", "ch26_the_visit": "square_tables",
	"ch04_flooded": "jetty", "ch27_the_reed_shore": "sunken_boat", "ch10_relay_hill": "relay"}

func run() -> void:
	suite = "YER CEKIM"
	min_checks = 1
	for id: String in SHOTS:
		var game: Node = await open(id)
		(game.get_node("UI") as CanvasLayer).visible = false
		var eye := Camera3D.new()
		eye.fov = GameConfig.CAMERA_FOV
		eye.keep_aspect = Camera3D.KEEP_WIDTH
		game.add_child(eye)
		eye.position = Vector3(0.0, 3.6, -GameConfig.HALF_Z + 7.5)
		eye.look_at(Vector3(0.0, 1.2, GameConfig.house_pos_z() + 1.6))
		await frames(6)
		get_tree().paused = false
		game.hud._close_pause()
		if game.cam != null:
			game.cam.current = false
		eye.current = true
		await frames(2)
		await drawn_frame()
		get_viewport().get_texture().get_image().save_png("res://out/landmark_%s.png" % SHOTS[id])
		print("[cekim] out/landmark_%s.png yazildi" % SHOTS[id])
		ck("%s landmark kuruldu" % id, game.find_child("Landmark_" + SHOTS[id], true, false) != null)
		await close(game)
