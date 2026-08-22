class_name Hud
extends Control
## Builds the whole HUD in code so the scene file stays tiny: completion meter,
## secret-discovery toast, and a finish banner.

var _bar: ProgressBar
var _percent: Label
var _tiles: Label
var _toast: PanelContainer
var _toast_label: Label
var _banner: Label
var _hint: Label
var _percent_tween: Tween
var _toast_tween: Tween


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_meter()
	_build_toast()
	_build_banner()
	_build_hint()
	_build_reset_button()


# ---------------------------------------------------------------- public API

func set_completion(percent: float, cut_tiles: int, total_tiles: int) -> void:
	if _bar:
		_bar.value = percent
	if _percent:
		_percent.text = "%d%%" % int(floor(percent))
		_pop(_percent)
	if _tiles:
		_tiles.text = "%d / %d tiles" % [cut_tiles, total_tiles]


func show_secret(name_text: String) -> void:
	if _toast == null:
		return
	_toast_label.text = "SECRET FOUND\n%s" % name_text.to_upper()
	_toast.modulate.a = 0.0
	_toast.visible = true
	_toast.scale = Vector2(0.9, 0.9)
	if _toast_tween and _toast_tween.is_valid():
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_property(_toast, "modulate:a", 1.0, 0.25)
	_toast_tween.parallel().tween_property(_toast, "scale", Vector2.ONE, 0.4) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_toast_tween.tween_interval(2.8)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.6)


func show_complete() -> void:
	if _banner == null:
		return
	_banner.visible = true
	_banner.modulate.a = 0.0
	_banner.scale = Vector2(0.7, 0.7)
	var tw := create_tween()
	tw.tween_property(_banner, "modulate:a", 1.0, 0.3)
	tw.parallel().tween_property(_banner, "scale", Vector2.ONE, 0.7) \
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func hide_hint() -> void:
	if _hint and _hint.visible:
		var tw := create_tween()
		tw.tween_property(_hint, "modulate:a", 0.0, 0.5)
		tw.tween_callback(_hint.hide)


# ---------------------------------------------------------------- building

func _panel_style(bg: Color, border: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(14)
	sb.content_margin_left = 18.0
	sb.content_margin_right = 18.0
	sb.content_margin_top = 10.0
	sb.content_margin_bottom = 12.0
	return sb


func _build_meter() -> void:
	var panel := PanelContainer.new()
	panel.name = "Meter"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.offset_left = -220.0
	panel.offset_right = 220.0
	panel.offset_top = 18.0
	panel.offset_bottom = 116.0
	panel.add_theme_stylebox_override("panel",
		_panel_style(Color(0.04, 0.09, 0.05, 0.72), Color(0.55, 0.82, 0.35, 0.55)))
	add_child(panel)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	panel.add_child(row)

	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 4)
	row.add_child(left)

	var title := Label.new()
	title.text = "LAWN MOWED"
	title.add_theme_font_size_override("font_size", 15)
	title.add_theme_color_override("font_color", Color(0.78, 0.92, 0.62))
	left.add_child(title)

	_bar = ProgressBar.new()
	_bar.min_value = 0.0
	_bar.max_value = 100.0
	_bar.value = 0.0
	_bar.show_percentage = false
	_bar.custom_minimum_size = Vector2(0.0, 22.0)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.02, 0.05, 0.02, 0.85)
	bg.set_corner_radius_all(11)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.47, 0.80, 0.24)
	fill.set_corner_radius_all(11)
	_bar.add_theme_stylebox_override("background", bg)
	_bar.add_theme_stylebox_override("fill", fill)
	left.add_child(_bar)

	_tiles = Label.new()
	_tiles.text = "0 / 0 tiles"
	_tiles.add_theme_font_size_override("font_size", 12)
	_tiles.add_theme_color_override("font_color", Color(0.72, 0.84, 0.66, 0.8))
	left.add_child(_tiles)

	_percent = Label.new()
	_percent.text = "0%"
	_percent.add_theme_font_size_override("font_size", 40)
	_percent.add_theme_color_override("font_color", Color(0.85, 0.98, 0.62))
	_percent.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_percent.custom_minimum_size = Vector2(96.0, 0.0)
	_percent.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(_percent)


func _build_toast() -> void:
	_toast = PanelContainer.new()
	_toast.name = "SecretToast"
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast.visible = false
	_toast.anchor_left = 0.5
	_toast.anchor_right = 0.5
	_toast.anchor_top = 0.0
	_toast.anchor_bottom = 0.0
	_toast.offset_left = -200.0
	_toast.offset_right = 200.0
	_toast.offset_top = 132.0
	_toast.offset_bottom = 216.0
	_toast.pivot_offset = Vector2(200.0, 42.0)
	_toast.add_theme_stylebox_override("panel",
		_panel_style(Color(0.10, 0.07, 0.02, 0.82), Color(0.95, 0.82, 0.35, 0.8)))
	add_child(_toast)

	_toast_label = Label.new()
	_toast_label.text = "SECRET FOUND"
	_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast_label.add_theme_font_size_override("font_size", 20)
	_toast_label.add_theme_color_override("font_color", Color(1.0, 0.94, 0.66))
	_toast.add_child(_toast_label)


func _build_banner() -> void:
	_banner = Label.new()
	_banner.name = "Banner"
	_banner.visible = false
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner.text = "LAWN COMPLETE!"
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_banner.add_theme_font_size_override("font_size", 54)
	_banner.add_theme_color_override("font_color", Color(0.95, 1.0, 0.7))
	_banner.add_theme_color_override("font_outline_color", Color(0.05, 0.15, 0.03))
	_banner.add_theme_constant_override("outline_size", 10)
	_banner.anchor_left = 0.5
	_banner.anchor_right = 0.5
	_banner.anchor_top = 0.5
	_banner.anchor_bottom = 0.5
	_banner.offset_left = -320.0
	_banner.offset_right = 320.0
	_banner.offset_top = -60.0
	_banner.offset_bottom = 20.0
	_banner.pivot_offset = Vector2(320.0, 40.0)
	add_child(_banner)


func _build_hint() -> void:
	_hint = Label.new()
	_hint.name = "Hint"
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint.text = "Drag anywhere on the left side to drive  •  arrow keys also work"
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.add_theme_font_size_override("font_size", 16)
	_hint.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.75))
	_hint.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.8))
	_hint.add_theme_constant_override("outline_size", 6)
	_hint.anchor_left = 0.0
	_hint.anchor_right = 1.0
	_hint.anchor_top = 1.0
	_hint.anchor_bottom = 1.0
	_hint.offset_top = -46.0
	_hint.offset_bottom = -18.0
	add_child(_hint)


func _build_reset_button() -> void:
	var btn := Button.new()
	btn.name = "ResetButton"
	btn.text = "Reset"
	btn.focus_mode = Control.FOCUS_NONE
	btn.anchor_left = 1.0
	btn.anchor_right = 1.0
	btn.offset_left = -108.0
	btn.offset_right = -18.0
	btn.offset_top = 18.0
	btn.offset_bottom = 58.0
	btn.pressed.connect(_on_reset_pressed)
	add_child(btn)


func _on_reset_pressed() -> void:
	get_tree().reload_current_scene()


func _pop(node: Control) -> void:
	if _percent_tween and _percent_tween.is_valid():
		_percent_tween.kill()
	node.pivot_offset = node.size * Vector2(1.0, 0.5)
	node.scale = Vector2(1.12, 1.12)
	_percent_tween = create_tween()
	_percent_tween.tween_property(node, "scale", Vector2.ONE, 0.18) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
