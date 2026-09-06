extends TestBase
## G19.3: the five yard shapes from above, so the props built on the blocks
## can be judged against the model's idea of them.

const SHOTS := ["ch09_radio_room", "ch19_town_square", "ch21_school_field",
	"ch25_night_watch", "ch11_orchard"]

func run() -> void:
	suite = "SEKIL CEKIM"
	min_checks = 1
	SkyTime.set_mode(GameConfig.SKY_MODE_DAY)
	for id: String in SHOTS:
		var game: Node = await open(id)
		(game.get_node("UI") as CanvasLayer).visible = false
		var above := Camera3D.new()
		above.fov = 52.0
		above.keep_aspect = Camera3D.KEEP_WIDTH
		above.position = Vector3(0.0, GameConfig.HALF_Z * 2.6, 3.0)
		game.add_child(above)
		above.look_at(Vector3(0.0, 0.0, 0.5))
		game.hud._close_pause()
		if game.cam != null:
			game.cam.current = false
		above.current = true
		await frames(6)
		await drawn_frame()
		get_viewport().get_texture().get_image().save_png("res://out/shape_%s.png" % id)
		print("[cekim] out/shape_%s.png yazildi" % id)
		ck("%s kuruldu" % id, game.model != null)
		await close(game)
	SkyTime.set_mode(GameConfig.SKY_MODE_AUTO)
