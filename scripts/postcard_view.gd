class_name PostcardView
extends Control
## A saved postcard, full width over whatever is behind it (G27): the card, one
## line saying where it went, CLOSE — and on a desktop SHOW FILE, which opens
## the folder, the nearest thing to sharing without a plugin.

signal closed()

var _path := ""
var _card: TextureRect


## The card's width comes from the VIEWPORT, which a node outside the tree does
## not have (G59). Both callers built this view and called setup() on it before
## adding it, so `get_viewport_rect()` returned Rect2() on a real device — the
## engine says so in the log — and the width came out at -80: a negative
## minimum size, which Godot clamps to nothing, so the postcard was a scrim, a
## caption and a button with no picture between them. Sized here, again on
## _ready, and again whenever the viewport changes.
func _ready() -> void:
	_size_card()
	get_viewport().size_changed.connect(_size_card)


func _size_card() -> void:
	if _card == null or not is_instance_valid(_card) or not is_inside_tree():
		return
	var room := get_viewport_rect().size.x
	if room < 240.0:
		return
	var wide := minf(GameConfig.UI_MAX_WIDTH - 80.0, room - 80.0)
	_card.custom_minimum_size = Vector2(wide,
		wide * float(Postcard.CARD.y) / float(Postcard.CARD.x))
	_card.pivot_offset = _card.custom_minimum_size * 0.5


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

	_card = TextureRect.new()
	_card.texture = tex
	_card.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_card.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	# A little tilt, the way a card lies on a desk.
	_card.rotation = deg_to_rad(-1.5)
	rows.add_child(_card)
	_size_card()

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
