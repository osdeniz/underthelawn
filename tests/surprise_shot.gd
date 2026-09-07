extends TestBase
## G29: the kite, the ball and the cloud shadow over ch01; the lit window on
## ch07 at dusk (a derelict neighbour: no evening chapter has the main house).

func run() -> void:
	suite = "SURPRIZ CEKIM"
	min_checks = 2
	var game := await open("ch01_aldridge")
	await settle(1.2)
	for row in GameConfig.GRID_ROWS:
		for col in GameConfig.GRID_COLS:
			if row < GameConfig.GRID_ROWS / 2 and game.model.is_mowable(col, row):
				game.model.mow(col, row, 0)
				if game.lawn.tuft_field != null:
					game.lawn.tuft_field.cut_cell(col, row, 0.0)
	var s: Surprises = game._surprises
	ck("surprizler var", s != null, "")
	if s != null:
		s.force(Surprises.KITE)
		s.force(Surprises.BALL)
		s.force(Surprises.CLOUD)
		s.force(Surprises.BUTTERFLIES)
	# Half the kite's crossing: it is over the yard, not still beyond the fence.
	await settle(GameConfig.SURPRISE_KITE_SECONDS * 0.5)
	await shot("out/surprise_ch01.png")
	close(game)
	var dusk := await open("ch07_mill")
	await settle(1.2)
	var s2: Surprises = dusk._surprises
	ck("gun batiminda pencere yakilir", s2 != null and s2.force(Surprises.WINDOW), "")
	await settle(2.5)
	await shot("out/surprise_ch07_window.png")
	close(dusk)
	finish()


func shot(path: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://" + path)
	print("[cekim] %s yazildi" % path)
