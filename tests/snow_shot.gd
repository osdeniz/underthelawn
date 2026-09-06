extends TestBase
## G23: the snow from the player's camera, a strip ploughed to the frozen ground.
func run() -> void:
	suite = "KAR CEKIM"
	min_checks = 1
	SkyTime.set_mode(GameConfig.SKY_MODE_DAY)
	var game: Node = await open("ch20_watchtower_road")
	var model: LawnModel = game.model
	var tufts: TuftField = game.lawn.tuft_field
	var cell := LawnModel.cell_at(game.mower.position)
	for r in range(cell.y - 7, cell.y + 1):
		for c in range(cell.x - 1, cell.x + 2):
			if model.is_mowable(c, r):
				model.mow(c, r, 0)
				tufts.cut_cell(c, r, 0.0)
	await settle(1.2)
	get_tree().paused = false
	game.hud._close_pause()
	if game.cam != null and game.cam.has_method("snap_to_target"):
		game.cam.snap_to_target()
	await frames(2)
	await drawn_frame()
	get_viewport().get_texture().get_image().save_png("res://out/snow.png")
	print("[cekim] out/snow.png yazildi")
	ck("kar paleti", GameConfig.active_grass_palette == "SNOW", GameConfig.active_grass_palette)
	ck("HUD Vaka 03 satiri", game.hud._case_line.text == Story.text("case_03.hud_line"),
		game.hud._case_line.text)
	ck("kizak var", game.mower.get_node_or_null("Body/Sled") != null)
	ck("kar yagiyor, yagmur sesi yok", Rain.is_snow() and not AudioDirector._rain.playing)
	ck("geri cekilebilir ama az", float(game.mower.params.get("reverse", 0.0)) > 0.0 and float(game.mower.params.get("reverse", 0.0)) < 0.5)
	SkyTime.set_mode(GameConfig.SKY_MODE_AUTO)
	await close(game)
