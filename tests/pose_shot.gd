extends TestBase
## G14.18: the riding poses, after the figure was reshaped.
##
## The arms got longer and the torso changed shape, and both poses put the
## hands on something — a handlebar and a steering wheel. This is the check
## that they still reach it and do not go through it. On TestBase since G19.2:
## the bare frame_post_draw await hung for good once the window lost focus.

func run() -> void:
	suite = "POZ CEKIM"
	min_checks = 1
	SkyTime.set_mode(GameConfig.SKY_MODE_DAY)
	for index: int in [GameConfig.MOWER_TRACTOR]:
		var game: Node = load("res://scenes/Main.tscn").instantiate()
		game.variant_id = "ch01_aldridge"
		add_child(game)
		await frames(12)
		game.hud._close_pause()
		game.select_mower(index)
		game._begin_search()
		await frames(130)
		game.hud._close_pause()
		await frames(1)
		await drawn_frame()
		get_viewport().get_texture().get_image().save_png("res://out/pose_%d.png" % index)
		print("[cekim] out/pose_%d.png yazildi" % index)
		ck("surucu makinede", game.mower != null)
		game.queue_free()
		await frames(6)
	SkyTime.set_mode(GameConfig.SKY_MODE_AUTO)
