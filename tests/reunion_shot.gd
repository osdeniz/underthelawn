extends Control
## G14.10: the closing card's Case 2 page, with the door actually open.

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for chapter_any: Variant in Story.list("chapters"):
		ChapterProgress.record(
			str((chapter_any as Dictionary).get("variant_id", "")), 2, 2)
	for project_any: Variant in RestoreBoard.projects():
		GameState.set_setting("restore",
			str((project_any as Dictionary).get("id", "")), true)
	var card := ReunionCard.new()
	add_child(card)
	for _i in 20:
		await get_tree().process_frame
	card._page = 2
	card._apply()
	card._fade.color.a = 0.0
	for _i in 20:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://out/case2_card.png")
	ChapterProgress.reset()
	RestoreBoard.reset()
	get_tree().quit()
