class_name DialogueBox
extends Control
## The one portrait-dialogue UI (G8). Briefing, debrief and town chatter all
## play through this; there is no second dialogue implementation.
##
## Lower half of the screen: the character's full 9:16 illustration standing
## LARGE above the text panel (the art is full-figure, and a thumbnail wastes
## it), name at the top of the panel, one to three lines typed out fast. First tap finishes the current line instantly,
## second tap advances — so a reader is never slowed down and a skimmer is never
## blocked. A flavour choice shows two buttons; picking one appends its reaction
## line and the conversation continues.
##
## Built in code, not a .tscn: it is one fixed layout reused for every
## conversation, and the interesting part is the timing, not the tree.

signal finished()

## Characters per second. Fast on purpose — the typewriter is texture, not a
## reading-speed limiter.
## G11: 55 cps outran comfortable reading on the longer Case 1 lines. The tap
## still completes a line instantly, so this only sets the unhurried pace.
const TYPE_CPS := 42.0
const FADE_TIME := 0.25
## Ignore taps briefly after one lands, so a double tap cannot skip a whole line
## plus the next one.
const TAP_LOCK := 0.12

var _entries: Array = []
var _index := -1
var _typing := false
var _shown := 0.0
var _full_text := ""
var _tap_lock := 0.0
var _accept_key := ""
var _awaiting_choice := false

var _scrim: ColorRect
var _panel: PanelContainer
var _portrait_frame: Panel
var _portrait_image: TextureRect
var _portrait_initial: Label
var _name_label: Label
var _text_label: Label
var _hint: Label
var _accept: Button
var _choices: VBoxContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()
	modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 1.0, FADE_TIME)


## Plays `entries` (from Dialogue.conversation / Dialogue.town_lines).
## `accept_key` adds a confirm button on the LAST line, for conversations the
## player has to actively accept, like a briefing.
func play(entries: Array, accept_key := "") -> void:
	_entries = entries
	_accept_key = accept_key
	_index = -1
	if _entries.is_empty():
		# Never leave the player stuck behind an empty box.
		push_warning("[Dialogue] bos konusma - kutu atlandi")
		_close()
		return
	_advance()


func _build() -> void:
	_scrim = ColorRect.new()
	_scrim.color = Color(0, 0, 0, 0.55)
	_scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_scrim)

	# The illustration stands above the text panel, which then overlaps its foot
	# so figure and box read as one unit instead of two stacked rectangles.
	_portrait_frame = Panel.new()
	_portrait_frame.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_portrait_frame.offset_left = 56
	_portrait_frame.offset_right = 56 + GameConfig.DIALOGUE_PORTRAIT_SIZE.x
	_portrait_frame.offset_top = -GameConfig.DIALOGUE_PORTRAIT_SIZE.y \
		- GameConfig.DIALOGUE_PANEL_LIFT
	_portrait_frame.offset_bottom = -GameConfig.DIALOGUE_PANEL_LIFT
	_portrait_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Godot does not clip children to a parent's rounded StyleBox unless asked,
	# so without this the image draws as a hard square over the frame.
	_portrait_frame.clip_children = CanvasItem.CLIP_CHILDREN_ONLY
	var frame_style := StyleBoxFlat.new()
	frame_style.bg_color = Color(0.16, 0.15, 0.13)
	frame_style.set_corner_radius_all(26)
	frame_style.border_color = Color(GameConfig.CASE_ACCENT, 0.5)
	frame_style.set_border_width_all(3)
	_portrait_frame.add_theme_stylebox_override("panel", frame_style)
	add_child(_portrait_frame)

	_portrait_image = TextureRect.new()
	_portrait_image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_portrait_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_portrait_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_portrait_frame.add_child(_portrait_image)

	_portrait_initial = Label.new()
	_portrait_initial.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_portrait_initial.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_portrait_initial.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_portrait_initial.add_theme_font_size_override("font_size", 190)
	_portrait_initial.add_theme_color_override("font_color", GameConfig.CASE_ACCENT)
	_portrait_initial.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_portrait_frame.add_child(_portrait_initial)

	_panel = PanelContainer.new()
	_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	# Taller: the bubble starts higher up the screen so the bigger text has
	# somewhere to go (G14.23).
	_panel.anchor_top = 0.70
	_panel.offset_top = 0
	_panel.offset_left = 40
	_panel.offset_right = -40
	_panel.offset_bottom = -60
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = GameConfig.CASE_PANEL
	style.set_corner_radius_all(30)
	style.set_content_margin_all(44)
	style.border_color = Color(GameConfig.CASE_ACCENT, 0.35)
	style.set_border_width_all(3)
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)

	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 26)
	rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(rows)

	_name_label = Label.new()
	_name_label.add_theme_font_size_override("font_size", 54)
	_name_label.add_theme_color_override("font_color", GameConfig.CASE_ACCENT)
	_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rows.add_child(_name_label)

	_text_label = Label.new()
	_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# Three lines of headroom, so a long line does not resize the panel mid-read.
	# Four lines of headroom: Case 1 has lines that wrap to three, and a box
	# that grows mid-read pushes the text under the reader's thumb.
	_text_label.custom_minimum_size = Vector2(0, 300)
	_text_label.add_theme_font_size_override("font_size", 52)
	_text_label.add_theme_color_override("font_color", Color(0.94, 0.94, 0.91))
	_text_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rows.add_child(_text_label)

	_choices = VBoxContainer.new()
	_choices.add_theme_constant_override("separation", 16)
	_choices.visible = false
	rows.add_child(_choices)

	_accept = Button.new()
	_accept.add_theme_font_size_override("font_size", 46)
	_accept.visible = false
	rows.add_child(_accept)

	_hint = Label.new()
	_hint.text = "▾"
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hint.add_theme_font_size_override("font_size", 34)
	_hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.45))
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rows.add_child(_hint)


func _process(delta: float) -> void:
	_tap_lock = maxf(_tap_lock - delta, 0.0)
	if not _typing:
		return
	_shown += TYPE_CPS * delta
	var count := mini(int(_shown), _full_text.length())
	_text_label.text = _full_text.substr(0, count)
	if count >= _full_text.length():
		_typing = false
		_hint.visible = not _awaiting_choice


func _gui_input(event: InputEvent) -> void:
	if _tap_lock > 0.0 or _awaiting_choice:
		return
	var pressed := event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed
	var clicked := event is InputEventMouseButton and (event as InputEventMouseButton).pressed
	if not (pressed or clicked):
		return
	accept_event()
	_tap_lock = TAP_LOCK
	if _typing:
		# First tap completes the line rather than skipping it.
		_shown = float(_full_text.length())
		return
	if _accept.visible:
		# The last line of an accept-gated conversation needs the button.
		return
	_advance()


func _advance() -> void:
	_index += 1
	if _index >= _entries.size():
		_close()
		return
	var entry: Dictionary = _entries[_index]
	if entry.has("choice"):
		_show_choice(entry["choice"])
		return
	_show_line(entry)
	# The accept button belongs on the final entry only.
	var is_last := _index == _entries.size() - 1
	if is_last and _accept_key != "":
		_accept.text = tr(_accept_key)
		_accept.visible = true
		_hint.visible = false
		if not _accept.pressed.is_connected(_on_accept):
			_accept.pressed.connect(_on_accept)


func _show_line(entry: Dictionary) -> void:
	var speaker := str(entry.get("speaker", ""))
	_name_label.text = tr(_speaker_name_key(speaker))
	_set_portrait(speaker)
	_full_text = tr(str(entry.get("text", "")))
	_shown = 0.0
	_typing = true
	_hint.visible = false
	_text_label.text = ""
	_speak(str(entry.get("text", "")))


## Plays a recorded line if one has been dropped in, and does nothing at all if
## not (G14.23).
##
## There is no generated speech here and there will not be: this project's rule
## is no runtime audio synthesis, and a recorded performance is not something
## the build can invent. What it CAN do is agree on where the files live, so a
## voice pass is a matter of adding audio and touching no code — one .ogg per
## translation key, under audio/voice/, named for the key.
func _speak(text_key: String) -> void:
	AudioDirector.stop_voice()
	if text_key == "":
		return
	AudioDirector.play_voice(text_key)


## Speaker id -> the name key the town screen also uses, so a character is named
## the same everywhere.
func _speaker_name_key(speaker_id: String) -> String:
	return "CHAR_" + speaker_id.to_upper()


func _set_portrait(speaker_id: String) -> void:
	var tex: Texture2D = null
	if speaker_id != "":
		tex = TextureLibrary.find("portraits/" + speaker_id)
	_portrait_image.texture = tex
	_portrait_image.visible = tex != null
	_portrait_initial.visible = tex == null
	if tex == null:
		if speaker_id != "":
			TextureLibrary.warn_missing("portraits/" + speaker_id,
				"diyalog portresi = harf dairesi")
		var shown := _name_label.text
		_portrait_initial.text = shown.substr(0, 1).to_upper() if shown != "" else "?"


## Two flavour buttons. Picking one splices its reaction line in right after
## this entry, so the rest of the conversation is untouched.
func _show_choice(choice: Dictionary) -> void:
	_awaiting_choice = true
	_hint.visible = false
	_text_label.text = ""
	_full_text = ""
	_typing = false
	for child in _choices.get_children():
		child.queue_free()
	var options: Array = choice.get("options", [])
	for option: Dictionary in options:
		var button := Button.new()
		button.text = tr(str(option.get("text", "")))
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.add_theme_font_size_override("font_size", 38)
		button.pressed.connect(_on_choice.bind(option))
		_choices.add_child(button)
	_choices.visible = true


func _on_choice(option: Dictionary) -> void:
	_awaiting_choice = false
	_choices.visible = false
	for child in _choices.get_children():
		child.queue_free()
	Haptics.light()
	var reply: Variant = option.get("reply", null)
	if reply is Dictionary:
		_entries.insert(_index + 1, reply)
	_tap_lock = TAP_LOCK
	_advance()


func _on_accept() -> void:
	Haptics.light()
	_close()


func _close() -> void:
	set_process(false)
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, FADE_TIME)
	tw.tween_callback(func() -> void:
		finished.emit()
		queue_free())
