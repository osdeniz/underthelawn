extends Control
## G48: the discoveries tab with one piece held, and the notes with the
## deduction it produced.

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ChapterProgress.reset()
	DeductionLog.reset()
	for chapter: Dictionary in ChapterProgress.chapters():
		var vid := str(chapter.get("variant_id", ""))
		var count := LevelVariant.of(vid).evidence_count()
		ChapterProgress.record(vid, count, count)
	var journal := JournalScreen.new()
	add_child(journal)
	for _i in 5:
		await get_tree().process_frame
	journal._section = JournalScreen.Section.DISCOVERIES
	journal._refresh()
	for _i in 10:
		await get_tree().process_frame
	var links: Array = DeductionLog.links()
	var link: Dictionary = links[0]
	var a := str(link.get("a", ""))
	var b := str(link.get("b", ""))
	var pick_a: Button = journal.find_child(DeductionLog.node_name(a), true, false)
	if pick_a != null:
		pick_a.pressed.emit()
	for _i in 6:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://out/deduction_pick.png")
	var pick_b: Button = journal.find_child(DeductionLog.node_name(b), true, false)
	if pick_b != null:
		pick_b.pressed.emit()
	for _i in 8:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://out/deduction_made.png")
	journal._section = JournalScreen.Section.NOTES
	journal._refresh()
	for _i in 8:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://out/deduction_notes.png")
	print("[cekim] out/deduction_pick.png, _made.png ve _notes.png yazildi")
	DeductionLog.reset()
	ChapterProgress.reset()
	get_tree().quit()
