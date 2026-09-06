extends TestBase
## G19.5: the lantern chapter from the player's camera.

func run() -> void:
	suite = "FENER CEKIM"
	min_checks = 1
	var game: Node = await open("ch25_night_watch")
	game.model.mow(LawnModel.cell_at(game.mower.position).x, LawnModel.cell_at(game.mower.position).y, 0)
	await settle(1.5)
	game.hud.visible = false
	get_tree().paused = false
	game.hud._close_pause()
	await frames(2)
	await drawn_frame()
	get_viewport().get_texture().get_image().save_png("res://out/lantern.png")
	print("[cekim] out/lantern.png yazildi")
	ck("fener kuruldu", game._lantern != null)
	await close(game)
