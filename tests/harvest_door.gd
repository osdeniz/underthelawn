extends Control
## G13.6: with the invitation open, the hub must show its own door to the field.

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Shoot at the shipping viewport. The camera keeps its WIDTH, so a wider
	# test window shows LESS sky than the phone and every framing judgement
	# made from it is wrong (G14.2).
	get_window().size = Vector2i(1170, 2532)
	get_window().content_scale_size = Vector2i(1170, 2532)
	GameState.set_setting("meta", "orientation_done", true)
	GameState.set_setting("harvest", "runs", 0)
	GameState.set_setting("harvest", "since_chapter", 0)
	GameState.set_setting("restore", "farm", true)
	GameState.set_setting("garage", "tractor_unlocked", true)
	ChapterProgress.reset()
	var chapters: Array = Story.list("chapters")
	for i in GameConfig.HARVEST_EVERY:
		ChapterProgress.record(str((chapters[i] as Dictionary).get("variant_id", "")), 2, 2)
	print("offered: ", HarvestLog.is_offered())
	var hub := HubScreen.new()
	add_child(hub)
	for _i in 30:
		await get_tree().process_frame
	hub.refresh()
	for _i in 60:
		await get_tree().process_frame
	print("tile var mi: ", hub.find_children("HarvestTile", "", true, false).size())
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://out/harvest_door.png")
	ChapterProgress.reset()
	GameState.set_setting("restore", "farm", false)
	get_tree().quit()
