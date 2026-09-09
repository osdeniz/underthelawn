extends TestBase
## G47: photo mode as the player sees it, and the card its shutter makes.

func run() -> void:
	suite = "FOTOGRAF CEKIM"
	min_checks = 2
	var game := await open("ch01_aldridge")
	await settle(1.0)
	# A lane through the middle, so the picture has something in it.
	var mid := LawnModel.cell_at(Vector3.ZERO)
	for row in range(mid.y - 6, mid.y + 7):
		for col in range(mid.x - 3, mid.x + 4):
			if LawnModel.in_bounds(col, row) and game.model.is_mowable(col, row):
				game.model.mow(col, row, 1)
				if game.lawn.tuft_field != null:
					game.lawn.tuft_field.cut_cell(col, row, 0.0)
	var mode := PhotoMode.open(game, game.hud)
	await frames(4)
	mode.swing(Vector2(-260.0, 90.0))
	mode._set_zoom(0.8)
	await settle(0.8)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://out/photo_mode.png")
	ck("mod ekranda", mode != null and is_instance_valid(mode), "")
	await mode._shoot()
	await settle(0.4)
	var newest := Postcard.all()
	var made := ""
	for card: Dictionary in newest:
		if str(card["id"]).begins_with("photo_"):
			made = str(card["path"])
			break
	ck("deklansor kart uretti", made != "", str(newest.size()))
	if made != "":
		var img := Image.load_from_file(ProjectSettings.globalize_path(made))
		img.save_png("res://out/photo_card.png")
		print("[cekim] out/photo_mode.png ve out/photo_card.png yazildi")
		DirAccess.remove_absolute(ProjectSettings.globalize_path(made))
	mode.close()
	close(game)
	finish()
