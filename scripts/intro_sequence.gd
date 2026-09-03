class_name IntroSequence
extends Control
## G7 opening: three full-screen cards, tap to advance.
##
## Each card is an illustration (textures/intro/intro_N.png) under a very slow
## Ken Burns push, with one or two lines of white text over it. When the
## illustration is missing the card falls back to a flat dark-warm ground, so
## the sequence reads correctly before any art exists.
##
## Built in code rather than a .tscn because every card is the same three nodes
## with different data — the layout is a loop, not a tree worth hand-editing.

signal finished()

## Ken Burns: 6 s from 1.0 to 1.06, per the brief.
const KEN_BURNS_TIME := 6.0
const KEN_BURNS_TO := GameConfig.INTRO_KEN_BURNS_TO
const FADE_TIME := 0.55
## Ignore taps for a moment so the tap that dismissed the previous card cannot
## skip the next one too.
const TAP_LOCK := 0.35

var _cards: Array = []
var _index := -1
var _tap_lock := 0.0
var _closing := false

var _image: TextureRect
var _ground: ColorRect
var _scrim: Control
var _lines: VBoxContainer
var _hint: Label
var _fade: ColorRect


## Which card list to play. The prologue uses the same sequence with different
## data (G15.1) — three sets of cards, one screen.
var cards_key := "intro.cards"


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_cards = Story.list(cards_key)
	_build()
	# Landscape (G18): the text keeps to a readable column; the art stays full.
	GameConfig.fit_wide(_lines)
	GameConfig.fit_wide(_hint)
	if _cards.is_empty():
		# Nothing to show; do not strand the player on a black screen.
		push_warning("[Intro] anlati kartlari yok - aciliş atlandi")
		_finish()
		return
	_advance()


func _build() -> void:
	# Warm dark ground, used as the fallback card and as the letterbox behind
	# any illustration that does not match the screen aspect.
	_ground = ColorRect.new()
	_ground.color = GameConfig.INTRO_GROUND
	_ground.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ground.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_ground)

	# Its own pivot-centred wrapper so the Ken Burns scale grows from the middle
	# instead of the top-left corner.
	_image = TextureRect.new()
	_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_image)

	# Darkens the lower half so white text stays readable over any artwork.
	# A plain Control, NOT a ColorRect: an unset ColorRect defaults to opaque
	# white and hid the warm ground entirely.
	_scrim = Control.new()
	_scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var grad := Gradient.new()
	grad.set_color(0, Color(0, 0, 0, 0.05))
	grad.set_color(1, Color(0, 0, 0, 0.78))
	var grad_tex := GradientTexture2D.new()
	grad_tex.gradient = grad
	grad_tex.fill_from = Vector2(0.0, 0.15)
	grad_tex.fill_to = Vector2(0.0, 1.0)
	var scrim_rect := TextureRect.new()
	scrim_rect.texture = grad_tex
	scrim_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	scrim_rect.stretch_mode = TextureRect.STRETCH_SCALE
	scrim_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scrim_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scrim.add_child(scrim_rect)
	add_child(_scrim)

	_lines = VBoxContainer.new()
	_lines.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_lines.anchor_top = 0.58
	_lines.offset_top = 0
	_lines.offset_left = 90
	_lines.offset_right = -90
	_lines.offset_bottom = -260
	_lines.alignment = BoxContainer.ALIGNMENT_END
	_lines.add_theme_constant_override("separation", 18)
	_lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_lines)

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
	_tap_lock = maxf(_tap_lock - delta, 0.0)


func _gui_input(event: InputEvent) -> void:
	if _closing or _tap_lock > 0.0:
		return
	var pressed := event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed
	var clicked := event is InputEventMouseButton and (event as InputEventMouseButton).pressed
	if pressed or clicked:
		accept_event()
		_advance()


## Fades out the current card, swaps in the next one, fades back in.
func _advance() -> void:
	_index += 1
	if _index >= _cards.size():
		_finish()
		return
	_tap_lock = TAP_LOCK
	var card: Dictionary = _cards[_index]

	var tw := create_tween()
	if _index > 0:
		tw.tween_property(_fade, "color:a", 1.0, FADE_TIME)
	tw.tween_callback(func() -> void: _apply(card))
	tw.tween_property(_fade, "color:a", 0.0, FADE_TIME)


func _apply(card: Dictionary) -> void:
	# Image paths are not language-dependent.
	var image_name := str(card.get("image", ""))
	var tex := TextureLibrary.find(image_name) if image_name != "" else null
	_image.texture = tex
	_image.visible = tex != null
	if tex == null and image_name != "":
		TextureLibrary.warn_missing(image_name, "aciliş karti zemini")

	for child in _lines.get_children():
		child.queue_free()
	for raw in card.get("lines", []):
		var label := Label.new()
		# Each line is a translation key.
		label.text = TranslationServer.translate(str(raw))
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.add_theme_font_size_override("font_size", GameConfig.fs(62))
		label.add_theme_color_override("font_color", Color(1, 1, 1))
		# A soft shadow keeps the line legible over a bright patch of artwork.
		label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.55))
		label.add_theme_constant_override("shadow_offset_x", 0)
		label.add_theme_constant_override("shadow_offset_y", 4)
		label.add_theme_constant_override("shadow_outline_size", 8)
		_lines.add_child(label)

	# A "poster" card frames the portrait instead of filling the screen with it:
	# a face cropped to a full-bleed background reads as scenery, and this one
	# has to read as a missing-person notice (G12.8).
	if bool(card.get("poster", false)):
		_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
		_image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_image.anchor_top = 0.10
		_image.anchor_bottom = 0.56
		_image.offset_left = 180
		_image.offset_right = -180
		_image.offset_top = 0
		_image.offset_bottom = 0
	else:
		_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		_image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# Restart the Ken Burns push for this card.
	_image.pivot_offset = _image.size * 0.5
	_image.scale = Vector2.ONE
	if tex != null and not bool(card.get("poster", false)):
		var push := create_tween()
		push.tween_property(_image, "scale", Vector2.ONE * KEN_BURNS_TO,
			KEN_BURNS_TIME).set_trans(Tween.TRANS_LINEAR)


func _finish() -> void:
	if _closing:
		return
	_closing = true
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 1.0, FADE_TIME)
	tw.tween_callback(func() -> void:
		finished.emit()
		queue_free())
