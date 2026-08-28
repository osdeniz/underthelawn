extends Control
## G14.2: the objectives screen with conditions half met, and the toast.

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	GameState.set_setting("meta", "orientation_done", true)
	ChapterProgress.reset()
	RestoreBoard.reset()
	Objectives.reset()
	GameState.set_setting("harvest", "runs", 0)
	GameState.set_setting("harvest", "since_chapter", 0)
	# Half done on purpose: three chapters in, the farm rebuilt, no tractor —
	# the screen has to make the missing piece obvious.
	var chapters: Array = Story.list("chapters")
	for i in 3:
		ChapterProgress.record(str((chapters[i] as Dictionary).get("variant_id", "")), 2, 2)
	GameState.set_setting("restore", "farm", true)
	GameState.set_setting("restore", "station", true)
	GameState.set_setting("garage", "tractor_unlocked", false)

	var hub := HubScreen.new()
	add_child(hub)
	for _i in 24:
		await get_tree().process_frame
	hub.refresh()
	for _i in 12:
		await get_tree().process_frame
	hub._show_page(hub._objectives_page)
	# The page fades in; ten frames catches it half transparent.
	for _i in 70:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://out/objectives.png")

	# Now the completion moment, on the town objective.
	GameState.set_setting("restore", "homes", true)
	GameState.set_setting("restore", "clinic", true)
	hub._show_page(hub._tiles_page)
	# Let the page change finish, or the shot catches two screens at once.
	for _i in 70:
		await get_tree().process_frame
	hub._announce_objectives(Objectives.collect())
	for _i in 40:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://out/objective_toast.png")

	ChapterProgress.reset()
	RestoreBoard.reset()
	Objectives.reset()
	get_tree().quit()
