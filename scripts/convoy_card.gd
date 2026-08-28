class_name ConvoyCard
extends Control
## The end of Case 02 (G13): the town in sight, and then the thing on the road
## behind it.
##
## Two beats, tapped through like the opening cards. The first is the warm one —
## the water tower, the porch light, two weeks of walking done. The second is the
## cold one, and it is deliberately the LAST thing the case says: the stranger
## told the Marshal to look east before he went inside.
##
## The illustration is optional. textures/story/convoy is used when it exists;
## when it does not, the card draws the headlights itself, because "a dark
## rectangle with text on it" is not an ending and this has to ship either way.

signal finished()

const FADE := 0.4
const PAGES := 2

var _page := 0
var _art: TextureRect
var _drawn: Control
var _scrim: ColorRect
var _title: Label
var _line: Label
var _hint: Label
var _fade: ColorRect
var _lock := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()
	_apply()


func _build() -> void:
	var ground := ColorRect.new()
	ground.color = GameConfig.QUIET_SKY
	ground.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ground.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ground)

	_drawn = Control.new()
	_drawn.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_drawn.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_drawn.draw.connect(_draw_page.bind(_drawn))
	add_child(_drawn)

	_art = TextureRect.new()
	_art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_art)

	_scrim = ColorRect.new()
	_scrim.color = Color(0.02, 0.02, 0.03, 0.45)
	_scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_scrim)

	var rows := VBoxContainer.new()
	rows.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	rows.offset_left = 70.0
	rows.offset_right = -70.0
	rows.offset_top = -560.0
	rows.offset_bottom = -180.0
	rows.add_theme_constant_override("separation", 26)
	rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rows)

	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_title.add_theme_font_size_override("font_size", 62)
	_title.add_theme_color_override("font_color", Color(0.96, 0.94, 0.88))
	rows.add_child(_title)

	_line = Label.new()
	_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_line.add_theme_font_size_override("font_size", 36)
	_line.add_theme_color_override("font_color", Color(0.84, 0.82, 0.78))
	rows.add_child(_line)

	_hint = Label.new()
	_hint.text = tr("INTRO_SKIP_HINT")
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.add_theme_font_size_override("font_size", 28)
	_hint.add_theme_color_override("font_color", Color(0.62, 0.60, 0.56))
	rows.add_child(_hint)

	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 1)
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fade)
	set_process(true)


func _process(delta: float) -> void:
	_lock = maxf(_lock - delta, 0.0)


func _unhandled_input(event: InputEvent) -> void:
	if _lock > 0.0:
		return
	var tapped := event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed
	var clicked := event is InputEventMouseButton and (event as InputEventMouseButton).pressed
	if not tapped and not clicked:
		return
	get_viewport().set_input_as_handled()
	_page += 1
	if _page >= PAGES:
		_close()
		return
	_lock = 0.35
	_apply()
	_drawn.queue_redraw()


func _apply() -> void:
	if _page == 0:
		_art.texture = TextureLibrary.find("story/homecoming")
		_title.text = tr("CASE_02_COMPLETE")
		_line.text = tr("DLG_DEB_CH18_F1")
	else:
		_art.texture = TextureLibrary.find("story/convoy")
		_title.text = tr("FINAL_02_HEADLINE")
		_line.text = tr("FINAL_02_LINE")
	_art.visible = _art.texture != null
	_scrim.visible = _art.texture != null
	if _page == 0:
		var tw := create_tween()
		tw.tween_property(_fade, "color:a", 0.0, FADE)


## The fallback illustration, and the one that actually ships today: a night
## horizon, the town's water tower on the left, and headlights on the east road.
func _draw_page(canvas: Control) -> void:
	if _art.texture != null:
		return
	var size := canvas.size
	var horizon := size.y * 0.52
	canvas.draw_rect(Rect2(Vector2(0.0, horizon),
		Vector2(size.x, size.y - horizon)), GameConfig.QUIET_GROUND)
	# The town: a tower and a few roof lines, with one window lit.
	var base := Vector2(size.x * 0.22, horizon)
	canvas.draw_rect(Rect2(base + Vector2(-14.0, -170.0), Vector2(28.0, 170.0)),
		GameConfig.QUIET_FIGURE)
	canvas.draw_rect(Rect2(base + Vector2(-46.0, -220.0), Vector2(92.0, 54.0)),
		GameConfig.QUIET_FIGURE)
	for i in 4:
		var x := size.x * (0.34 + float(i) * 0.055)
		canvas.draw_rect(Rect2(Vector2(x, horizon - 46.0), Vector2(64.0, 46.0)),
			GameConfig.QUIET_FIGURE)
	canvas.draw_rect(Rect2(Vector2(size.x * 0.352, horizon - 34.0),
		Vector2(14.0, 14.0)), Color(0.96, 0.80, 0.42))

	if _page == 0:
		return
	# Page two: the road east, and the lights on it. Paired, unevenly spaced,
	# each with a halo — a convoy reads as a convoy because there are SEVERAL.
	# Kept clear of the right edge: the first pass ran the road off screen and
	# clipped the nearest pair of lights in half.
	canvas.draw_colored_polygon(PackedVector2Array([
		Vector2(size.x * 0.74, horizon), Vector2(size.x * 0.80, horizon),
		Vector2(size.x * 1.00, size.y * 0.86), Vector2(size.x * 0.46, size.y * 0.86)]),
		GameConfig.QUIET_ROAD)
	var along: Array[float] = [0.04, 0.14, 0.28, 0.46]
	for i in along.size():
		var t: float = along[i]
		var y := horizon + (size.y * 0.86 - horizon) * t
		var x := lerpf(size.x * 0.77, size.x * 0.73, t)
		var r := lerpf(5.0, 14.0, t)
		for side: float in [-1.0, 1.0]:
			var at := Vector2(x + side * r * 2.4, y)
			canvas.draw_circle(at, r * 2.6, Color(0.98, 0.90, 0.62, 0.10))
			canvas.draw_circle(at, r, Color(0.99, 0.95, 0.78, 0.92))


func _close() -> void:
	set_process(false)
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 1.0, FADE)
	tw.tween_callback(func() -> void:
		finished.emit()
		queue_free())
