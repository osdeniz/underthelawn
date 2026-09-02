extends Control
## G14.13: the arrival card and the hub bar's food rate.

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	GameState.set_setting("meta", "orientation_done", true)
	ChapterProgress.reset()
	Settlers.reset()
	TownStats.reset()
	var chapters: Array = Story.list("chapters")
	for i in 3:
		ChapterProgress.record(str((chapters[i] as Dictionary).get("variant_id", "")), 2, 2)
	for id: String in ["swing", "lantern"]:
		GameState.set_setting("restore", id, true)
	var hub := HubScreen.new()
	add_child(hub)
	for _i in 30:
		await get_tree().process_frame
	hub.refresh()
	for _i in 40:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://out/settler.png")
	ChapterProgress.reset()
	Settlers.reset()
	RestoreBoard.reset()
	get_tree().quit()
