extends Node
## G13: the diorama, both states side by side in time — ruined first, then all
## three buildings restored. Meant to be looked at.

func _ready() -> void:
	var town: TownDiorama = load("res://scenes/TownDiorama.tscn").instantiate()
	add_child(town)
	await get_tree().process_frame
	var restored := str(OS.get_environment("UTL_RESTORED")) == "1"
	for id: String in GameConfig.DIORAMA_BUILDINGS:
		town.set_built(id, restored, false)
	if restored:
		# Figures only appear once their project is built; the shot wants them.
		for chapter: Dictionary in Story.list("chapters"):
			ChapterProgress.record(str(chapter.get("variant_id", "")), 3, 3)
		for id2: String in GameConfig.DIORAMA_BUILDINGS:
			GameState.set_setting("restore", id2, true)
		town.refresh_figures()
	for _i in 40:
		await get_tree().process_frame
	await get_tree().process_frame
	for node in town.get_children():
		var n3 := node as Node3D
		if n3 == null: continue
		print('%-16s pos=%v vis=%s cocuk=%d' % [n3.name, n3.global_position,
			str(n3.is_visible_in_tree()), n3.get_child_count()])
	var vis := 0
	for m in town.find_children('*', 'MeshInstance3D', true, false):
		if (m as MeshInstance3D).is_visible_in_tree(): vis += 1
	print('gorunur mesh: %d' % vis)
