extends Node
## G13.4: the weed band at 0 chapters and at 8, plus a frame mid-retreat.

func _ready() -> void:
	ChapterProgress.reset()
	var town: TownDiorama = load("res://scenes/TownDiorama.tscn").instantiate()
	add_child(town)
	await get_tree().process_frame
	town.set_process(false)
	town.camera.v_offset = 0.0
	town.camera.position = Vector3(0.0, 23.0, 23.0)
	town.camera.look_at(Vector3(0.0, 2.2, -5.5))
	for _i in 20:
		await get_tree().process_frame
	await _shoot("reclaim_0")

	# Finish two chapters, then watch the band step back.
	var chapters: Array = Story.list("chapters")
	for i in 2:
		ChapterProgress.record(str((chapters[i] as Dictionary).get("variant_id", "")), 3, 3)
	town.set_process(true)
	town.play_reclaim_step.call()
	await get_tree().create_timer(0.7).timeout
	town.set_process(false)
	town.camera.position = Vector3(0.0, 23.0, 23.0)
	town.camera.look_at(Vector3(0.0, 2.2, -5.5))
	await _shoot("reclaim_mid")
	await get_tree().create_timer(1.2).timeout

	for chapter: Dictionary in chapters:
		ChapterProgress.record(str(chapter.get("variant_id", "")), 3, 3)
	town._write_reclaim()
	town.set_process(false)
	town.camera.position = Vector3(0.0, 23.0, 23.0)
	town.camera.look_at(Vector3(0.0, 2.2, -5.5))
	for _i in 6:
		await get_tree().process_frame
	await _shoot("reclaim_8")
	ChapterProgress.reset()
	get_tree().quit()


func _shoot(label: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://out/%s.png" % label)
