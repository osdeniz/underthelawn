extends Control
## G14.1: the reunion card's middle beat — the party that was waiting for her.

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var card := ReunionCard.new()
	add_child(card)
	for _i in 20:
		await get_tree().process_frame
	# Straight to the celebration page, without waiting out two taps.
	card._page = 1
	card._apply()
	card._fade.color.a = 0.0
	for _i in 20:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://out/birthday.png")
	get_tree().quit()
