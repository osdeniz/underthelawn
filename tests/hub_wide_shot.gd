extends TestBase
## G19.9: the hub sideways, town page live — the diorama camera's landscape framing.

func run() -> void:
	suite = "YATAY HUB CEKIM"
	min_checks = 1
	get_window().size = Vector2i(1600, 900)
	await frames(4)
	var host := Control.new()
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(host)
	var hub := HubScreen.new()
	host.add_child(hub)
	hub.set_diorama_active(true)
	hub.refresh()
	hub._on_tile("town", false)
	await settle(1.2)
	await drawn_frame()
	get_viewport().get_texture().get_image().save_png("res://out/hub_wide.png")
	print("[cekim] out/hub_wide.png yazildi")
	ck("kasaba sayfasi acik", hub._page_wants_town)
	hub.queue_free()
	await frames(3)
