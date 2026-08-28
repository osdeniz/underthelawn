extends Node
## G13.5: every project photographed ruined and restored, from a camera that
## frames just that plot — the brief's deliverable.

func _ready() -> void:
	var town: TownDiorama = load("res://scenes/TownDiorama.tscn").instantiate()
	add_child(town)
	await get_tree().process_frame
	# _life() re-places the camera every frame from _cam_base, so it has to be
	# off or every shot below comes out at the hub framing.
	town.set_process(false)
	for chapter: Dictionary in Story.list("chapters"):
		ChapterProgress.record(str(chapter.get("variant_id", "")), 3, 3)
	# Nothing built: the plate of ruins.
	for id: String in GameConfig.DIORAMA_BUILDINGS:
		GameState.set_setting("restore", id, false)
		town.set_built(id, false, false)
	town.refresh_figures()
	for _i in 20:
		await get_tree().process_frame

	for id: String in GameConfig.DIORAMA_BUILDINGS:
		await _frame(town, id)
		await _shoot("p_%s_0ruin" % id)
		GameState.set_setting("restore", id, true)
		town.set_built(id, true, false)
		town.refresh_figures()
		for _i in 8:
			await get_tree().process_frame
		await _shoot("p_%s_1built" % id)
	# The hero shot: the whole town, everything standing.
	# Tighter than the hub framing: the hub leaves room for its cards, a hero
	# shot should not.
	town.camera.v_offset = 0.0
	# In front of the town, not in front of the PLATE: the buildings sit in the
	# back half, so framing the plate centred fills a third of the shot with
	# empty grass.
	town.camera.position = Vector3(0.0, 23.0, 23.0)
	town.camera.look_at(Vector3(0.0, 2.2, -5.5))
	for _i in 40:
		await get_tree().process_frame
	await _shoot("p_hero")
	get_tree().quit()


## Puts the camera on one plot, along the diorama's own view line.
func _frame(town: TownDiorama, id: String) -> void:
	var at: Vector3 = GameConfig.DIORAMA_BUILDINGS[id]["pos"]
	var focus := at + Vector3(0.0, 1.6, 0.0)
	var dir := (GameConfig.DIORAMA_CAM_POS - GameConfig.DIORAMA_CAM_LOOK).normalized()
	town.camera.v_offset = 0.0
	town.camera.position = focus + dir * 11.0
	town.camera.look_at(focus)
	for _i in 4:
		await get_tree().process_frame


func _shoot(label: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://out/%s.png" % label)
