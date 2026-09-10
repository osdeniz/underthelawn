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
## Page order: reunion, party, the dog's name, the door to Case 2 (G26).
const PAGE_REUNION := 0
const PAGE_PARTY := 1
const PAGE_NAME := 2
const PAGE_CASE2 := 3

var _page := 0
var _art: TextureRect
var _scrim: ColorRect
var _title: Label
var _line: Label
var _hint: Label
var _fade: ColorRect
var _lock := 0.0
## The naming page: a box, three chips, one button. Hidden on every other page.
var _name_box: VBoxContainer
var _name_edit: LineEdit
var _name_ok: Button
var _named := false
var _typer := Typewriter.new()


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

	_scrim = ColorRect.new()
	var scrim := _scrim
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

	_name_box = VBoxContainer.new()
	_name_box.add_theme_constant_override("separation", 22)
	_name_box.visible = false
	rows.add_child(_name_box)

	_name_edit = LineEdit.new()
	_name_edit.placeholder_text = tr("REUNION_NAME_PLACEHOLDER")
	_name_edit.max_length = DogName.MAX_CHARS
	_name_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_edit.custom_minimum_size = Vector2(0, 110)
	_name_edit.add_theme_font_size_override("font_size", 50)
	_name_edit.text_submitted.connect(func(_t: String) -> void: _confirm_name())
	_name_box.add_child(_name_edit)

	var chips := HBoxContainer.new()
	chips.alignment = BoxContainer.ALIGNMENT_CENTER
	chips.add_theme_constant_override("separation", 18)
	_name_box.add_child(chips)
	for suggestion in DogName.suggestions():
		var chip := Button.new()
		chip.text = suggestion
		chip.custom_minimum_size = Vector2(230, 96)
		chip.add_theme_font_size_override("font_size", 42)
		_style_button(chip, false)
		chip.pressed.connect(func() -> void:
			_name_edit.text = suggestion
			_confirm_name())
		chips.add_child(chip)

	_name_ok = Button.new()
	_name_ok.text = tr("REUNION_NAME_OK")
	_name_ok.custom_minimum_size = Vector2(0, 108)
	_name_ok.add_theme_font_size_override("font_size", 44)
	_style_button(_name_ok, true)
	_name_ok.pressed.connect(_confirm_name)
	_name_box.add_child(_name_ok)

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
	var was_typing := _typer.typing()
	_typer.advance(delta)
	if was_typing and not _typer.typing():
		_reveal_after_typing()


func _gui_input(event: InputEvent) -> void:
	if _lock > 0.0:
		return
	var pressed := event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed
	var clicked := event is InputEventMouseButton and (event as InputEventMouseButton).pressed
	if not (pressed or clicked):
		return
	if _typer.typing():
		# First tap finishes the words (G37).
		accept_event()
		_typer.finish()
		_reveal_after_typing()
		_lock = 0.35
		return
	# The naming page waits for the button, not a tap anywhere: a tap that meant
	# "dismiss the keyboard" must not skip the question.
	if _page == PAGE_NAME and not _named:
		return
	accept_event()
	_page += 1
	if _page > PAGE_CASE2:
		_close()
		return
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 1.0, FADE)
	tw.tween_callback(_apply)
	tw.tween_property(_fade, "color:a", 0.0, FADE)


func _apply() -> void:
	_lock = 0.5
	_scrim.color.a = 0.55
	_name_box.visible = _page == PAGE_NAME and not _named
	_hint.visible = not _name_box.visible
	if _page == PAGE_REUNION or _page == PAGE_NAME:
		# The painted reunion (G61) is half the brightness of the storybook one
		# it replaced; the old veil buried it. See GameConfig.REUNION_SCRIM.
		_scrim.color.a = GameConfig.REUNION_SCRIM
	if _page == PAGE_NAME:
		# Ellie asks; the reunion photograph stays behind her. If a name was
		# already given (a replay of the ending), the page just says it.
		_art.texture = TextureLibrary.find("story/reunion")
		_title.text = tr("REUNION_NAME_TITLE")
		if DogName.has_name():
			_named = true
			_name_box.visible = false
			_hint.visible = true
			_line.text = DogName.fill(tr("REUNION_NAME_DONE"))
		else:
			_line.text = tr("REUNION_NAME_LINE")
			_name_edit.text = ""
			_name_edit.grab_focus()
	elif _page == PAGE_REUNION:
		_art.texture = TextureLibrary.find("story/reunion")
		if _art.texture == null:
			TextureLibrary.warn_missing("story/reunion", "kavusma karti = duz zemin")
		_title.text = tr("REUNION_TITLE")
		_line.text = tr("REUNION_LINE")
	elif _page == PAGE_PARTY:
		# The party in the square. Its own art if it has been drawn; the reunion
		# photograph carries the beat until then, and the words do the work.
		_art.texture = TextureLibrary.find("story/birthday")
		if _art.texture == null:
			_art.texture = TextureLibrary.find("story/reunion")
		_title.text = tr("BIRTHDAY_TITLE")
		_line.text = tr("BIRTHDAY_LINE")
		# The party art is lit by candles and nothing else; the scrim that keeps
		# text readable over the other two would put it out.
		_scrim.color.a = 0.22
	else:
		_art.texture = TextureLibrary.find("hub/case2_teaser")
		if _art.texture == null:
			TextureLibrary.warn_missing("hub/case2_teaser", "vaka 2 karti = duz zemin")
		# Only say UNLOCKED when it is. The card used to announce Case 02 the
		# moment Case 01 closed, and Case 02 also waits on the town being
		# rebuilt — so the player was told a door had opened and then could not
		# find it anywhere (G13). Locked, the card names the condition instead,
		# which is the same promise with the price attached.
		if ChapterProgress.case_two_open():
			_title.text = "%s\n%s" % [tr("CASE_02_UNLOCKED"), tr("CASE_02_TITLE")]
			# The OBJECTIVE, not the locked line. This branch is the one where
			# the door has just opened, and it was printing "To be continued"
			# underneath the word UNLOCKED — the card announced a case and
			# withdrew it in the same breath (G14.10).
			_line.text = tr("CASE_02_OBJECTIVE")
		else:
			var progress := RestoreBoard.town_ready_progress()
			_title.text = "%s\n%s" % [tr("CASE_02_ID"), tr("CASE_02_TITLE")]
			_line.text = tr("CASE_02_WAITING").format({"done": progress.x,
				"total": progress.y})
	_art.visible = _art.texture != null
	# The words type themselves in (G37); this block, not the branches above,
	# is what decides whether the hint and the naming box are showing yet.
	_typer.play([_title, _line], FADE)
	if _typer.typing():
		_name_box.visible = false
		_hint.visible = false
	else:
		_reveal_after_typing()
	if _page == PAGE_REUNION:
		var tw := create_tween()
		tw.tween_property(_fade, "color:a", 0.0, FADE)


## What waits for the last letter: the hint, and the box that asks for a name.
## Ellie asks the question first and only then is there somewhere to answer —
## a text field sitting under a half-written question reads as a form.
func _reveal_after_typing() -> void:
	_name_box.visible = _page == PAGE_NAME and not _named
	_hint.visible = not _name_box.visible
	if _name_box.visible:
		_name_edit.grab_focus()


## The default button is a grey rectangle drawn for a light theme; over the
## night photograph it read as plain text (measured on the first render). Dark
## card, the case accent for its edge, filled for the one that confirms.
func _style_button(button: Button, primary: bool) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = GameConfig.CASE_ACCENT.darkened(0.55) if primary \
		else Color(0.09, 0.11, 0.10, 0.88)
	style.border_color = GameConfig.CASE_ACCENT
	style.set_border_width_all(2)
	style.set_corner_radius_all(16)
	style.set_content_margin_all(14)
	button.add_theme_stylebox_override("normal", style)
	var hover := style.duplicate() as StyleBoxFlat
	hover.bg_color = hover.bg_color.lightened(0.12)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	button.add_theme_stylebox_override("focus", style)
	button.add_theme_color_override("font_color", Color(0.96, 0.94, 0.88))
	button.add_theme_color_override("font_hover_color", Color(1, 1, 1))
	button.add_theme_color_override("font_pressed_color", Color(1, 1, 1))


## The box or, empty, the first chip: skipping the question still leaves the dog
## with a name, because "the dog" for the rest of the game would read as the
## man's refusal winning. Ellie says the name back, and the next tap moves on.
func _confirm_name() -> void:
	if _named:
		return
	var typed := DogName.clean_name(_name_edit.text)
	if typed == "":
		typed = DogName.suggestions()[0]
	DogName.store(typed)
	_named = true
	_name_box.visible = false
	_line.text = DogName.fill(tr("REUNION_NAME_DONE"))
	# Ellie says the name back, letter by letter like everything else.
	_typer.play([_line])
	_hint.visible = not _typer.typing()
	_lock = 0.4


func _close() -> void:
	set_process(false)
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 1.0, FADE)
	tw.tween_callback(func() -> void:
		finished.emit()
		queue_free())
