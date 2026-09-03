extends Node
## G16.3: the town at the reduced grass detail, from the hub's own camera.
func _ready() -> void:
	var dio: Node3D = load("res://scenes/TownDiorama.tscn").instantiate()
	add_child(dio)
	for _i in 40:
		await get_tree().process_frame
	var cams := dio.find_children("*", "Camera3D", true, false)
	if not cams.is_empty():
		(cams[0] as Camera3D).current = true
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://out/diorama_lod.png")
	print("[cekim] out/diorama_lod.png yazildi (kamera %d)" % cams.size())
	get_tree().quit()
