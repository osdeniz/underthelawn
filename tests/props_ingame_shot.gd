extends TestBase
## G14.12 / G19.1: the props at the distance a player actually sees them. A
## patch in front of the machine is cut and six pieces of salvage plus a crate
## are laid on it, so all three salvage shapes show at play distance.

func run() -> void:
	suite = "PROP CEKIM"
	min_checks = 1
	TownStats.reset()
	SkyTime.set_mode(GameConfig.SKY_MODE_DAY)
	var game: Node = await open("ch01_aldridge")
	var model: LawnModel = game.model
	var host: Node3D = game.get_node("ScrapField")
	var spots: Array[Vector3] = [Vector3(-2.4, 0.0, 4.6), Vector3(-0.6, 0.0, 4.2),
		Vector3(1.3, 0.0, 4.7), Vector3(-1.6, 0.0, 6.0), Vector3(0.4, 0.0, 6.3),
		Vector3(2.5, 0.0, 6.1)]
	var tufts: TuftField = game.lawn.tuft_field
	for c in range(-4, 5):
		for r in range(2, 9):
			var cell := LawnModel.cell_at(Vector3(float(c), 0.0, float(r)))
			if model.is_mowable(cell.x, cell.y):
				model.mow(cell.x, cell.y, 0)
				if tufts != null:
					tufts.cut_cell(cell.x, cell.y, 0.0)
	var props: Array[Node3D] = []
	for s in spots:
		var cell := LawnModel.cell_at(s)
		var p := SalvageProp.spawn(host, LawnModel.cell_center(cell.x, cell.y))
		p.reveal()
		props.append(p)
	var food_cell := LawnModel.cell_at(Vector3(3.2, 0.0, 4.4))
	FoodProp.spawn(host, LawnModel.cell_center(food_cell.x, food_cell.y)).reveal()
	await settle(0.8)
	# The headless window has no focus, so the game re-opens its pause sheet
	# behind our back; close it right before the capture.
	get_tree().paused = false
	game.hud._close_pause()
	await frames(2)
	await drawn_frame()
	get_viewport().get_texture().get_image().save_png("res://out/props_game.png")
	print("[cekim] out/props_game.png yazildi")
	ck("hurda yer seviyesinde", absf(props[0].position.y - GameConfig.PROP_GROUND_Y) < 0.02,
		"%.2f" % props[0].position.y)
	SkyTime.set_mode(GameConfig.SKY_MODE_AUTO)
	await close(game)
