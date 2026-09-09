extends TestBase
## G56 on screen: the named chip in the top bar, and the walkthrough note over
## the page it opens. Both are text over other people's art, so the only way to
## know they fit is to look.

func run() -> void:
	suite = "YONLENDIRME CEKIM"
	min_checks = 2
	await _chip()
	await _note()
	finish()


func _chip() -> void:
	var game := await open("ch01_aldridge")
	game.hud.set_scrap(128)
	game.hud.set_food(9)
	game.hud.show_wallet()
	get_tree().paused = false
	game.hud._close_pause()
	await frames(3)
	await drawn_frame()
	var shot := get_viewport().get_texture().get_image()
	var view := get_viewport().get_visible_rect().size
	var chip: Control = game.hud.find_child("WalletChip", true, false)
	var rect := chip.get_global_rect()
	ck("serit ekranin icinde", rect.end.x < view.x,
		"%.0f < %.0f" % [rect.end.x, view.x])
	# The strip, not the chip: the claim is that the chip clears the buttons
	# and the bar around it.
	shot.get_region(Rect2i(0, 0, int(view.x), 260)).save_png("res://out/wallet_chip.png")
	print("[cekim] out/wallet_chip.png yazildi (serit %.0f-%.0f)" % [rect.position.x, rect.end.x])
	close(game)
	await frames(2)


func _note() -> void:
	Guide.reset()
	var layer := CanvasLayer.new()
	add_child(layer)
	var hub := HubScreen.new()
	layer.add_child(hub)
	await frames(8)
	hub.set_diorama_active(true)
	hub.refresh()
	await settle(0.6)
	hub.run_guide_step(Guide.steps()[0])
	await settle(1.2)
	await drawn_frame()
	var view := get_viewport().get_visible_rect().size
	get_viewport().get_texture().get_image().save_png("res://out/guide_note.png")
	print("[cekim] out/guide_note.png yazildi")
	var note: Control = hub.find_child("GuideNote", true, false)
	ck("not ekranin icinde", note != null
		and note.get_global_rect().end.y <= view.y + 1.0,
		"" if note == null else "%.0f / %.0f" % [note.get_global_rect().end.y, view.y])
	Guide.reset()
	hub.queue_free()
	layer.queue_free()
	await frames(2)
