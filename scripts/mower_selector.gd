class_name MowerSelector
extends HBoxContainer
## Three-way mower picker at the bottom centre (§16). Selected entry is
## highlighted green. Buttons STOP input so taps never reach the lawn.

signal mower_chosen(index: int)

var _buttons: Array[Button] = []
var _current := -1


func _ready() -> void:
	add_theme_constant_override("separation", 24)
	alignment = BoxContainer.ALIGNMENT_CENTER
	for i in GameConfig.MOWER_TYPES.size():
		var info: Dictionary = GameConfig.MOWER_TYPES[i]
		var button := Button.new()
		button.text = "%s %s" % [info["emoji"], info["label"]]
		button.focus_mode = Control.FOCUS_NONE
		button.mouse_filter = Control.MOUSE_FILTER_STOP
		button.add_theme_font_size_override("font_size", 40)
		button.pressed.connect(_on_pressed.bind(i))
		add_child(button)
		_buttons.append(button)
	set_current(GameConfig.MOWER_PUSH)


func set_current(index: int) -> void:
	_current = index
	for i in _buttons.size():
		var button := _buttons[i]
		button.add_theme_stylebox_override("normal", _style(i == index))
		button.add_theme_stylebox_override("hover", _style(i == index))
		button.add_theme_stylebox_override("pressed", _style(true))
		button.add_theme_color_override("font_color",
			Color(1.0, 1.0, 0.92) if i == index else Color(0.78, 0.82, 0.76))


func _on_pressed(index: int) -> void:
	if index == _current:
		return
	mower_chosen.emit(index)


func _style(selected: bool) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.24, 0.55, 0.20, 0.95) if selected \
		else Color(0.06, 0.11, 0.07, 0.72)
	sb.border_color = Color(0.55, 0.86, 0.42, 0.9) if selected \
		else Color(0.4, 0.46, 0.38, 0.5)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(26)
	sb.content_margin_left = 26.0
	sb.content_margin_right = 26.0
	sb.content_margin_top = 18.0
	sb.content_margin_bottom = 18.0
	return sb
