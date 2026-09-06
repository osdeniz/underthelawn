class_name PostcardView
extends Control
## A saved postcard, full width over whatever is behind it (G27): the card, one
## line saying where it went, CLOSE — and on a desktop SHOW FILE, which opens
## the folder, the nearest thing to sharing without a plugin.

signal closed()

var _path := ""


func setup(tex: Texture2D, path: String) -> void:
	_path = path
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var scrim := ColorRect.new()
	scrim.color = Color(0, 0, 0, 0.82)
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(scrim)

	var rows := VBoxContainer.new()
	rows.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	rows.grow_horizontal = Control.GROW_DIRECTION_BOTH
	rows.grow_vertical = Control.GROW_DIRECTION_BOTH
	rows.add_theme_constant_override("separation", GameConfig.UI_GAP_WIDE)
	rows.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(rows)

	var card := TextureRect.new()
	card.texture = tex
	card.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	card.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var wide := minf(GameConfig.UI_MAX_WIDTH - 80.0, get_viewport_rect().size.x - 80.0)
	card.custom_minimum_size = Vector2(wide, wide * float(Postcard.CARD.y) / float(Postcard.CARD.x))
	# A little tilt, the way a card lies on a desk.
	card.pivot_offset = card.custom_minimum_size * 0.5
	card.rotation = deg_to_rad(-1.5)
	rows.add_child(card)

	var note := Label.new()
	note.text = tr("POSTCARD_SAVED")
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.add_theme_font_size_override("font_size", GameConfig.UI_BODY)
	note.add_theme_color_override("font_color", GameConfig.UI_INK_SOFT)
	rows.add_child(note)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", GameConfig.UI_GAP)
	rows.add_child(buttons)
	if not OS.has_feature("mobile"):
		var folder := Button.new()
		folder.text = tr("POSTCARD_SHOW_FOLDER")
		folder.custom_minimum_size = Vector2(300, GameConfig.UI_TAP_MIN)
		folder.add_theme_font_size_override("font_size", GameConfig.UI_BODY)
		folder.pressed.connect(func() -> void:
			OS.shell_show_in_file_manager(ProjectSettings.globalize_path(_path), true))
		buttons.add_child(folder)
	var close := Button.new()
	close.name = "PostcardClose"
	close.text = tr("POSTCARD_CLOSE")
	close.custom_minimum_size = Vector2(300, GameConfig.UI_TAP_MIN)
	close.add_theme_font_size_override("font_size", GameConfig.UI_BODY)
	close.pressed.connect(_close)
	buttons.add_child(close)


func _gui_input(event: InputEvent) -> void:
	var pressed := event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed
	var clicked := event is InputEventMouseButton and (event as InputEventMouseButton).pressed
	if pressed or clicked:
		accept_event()
		_close()


func _close() -> void:
	closed.emit()
	queue_free()
