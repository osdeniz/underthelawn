extends Control
## G12.10: every drawn UI icon at the size it actually renders, on both a light
## and a dark ground — these replaced emoji, so they have to read at 40 px.

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0.12, 0.13, 0.11)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var icons: Array = [
		["money", UiIcons.money()], ["evidence", UiIcons.evidence()],
		["town", UiIcons.for_tile("town")], ["restore", UiIcons.for_tile("restore")],
		["workshop", UiIcons.for_tile("workshop")],
		["echoes", UiIcons.for_tile("echoes")],
		["station", UiIcons.for_tile("station")],
		["sound on", UiIcons.sound(true)], ["sound off", UiIcons.sound(false)],
		["lock", UiIcons.lock()], ["house", UiIcons.house()],
	]
	var y := 60
	for entry: Array in icons:
		for size: int in [40, 96]:
			var rect := TextureRect.new()
			rect.texture = entry[1]
			rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			rect.position = Vector2(120 if size == 40 else 220, y)
			rect.size = Vector2(size, size)
			add_child(rect)
		var name_label := Label.new()
		name_label.text = str(entry[0])
		name_label.position = Vector2(360, y + 24)
		name_label.add_theme_font_size_override("font_size", 34)
		add_child(name_label)
		y += 120
