extends Node
## G13.2: the whole purchase, exactly as a player does it — restore page, buy
## the station, watch the transition, and land back on a usable hub.

func _ready() -> void:
	GameConfig.hub_mode = GameConfig.HUB_MODE_DIORAMA
	RestoreBoard.reset()
	GameState.set_setting("economy", "scrap", 90000)
	for opener: String in ["swing", "lantern", "greenhouse"]:
		RestoreBoard.buy(opener)
	var hub := HubScreen.new()
	add_child(hub)
	await get_tree().process_frame
	hub._on_tile("restore", false, Button.new())
	for _i in 10:
		await get_tree().process_frame
	hub._on_project("station", false, Button.new())
	await get_tree().create_timer(2.2).timeout
	await _shoot("g132_mid")
	await get_tree().create_timer(4.0).timeout
	await _shoot("g132_after")
	print("[G13.2] onarildi=%s  cocuk=%d" % [str(RestoreBoard.is_built("station")),
		hub.get_child_count()])
	for child in hub.get_children():
		var c := child as Control
		if c != null and c.visible and c.modulate.a < 0.99:
			print("  SOLUK KALDI: %s a=%.2f" % [c.name, c.modulate.a])
		if c is Button and c.size.x >= hub.size.x - 1.0:
			print("  ENGEL BUTON: %s" % c.name)
	RestoreBoard.reset()
	get_tree().quit()


func _shoot(label: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://out/%s.png" % label)
