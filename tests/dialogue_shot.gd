extends Control
## G14.23: the dialogue box, after the portrait and the bubble grew.

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var ground := ColorRect.new()
	ground.color = Color(0.16, 0.24, 0.14)
	ground.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(ground)
	var box := DialogueBox.new()
	add_child(box)
	box.play(Dialogue.conversation("brief_ch01"),
		Dialogue.accept_key("brief_ch01"))
	for _i in 120:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://out/dialogue.png")
	get_tree().quit()
