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
		# G10: only owned mowers appear; the rest live in Gus's workshop.
		if not Garage.is_unlocked(i):
			_buttons.append(null)
			continue
		var info: Dictionary = GameConfig.MOWER_TYPES[i]
		var button := Button.new()
		# A drawn icon, not the emoji: on a phone the emoji is a blank box that
		# still takes its width, which is what pushed these labels right (G12.9).
		button.icon = MowerIcons.icon_for(i)
		button.expand_icon = true
		button.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.custom_minimum_size = Vector2(150, 150)
		button.add_theme_constant_override("h_separation", 0)
		button.text = tr(info["label"])
		button.focus_mode = Control.FOCUS_NONE
		button.mouse_filter = Control.MOUSE_FILTER_STOP
		button.add_theme_font_size_override("font_size", 30)
		button.pressed.connect(_on_pressed.bind(i))
		add_child(button)
		_buttons.append(button)
	set_current(GameConfig.MOWER_PUSH)


func set_current(index: int) -> void:
	_current = index
	for i in _buttons.size():
		var button := _buttons[i]
		if button == null:
			continue
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
