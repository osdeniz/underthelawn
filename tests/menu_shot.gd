extends Control
## The main menu at the phone's size (G35): the cover keeps its title.
##
## It did not actually check that. The capture was the whole desktop viewport,
## which is landscape, so the one thing the shot exists to prove — that a 4:5
## cover covering a 0.46 screen does not lose its lettering off the sides —
## was never in the picture (G58). Letterboxed to the phone's exact frame now,
## the way Legibility and PrologueShot do it.

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	get_window().content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	var menu := MainMenu.new()
	add_child(menu)
	for _i in 30:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var frame := get_viewport().get_visible_rect()
	get_viewport().get_texture().get_image().get_region(
		Rect2i(Vector2i(frame.position), Vector2i(frame.size))).save_png(
		"res://out/menu_phone.png")
	print("[cekim] out/menu_phone.png yazildi (%dx%d)" % [frame.size.x, frame.size.y])
	get_tree().quit()
