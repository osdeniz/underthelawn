extends Control
## G14.14: the farm sheet, where the six fields must read as six choices.

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	GameState.set_setting("meta", "orientation_done", true)
	GameState.set_setting("harvest", "runs", 0)
	GameState.set_setting("harvest", "since_chapter", 0)
	GameState.set_setting("restore", "farm", true)
	GameState.set_setting("garage", "tractor_unlocked", true)
	ChapterProgress.reset()
	var chapters: Array = Story.list("chapters")
	for i in GameConfig.HARVEST_EVERY:
		ChapterProgress.record(str((chapters[i] as Dictionary).get("variant_id", "")), 2, 2)
	var hub := HubScreen.new()
	add_child(hub)
	for _i in 16:
		await get_tree().process_frame
	hub.open_map_at(GameConfig.HARVEST_VARIANT)
	for _i in 30:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://out/fields.png")
	ChapterProgress.reset()
	RestoreBoard.reset()
	get_tree().quit()
