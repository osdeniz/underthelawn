extends Control
## The main menu at the phone's size (G35): the cover keeps its title.

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var menu := MainMenu.new()
	add_child(menu)
	for _i in 30:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://out/menu_phone.png")
	print("[cekim] out/menu_phone.png yazildi")
	get_tree().quit()
