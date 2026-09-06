extends TestBase
## G21: the lake from the player's camera, a strip cut so the clear water shows.
func run() -> void:
	suite = "GOL CEKIM"
	min_checks = 1
	SkyTime.set_mode(GameConfig.SKY_MODE_DAY)
	var game: Node = await open("ch04_flooded")
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
	get_viewport().get_texture().get_image().save_png("res://out/lake.png")
	print("[cekim] out/lake.png yazildi")
	ck("gol kuruldu", game.variant.is_lake())
	SkyTime.set_mode(GameConfig.SKY_MODE_AUTO)
	await close(game)
