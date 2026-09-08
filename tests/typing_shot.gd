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
	# The skip bar, mid-hold (G40): its own capture, because a 6 px bar at the
	# bottom of a phone screen is exactly the kind of thing that lands on top
	# of the hint or under the home indicator.
	intro._hold = GameConfig.INTRO_SKIP_HOLD * 0.62
	for _i in 3:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://out/typing_3_skip.png")
	print("[cekim] out/typing_1.png, _2.png ve _3_skip.png yazildi")
	print("--- TUM YAZI CEKIM TESTLERI GECTI ---")
	get_tree().quit()
