extends Control
## G13.5: the two map layers, and every pin state in one frame.

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ChapterProgress.reset()
	# A run in progress: three places searched, one of them with evidence left
	# behind, so the map shows done / missed / next / locked at once.
	var order: Array = GameConfig.MAP_PLACES.keys()
	ChapterProgress.record(str(order[0]), 2, 2)
	ChapterProgress.record(str(order[1]), 1, 2)
	ChapterProgress.record(str(order[2]), 2, 2)
	for id: String in ["station", "homes", "clinic", "lantern"]:
		GameState.set_setting("restore", id, true)

	var map := TownMap.new()
	map.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(map)
	for _i in 20:
		await get_tree().process_frame
	await _shoot("map_world")

	map.show_layer(TownMap.Layer.TOWN, false)
	map.refresh()
	for _i in 20:
		await get_tree().process_frame
	await _shoot("map_town")

	# The panel for the next place.
	map.focus_place(str(order[3]))
	for _i in 25:
		await get_tree().process_frame
	await _shoot("map_panel")
	ChapterProgress.reset()
	get_tree().quit()


func _shoot(label: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://out/%s.png" % label)
