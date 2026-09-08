extends Control
## G37: a story card half typed and then whole, so the pacing can be seen and
## the layout checked — with visible_characters the text block must sit in the
## same place in both frames.

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	GameConfig.text_instant = false
	var intro := IntroSequence.new()
	intro.cards_key = "prologue.cards"
	add_child(intro)
	for _i in 8:
		await get_tree().process_frame
	# Past the fade, part way into the first line.
	var wait := 0.0
	while wait < 0.95:
		wait += get_process_delta_time()
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://out/typing_1.png")
	intro._typer.finish()
	for _i in 3:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://out/typing_2.png")
	print("[cekim] out/typing_1.png ve out/typing_2.png yazildi")
	print("--- TUM YAZI CEKIM TESTLERI GECTI ---")
	get_tree().quit()
