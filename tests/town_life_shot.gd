extends Node
## G14.6: the rebuilt town at night — smoke, windows, far houses.
##
## Shot from the diorama scene directly, NOT through the hub: the hub parks its
## town behind a captured still to save the framebuffer, and that still is what
## a hub-side shot photographs.

func _ready() -> void:
	GameState.set_setting("meta", "orientation_done", true)
	for id: String in GameConfig.DIORAMA_BUILDINGS:
		GameState.set_setting("restore", id, true)
	SkyTime.set_mode(GameConfig.SKY_MODE_NIGHT)
	var town: TownDiorama = load("res://scenes/TownDiorama.tscn").instantiate()
	add_child(town)
	for _i in 20:
		await get_tree().process_frame
	for id2: String in GameConfig.DIORAMA_BUILDINGS:
		town.set_built(id2, true, false)
	town.apply_sky_mode()
	for _i in 90:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://out/town_night.png")
	RestoreBoard.reset()
	SkyTime.set_mode(GameConfig.SKY_MODE_AUTO)
	get_tree().quit()
