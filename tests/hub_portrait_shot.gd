extends TestBase
## G19 review: the hub's list page as the phone shows it, after the warm-up.
func run() -> void:
	suite = "HUB CEKIM"
	min_checks = 1
	var host := Control.new()
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(host)
	var hub := HubScreen.new()
	host.add_child(hub)
	hub.set_diorama_active(true)
	hub.refresh()
	await settle(1.5)
	await drawn_frame()
	get_viewport().get_texture().get_image().save_png("res://out/hub_portrait.png")
	print("[cekim] out/hub_portrait.png yazildi")
	ck("hub kuruldu", hub._tiles_page != null)
	hub.queue_free()
	await frames(3)
