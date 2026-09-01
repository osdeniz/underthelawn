extends Control
## G14.8: the settings screen, with the light row in it.

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	SkyTime.set_mode(GameConfig.SKY_MODE_DUSK)
	var screen := SettingsScreen.new()
	add_child(screen)
	for _i in 30:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://out/settings.png")
	SkyTime.set_mode(GameConfig.SKY_MODE_AUTO)
	get_tree().quit()
