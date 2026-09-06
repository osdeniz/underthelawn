extends TestBase
## G27: a card from ch01 (midday, green) and one from ch06 (the big grid), so
## the camera's framing can be read rather than assumed.

func run() -> void:
	suite = "KARTPOSTAL CEKIM"
	min_checks = 2
	for vid in ["ch01_aldridge", "ch06_watertower"]:
		var game := await open(vid)
		await settle(1.2)
		for row in GameConfig.GRID_ROWS:
			for col in GameConfig.GRID_COLS:
				if game.model.is_mowable(col, row) and not game.model.is_cut(col, row):
					game.model.mow(col, row, 0)
					if game.lawn.tuft_field != null:
						game.lawn.tuft_field.cut_cell(col, row, 0.0)
		await frames(3)
		var saved: String = await Postcard.make(game, vid, game._postcard_subtitle())
		ck("kart var: %s" % vid, saved != "", saved)
		if saved != "":
			var img := Image.load_from_file(ProjectSettings.globalize_path(saved))
			img.save_png("res://out/postcard_%s.png" % vid)
			print("[cekim] out/postcard_%s.png yazildi" % vid)
		close(game)
	finish()
