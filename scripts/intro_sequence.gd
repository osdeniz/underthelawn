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
var _typer := Typewriter.new()
## Holding to skip (G40): how long the press has lasted, and the bar that
## shows it. -1.0 means no finger is down.
var _hold := -1.0
var _skip_track: ColorRect
var _skip_fill: ColorRect

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

	# "hold to skip", and the bar that fills while a finger is down. The bar
	# is what makes the gesture safe: a thumb left on the screen shows its
	# progress and can be lifted before it counts (G40).
	var skip_hint := Label.new()
	skip_hint.name = "SkipHint"
	skip_hint.text = tr("INTRO_HOLD_SKIP")
	skip_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	skip_hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	skip_hint.offset_top = -96
	skip_hint.offset_bottom = -50
	skip_hint.add_theme_font_size_override("font_size", 26)
	skip_hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.28))
	skip_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(skip_hint)

	_skip_track = ColorRect.new()
	_skip_track.name = "SkipTrack"
	_skip_track.color = Color(1, 1, 1, 0.14)
	_skip_track.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_skip_track.offset_left = -140
	_skip_track.offset_right = 140
	_skip_track.offset_top = -44
	_skip_track.offset_bottom = -38
	_skip_track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_skip_track.visible = false
	add_child(_skip_track)
	_skip_fill = ColorRect.new()
	_skip_fill.color = GameConfig.CASE_ACCENT
	_skip_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_skip_fill.size = Vector2(0, 6)
	_skip_track.add_child(_skip_fill)

	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 1)
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fade)


func _process(delta: float) -> void:
	_tap_lock = maxf(_tap_lock - delta, 0.0)
	_typer.advance(delta)
	# Asked every frame rather than caught on the transition: a skip or a
	# settings change can finish the typing too, and the first version left
	# the hint hidden for good when it did (seen in out/typing_3_skip.png).
	_hint.visible = not _typer.typing()
	_tick_hold(delta)


func _gui_input(event: InputEvent) -> void:
	var pressed := event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed
	var clicked := event is InputEventMouseButton and (event as InputEventMouseButton).pressed
	var lifted := (event is InputEventScreenTouch
			and not (event as InputEventScreenTouch).pressed) \
		or (event is InputEventMouseButton and not (event as InputEventMouseButton).pressed)
	# A lift clears the hold BEFORE the tap lock is consulted. The first
	# version checked the lock first, so the release after a tap was swallowed
	# and the press went on counting: tapping one card and then touching
	# nothing skipped the whole prologue a second later (measured).
	if lifted:
		_hold = -1.0
		if _skip_track != null:
			_skip_track.visible = false
		return
	if pressed or clicked:
		# The timer starts even inside the tap lock — a finger going down
		# right after a tap is still a finger going down — but nothing else
		# happens until the lock has run out.
		if _hold < 0.0:
			_hold = 0.0
		if _closing or _tap_lock > 0.0:
			return
		accept_event()
		if _typer.typing():
			# First tap finishes the words, second turns the page: the same two
			# taps the dialogue box has always asked for (G37).
			_typer.finish()
			_hint.visible = true
			_tap_lock = TAP_LOCK
			return
		_advance()


## A press that outlasts INTRO_SKIP_HOLD ends the whole sequence, not just the
## card: the flow takes it from there exactly as it would after the last one.
func _tick_hold(delta: float) -> void:
	if _closing:
		return
	if _hold < 0.0:
		if _skip_track.visible:
			_skip_track.visible = false
		return
	_hold += delta
	# The bar appears only once the press has clearly outlived a tap.
	_skip_track.visible = _hold > 0.18
	_skip_fill.size = Vector2(_skip_track.size.x
		* clampf(_hold / GameConfig.INTRO_SKIP_HOLD, 0.0, 1.0), _skip_track.size.y)
	if _hold >= GameConfig.INTRO_SKIP_HOLD:
		_hold = -1.0
		_skip_track.visible = false
		Haptics.medium()
		Analytics.track(AnalyticsEvents.INTRO_SKIPPED,
			{"cards": cards_key, "at": _index})
		_finish()


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
	# The labels this card is about to type, collected as they are made:
	# get_children() still holds the ones just queue_freed, and typing into a
	# dying label types into nothing.
	var fresh: Array = []
	for raw in card.get("lines", []):
		var label := Label.new()
		# Each line is a translation key.
		label.text = DogName.fill(TranslationServer.translate(str(raw)))
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.add_theme_font_size_override("font_size", GameConfig.fs(62))
		label.add_theme_color_override("font_color", Color(1, 1, 1))
		# A soft shadow keeps the line legible over a bright patch of artwork.
		label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.55))
		label.add_theme_constant_override("shadow_offset_x", 0)
		label.add_theme_constant_override("shadow_offset_y", 4)
		label.add_theme_constant_override("shadow_outline_size", 8)
		_lines.add_child(label)
		fresh.append(label)

	# Letter by letter (G37), starting when the fade has brought the picture
	# in. The hint waits for the last letter, the way the dialogue box's does.
	_typer.play(fresh, FADE_TIME)
	_hint.visible = not _typer.typing()

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
