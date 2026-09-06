extends Control
## G26: the reunion card's naming page, as the player sees it, then Ellie's
## answer once a chip is pressed.

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var keep := str(GameState.get_setting("story", "dog_name", ""))
	GameState.set_setting("story", "dog_name", "")
	var card := ReunionCard.new()
	add_child(card)
	for _i in 5:
		await get_tree().process_frame
	card._page = ReunionCard.PAGE_NAME
	card._apply()
	card._fade.color.a = 0.0
	for _i in 30:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://out/dog_name_1.png")
	card._name_edit.text = "Duman"
	card._name_ok.pressed.emit()
	for _i in 30:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://out/dog_name_2.png")
	print("[cekim] out/dog_name_1.png ve out/dog_name_2.png yazildi")
	GameState.set_setting("story", "dog_name", keep)
	print("--- TUM ISIM CEKIM TESTLERI GECTI ---")
	get_tree().quit()
