extends TestBase
## G24: the sand road from the player's camera; a strip cut, its far end already drifting back.
func run() -> void:
	suite = "KUM CEKIM"
	min_checks = 1
	SkyTime.set_mode(GameConfig.SKY_MODE_DAY)
	var game: Node = await open("ch18_long_road_home")
	var model: LawnModel = game.model
	var tufts: TuftField = game.lawn.tuft_field
	var cell := LawnModel.cell_at(game.mower.position)
	for r in range(cell.y - 12, cell.y + 1):
		for c in range(cell.x - 1, cell.x + 2):
			if model.is_mowable(c, r):
				model.mow(c, r, 0)
				tufts.cut_cell(c, r, 0.0)
	await settle(0.8)
	# The far end has been open long enough: the wind takes it.
	for key: int in game._cut_at.keys():
		game._cut_at[key] = Time.get_ticks_msec() - 60000
	game._recover_clock = 10.0
	game._tick_recover(0.6)
	await settle(0.6)
	get_tree().paused = false
	game.hud._close_pause()
	if game.cam != null and game.cam.has_method("snap_to_target"):
		game.cam.snap_to_target()
	await frames(2)
	await drawn_frame()
	get_viewport().get_texture().get_image().save_png("res://out/sand.png")
	print("[cekim] out/sand.png yazildi")
	ck("kum paleti", GameConfig.active_grass_palette == "SAND")
	SkyTime.set_mode(GameConfig.SKY_MODE_AUTO)
	await close(game)
