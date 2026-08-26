class_name ReunionCard
extends Control
## The end of Case 1 (G11): Ellie home, the party that was waiting for her, then
## the door to Case 2.
##
## Three full-screen beats, tapped through like the opening cards, because the
## case should close the way it opened — quietly, with a picture and two lines.
## The middle beat is the warm one and the last is the cold one, deliberately
## next to each other (G14.1): the town gets its evening, and the question of
## what Ellie saw is already standing behind it.

signal finished()

const FADE := 0.4

var _page := 0
var _art: TextureRect
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
	ground.color = GameConfig.INTRO_GROUND
	ground.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ground.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ground)

	_art = TextureRect.new()
	_art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_art)

	var scrim := ColorRect.new()
	scrim.color = Color(0, 0, 0, 0.55)
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(scrim)

	var rows := VBoxContainer.new()
	rows.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rows.anchor_top = 0.58
	rows.offset_top = 0
	rows.offset_left = 90
	rows.offset_right = -90
	rows.offset_bottom = -260
	rows.alignment = BoxContainer.ALIGNMENT_END
	rows.add_theme_constant_override("separation", 26)
	rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rows)

	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_title.add_theme_font_size_override("font_size", 68)
	_title.add_theme_color_override("font_color", GameConfig.CASE_ACCENT)
	_title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	_title.add_theme_constant_override("shadow_offset_y", 4)
	rows.add_child(_title)

	_line = Label.new()
	_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_line.add_theme_font_size_override("font_size", 46)
	_line.add_theme_color_override("font_color", Color(0.95, 0.94, 0.90))
	_line.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	_line.add_theme_constant_override("shadow_offset_y", 3)
	rows.add_child(_line)

	_hint = Label.new()
	_hint.text = Story.text("intro.skip_hint", "tap to continue")
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_hint.offset_top = -150
	_hint.offset_bottom = -80
	_hint.add_theme_font_size_override("font_size", 34)
	_hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.45))
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hint)

	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 1)
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fade)


func _process(delta: float) -> void:
	_lock = maxf(_lock - delta, 0.0)


func _gui_input(event: InputEvent) -> void:
	if _lock > 0.0:
		return
	var pressed := event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed
	var clicked := event is InputEventMouseButton and (event as InputEventMouseButton).pressed
	if not (pressed or clicked):
		return
	accept_event()
	_page += 1
	if _page > 2:
		_close()
		return
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 1.0, FADE)
	tw.tween_callback(_apply)
	tw.tween_property(_fade, "color:a", 0.0, FADE)


func _apply() -> void:
	_lock = 0.5
	if _page == 0:
		_art.texture = TextureLibrary.find("story/reunion")
		if _art.texture == null:
			TextureLibrary.warn_missing("story/reunion", "kavusma karti = duz zemin")
		_title.text = tr("REUNION_TITLE")
		_line.text = tr("REUNION_LINE")
	elif _page == 1:
		# The party in the square. Its own art if it has been drawn; the reunion
		# photograph carries the beat until then, and the words do the work.
		_art.texture = TextureLibrary.find("story/birthday")
		if _art.texture == null:
			_art.texture = TextureLibrary.find("story/reunion")
		_title.text = tr("BIRTHDAY_TITLE")
		_line.text = tr("BIRTHDAY_LINE")
	else:
		_art.texture = TextureLibrary.find("hub/case2_teaser")
		if _art.texture == null:
			TextureLibrary.warn_missing("hub/case2_teaser", "vaka 2 karti = duz zemin")
		_title.text = "%s\n%s" % [tr("CASE_02_UNLOCKED"), tr("CASE_02_TITLE")]
		_line.text = tr("CASE_02_LOCKED")
	_art.visible = _art.texture != null
	if _page == 0:
		var tw := create_tween()
		tw.tween_property(_fade, "color:a", 0.0, FADE)


func _close() -> void:
	set_process(false)
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 1.0, FADE)
	tw.tween_callback(func() -> void:
		finished.emit()
		queue_free())
