extends TestBase
## What a dialogue backdrop is actually allowed to show (G58).
##
## A story card gets the whole screen; a conversation does not. The text panel
## covers the bottom of the frame and the portrait stands in front of the
## lower left, so most of a picture put behind a conversation is never seen.
## This renders one with a known card as its backdrop and MEASURES the surviving
## region, so the prompts for the place paintings can be written against a
## number instead of a guess.

func run() -> void:
	suite = "ZEMIN CEKIM"
	min_checks = 2
	get_window().content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	await frames(2)
	var box := DialogueBox.new()
	add_child(box)
	box.play([{"speaker": "marshal", "text": "DLG_BRIEF_CH01_1"}], "", "intro/pro_3")
	await settle(1.0)
	await drawn_frame()
	var frame := get_viewport().get_visible_rect()
	get_viewport().get_texture().get_image().get_region(
		Rect2i(Vector2i(frame.position), Vector2i(frame.size))).save_png(
		"res://out/dialogue_backdrop.png")
	print("[cekim] out/dialogue_backdrop.png yazildi")

	var view := frame.size
	var panel: Control = null
	var portrait: Control = null
	for any: Variant in box.find_children("*", "Control", true, false):
		var control := any as Control
		if control is PanelContainer:
			panel = control
		elif control is Panel and control.get_child_count() > 0:
			portrait = control
	ck("metin paneli bulundu", panel != null, "")
	ck("portre cercevesi bulundu", portrait != null, "")
	if panel == null or portrait == null:
		box.queue_free()
		return
	var panel_top := panel.get_global_rect().position.y / view.y
	var por := portrait.get_global_rect()
	print("[olcum] metin paneli ust kenari: ekranin %%%.0f'i" % (panel_top * 100.0))
	print("[olcum] portre: x %%%.0f-%%%.0f, y %%%.0f-%%%.0f" % [
		por.position.x / view.x * 100.0, por.end.x / view.x * 100.0,
		por.position.y / view.y * 100.0, por.end.y / view.y * 100.0])
	print("[olcum] zeminin gorunen kismi: ustten %%%.0f tam genislik, artinda saginda %%%.0f-%%100 seridi" % [
		por.position.y / view.y * 100.0, por.end.x / view.x * 100.0])
	# The claim the prompts rest on: the picture's own bottom half is furniture.
	ck("panel ekranin alt ucte birini kaplar", panel_top >= 0.65 and panel_top <= 0.75,
		"%.2f" % panel_top)
	ck("portre alt solda durur",
		por.position.x / view.x < 0.10 and por.end.x / view.x < 0.60
		and por.position.y / view.y > 0.30,
		"%.2f %.2f %.2f" % [por.position.x / view.x, por.end.x / view.x,
			por.position.y / view.y])
	box.queue_free()
	await frames(2)
