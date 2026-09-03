extends Control
## The end of Case 03 (G17): two pages of narrative, then the one choice the
## game ever asks — open the gate or keep it closed. Neither button uses the
## words the design forbids; the two mornings that follow say what each meant,
## and where the dog stands is the whole answer.

signal chosen(open: bool)

const FADE := 0.4

var _page := 0
var _lines: Label
var _title: Label
var _hint: Label
var _choices: VBoxContainer
var _fade: ColorRect
var _lock := 0.0
var _done := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var ground := ColorRect.new()
	ground.color = Color(0.05, 0.06, 0.05)
	ground.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ground.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ground)

	_title = Label.new()
	_title.text = tr("GATE_TITLE")
	_title.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_title.offset_top = 380
	_title.offset_bottom = 480
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", GameConfig.fs(GameConfig.UI_HEAD + 12))
	_title.add_theme_color_override("font_color", GameConfig.CASE_ACCENT)
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_title)

	_lines = Label.new()
	_lines.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_lines.anchor_top = 0.42
	_lines.anchor_bottom = 0.66
	_lines.offset_left = 100
	_lines.offset_right = -100
	_lines.offset_top = 0
	_lines.offset_bottom = 0
	_lines.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_lines.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_lines.add_theme_font_size_override("font_size", GameConfig.fs(56))
	_lines.add_theme_color_override("font_color", Color(0.95, 0.94, 0.9))
	_lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_lines)

	_choices = VBoxContainer.new()
	_choices.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_choices.offset_left = 90
	_choices.offset_right = -90
	_choices.offset_top = -720
	_choices.offset_bottom = -200
	_choices.add_theme_constant_override("separation", 34)
	_choices.visible = false
	add_child(_choices)
	_add_choice(true, "GATE_OPEN", "GATE_OPEN_SUB")
	_add_choice(false, "GATE_CLOSE", "GATE_CLOSE_SUB")

	_hint = Label.new()
	_hint.text = Story.text("intro.skip_hint", "tap to continue")
	_hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_hint.offset_top = -150
	_hint.offset_bottom = -80
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.add_theme_font_size_override("font_size", 34)
	_hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.45))
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hint)

	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 1)
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fade)
	_apply()
	create_tween().tween_property(_fade, "color:a", 0.0, FADE)


func _add_choice(open: bool, key: String, sub_key: String) -> void:
	var button := Button.new()
	button.name = "Open" if open else "Close"
	button.custom_minimum_size = Vector2(0, GameConfig.UI_TAP_MIN + 60)
	button.text = "%s\n%s" % [tr(key), tr(sub_key)]
	button.add_theme_font_size_override("font_size", GameConfig.fs(GameConfig.UI_LABEL))
	var skin := StyleBoxFlat.new()
	skin.bg_color = Color(0.10, 0.10, 0.09, 0.96)
	skin.set_corner_radius_all(18)
	skin.set_border_width_all(2)
	skin.border_color = Color(GameConfig.CASE_ACCENT, 0.6)
	skin.set_content_margin_all(26)
	button.add_theme_stylebox_override("normal", skin)
	button.pressed.connect(_on_choice.bind(open))
	_choices.add_child(button)


func _process(delta: float) -> void:
	_lock = maxf(_lock - delta, 0.0)


func _gui_input(event: InputEvent) -> void:
	if _done or _lock > 0.0 or _page >= 2:
		return
	var tap := (event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed) \
		or (event is InputEventMouseButton and (event as InputEventMouseButton).pressed)
	if tap:
		accept_event()
		advance()


## The next page. Public, so a test can walk the card without a touch event.
func advance() -> void:
	if _page >= 2:
		return
	_page += 1
	_lock = 0.35
	_apply()


func _apply() -> void:
	match _page:
		0:
			_lines.text = "%s\n\n%s" % [tr("GATE_1_L1"), tr("GATE_1_L2")]
		1:
			_lines.text = "%s\n\n%s" % [tr("GATE_2_L1"), tr("GATE_2_L2")]
		_:
			_lines.text = ""
			_choices.visible = true
			_hint.visible = false


func _on_choice(open: bool) -> void:
	if _done:
		return
	_done = true
	Haptics.medium()
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 1.0, FADE)
	tw.tween_callback(func() -> void:
		chosen.emit(open)
		queue_free())
