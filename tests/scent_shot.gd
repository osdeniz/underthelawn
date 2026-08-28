extends Node
## G13.4: the radio line and the faint ground tint around a find.

func _ready() -> void:
	GameConfig.hint_moments = true
	var game: Node = load("res://scenes/Main.tscn").instantiate()
	add_child(game)
	for _i in 20:
		await get_tree().process_frame
	var model = game.model
	# Mow up to the first scent threshold.
	var target := int(GameConfig.GRID_COLS * GameConfig.GRID_ROWS * 0.31)
	var done := 0
	for row in GameConfig.GRID_ROWS:
		for col in GameConfig.GRID_COLS:
			if done >= target:
				break
			if not model.is_mowable(col, row) or model.is_cut(col, row):
				continue
			model.mow(col, row, 0)
			done += 1
	game.lawn.repaint_all()
	game._check_scent(model.completion_ratio())
	for _i in 25:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://out/scent.png")
	get_tree().quit()
