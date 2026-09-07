extends Control
## G33: the Journal's RECORDS tab, a few earned and the rest open.

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var keep := {}
	for id in ["first_yard", "dog_named", "rings_1"]:
		keep[id] = Achievements.earned_on(id)
		GameState.set_setting(Achievements.SECTION, id, "2026-09-07")
	var journal := JournalScreen.new()
	add_child(journal)
	for _i in 5:
		await get_tree().process_frame
	journal._section = JournalScreen.Section.RECORDS
	journal._refresh()
	for _i in 30:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://out/records.png")
	print("[cekim] out/records.png yazildi")
	for id in keep:
		GameState.set_setting(Achievements.SECTION, id, keep[id])
	get_tree().quit()
