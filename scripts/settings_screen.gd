class_name SettingsScreen
extends Control
## Options had exactly one control before this — a mute icon inside the
## gameplay HUD — and nowhere else in the app. This is the first real home for
## them, reachable from the main menu (and, once the hub's own navigation is
## rebuilt, from there too).
##
## Deliberately small: a handful of rows, not a dashboard of its own. Sound,
## haptics, language, and the same destructive reset the main menu offers, for
## a player who opens Settings looking for it.
##
## Language used to be a read-only row showing whatever the OS had picked. That
## is a reasonable default and a poor dead end — it left a player who wanted
## the other language nothing to tap. It is now a real control; see
## LocaleSupport.select. Switching rebuilds this screen, because every label in
## this game is built once in _ready and will not retranslate itself.

signal closed()

## Switch geometry. The knob travels between the two ends of the track, and the
## track is short enough that the whole switch still sits inside a 150px column
## beside a two-line row of text.
const TRACK_W := 132.0
const TRACK_H := 72.0
const KNOB := 56.0

var _rows: VBoxContainer
var _reset_confirm: Control


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	# Fully opaque. At 0.97 the main menu's title and its action list showed
	# through behind these rows — two screens visible at once, which reads as a
	# rendering fault rather than as a translucency effect.
	var backdrop := ColorRect.new()
	backdrop.color = GameConfig.UI_BG
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)

	var header := Label.new()
	header.text = tr("MENU_SETTINGS")
	header.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	header.offset_top = 96.0
	header.offset_bottom = 196.0
	header.offset_left = 70.0
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	header.add_theme_font_size_override("font_size", GameConfig.UI_TITLE)
	header.add_theme_color_override("font_color", GameConfig.UI_INK)
	add_child(header)

	var close := Button.new()
	close.text = "×"
	close.flat = true
	close.custom_minimum_size = Vector2(90, 90)
	close.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	close.offset_left = -110.0
	close.offset_top = 90.0
	close.add_theme_font_size_override("font_size", GameConfig.UI_TITLE)
	close.add_theme_color_override("font_color", GameConfig.UI_INK_SOFT)
	close.pressed.connect(func() -> void:
		Haptics.light()
		closed.emit())
	add_child(close)

	_rows = VBoxContainer.new()
	_rows.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_rows.offset_top = 236.0
	_rows.offset_left = 70.0
	_rows.offset_right = -70.0
	_rows.add_theme_constant_override("separation", GameConfig.UI_GAP_TIGHT)
	add_child(_rows)

	# Three rows in one undifferentiated column left most of the screen empty
	# and told the player nothing about how the rows related. Grouping them
	# under headings costs no space that was being used and gives the screen
	# the shape of a settings page rather than a list that ran out.
	_add_section(tr("SETTINGS_GROUP_FEEL"))
	_add_toggle(tr("SETTINGS_SOUND"), tr("SETTINGS_SOUND_HINT"),
		not AudioDirector.muted,
		func(on: bool) -> void: AudioDirector.muted = not on)
	_add_divider()
	_add_toggle(tr("SETTINGS_HAPTICS"), tr("SETTINGS_HAPTICS_HINT"),
		Haptics.enabled,
		func(on: bool) -> void:
			Haptics.enabled = on
			GameState.set_setting("meta", "haptics_enabled", on))

	# The device checklist's readout (G16.3): fps, draws and triangles in the
	# corner of every screen. Off by default; a tester turns it on here.
	_add_toggle(tr("SET_PERF_TITLE"), tr("SET_PERF_HINT"), PerfOverlay.enabled(),
		func(on: bool) -> void: PerfOverlay.set_enabled(on))
	# Large text for the surfaces the player reads (G16.4). Takes effect on the
	# next dialogue or card; the settings page itself is not one of them.
	_add_toggle(tr("SET_BIGTEXT_TITLE"), tr("SET_BIGTEXT_HINT"),
		bool(GameState.get_setting("display", "large_text", false)),
		func(on: bool) -> void: GameState.set_setting("display", "large_text", on))
	_add_section(tr("SETTINGS_GROUP_GAME"))
	# The same switch as the one on the game's top bar, in the place a player
	# goes looking for it (G14.8). Cycles the four positions in order, and the
	# value shown is the name of the one in force — Story included, which is
	# the only one that leaves each chapter's own hour alone.
	_add_choice_row(tr("SETTINGS_LIGHT"),
		tr("SKY_VALUE_" + SkyTime.mode().to_upper()),
		func() -> void:
			SkyTime.set_mode(SkyTime.next_mode())
			_rebuild())
	_add_divider()
	_add_choice_row(tr("SETTINGS_LANGUAGE"),
		LocaleSupport.name_of(LocaleSupport.current()),
		func() -> void:
			LocaleSupport.select(LocaleSupport.next_of(LocaleSupport.current()))
			_rebuild())

	# Anchored to the BOTTOM of the screen, not stacked under the last row.
	# A destructive action sitting directly beneath an ordinary one invites
	# the mis-tap it then asks you to confirm; distance is the cheapest guard.
	var reset := Button.new()
	reset.text = tr("SETTINGS_RESET")
	reset.custom_minimum_size = Vector2(0, GameConfig.UI_TAP_MIN)
	reset.flat = true
	reset.alignment = HORIZONTAL_ALIGNMENT_LEFT
	reset.add_theme_font_size_override("font_size", GameConfig.UI_HEAD)
	reset.add_theme_color_override("font_color", GameConfig.UI_RED)
	reset.add_theme_color_override("font_hover_color", GameConfig.UI_RED.lightened(0.15))
	reset.add_theme_color_override("font_pressed_color", GameConfig.UI_RED.lightened(0.15))
	reset.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	reset.pressed.connect(_show_reset_confirm)

	# The reset used to hang on its own in the middle of a large empty area,
	# which read as a stray control rather than as the foot of the screen.
	# It now sits in a footer with a rule above it and the build line below,
	# so the page has a bottom edge instead of just running out.
	var foot := VBoxContainer.new()
	foot.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	foot.offset_left = 70.0
	foot.offset_right = -70.0
	foot.offset_top = -float(GameConfig.UI_TAP_MIN) - 150.0
	foot.offset_bottom = -56.0
	foot.add_theme_constant_override("separation", GameConfig.UI_GAP)
	add_child(foot)

	var rule := ColorRect.new()
	rule.color = GameConfig.UI_LINE
	rule.custom_minimum_size = Vector2(0, 2)
	foot.add_child(rule)
	foot.add_child(reset)

	var build := Label.new()
	build.text = "%s  v%s" % [tr("MENU_TITLE"),
		str(ProjectSettings.get_setting("application/config/version", "1.0.0"))]
	build.add_theme_font_size_override("font_size", GameConfig.UI_MICRO)
	build.add_theme_color_override("font_color", GameConfig.UI_INK_FAINT)
	foot.add_child(build)


## A small brass heading over a run of rows. Same shape as the Journal's group
## heading, so the two screens teach the same reading habit.
func _add_section(title: String) -> void:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, GameConfig.UI_GAP_SECTION)
	_rows.add_child(spacer)
	var label := Label.new()
	label.text = title.to_upper()
	label.add_theme_font_size_override("font_size", GameConfig.UI_LABEL)
	label.add_theme_color_override("font_color", GameConfig.UI_BRASS_DEEP)
	_rows.add_child(label)
	var rule := ColorRect.new()
	rule.color = GameConfig.UI_LINE
	rule.custom_minimum_size = Vector2(0, 2)
	_rows.add_child(rule)


## A hairline between rows, in the case accent at low alpha — the same divider
## the Case screen uses, so the two screens read as one system.
func _add_divider() -> void:
	var line := HSeparator.new()
	var style := StyleBoxFlat.new()
	style.bg_color = GameConfig.UI_LINE
	style.content_margin_top = 1
	style.content_margin_bottom = 1
	line.add_theme_stylebox_override("separator", style)
	_rows.add_child(line)


func _add_toggle(title: String, hint: String, value: bool,
		on_change: Callable) -> void:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 150)
	_rows.add_child(row)

	var text_col := VBoxContainer.new()
	text_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	text_col.add_theme_constant_override("separation", 6)
	row.add_child(text_col)
	var title_label := Label.new()
	title_label.text = title
	title_label.add_theme_font_size_override("font_size", GameConfig.UI_HEAD)
	title_label.add_theme_color_override("font_color", GameConfig.UI_INK)
	text_col.add_child(title_label)
	var hint_label := Label.new()
	hint_label.text = hint
	hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint_label.add_theme_font_size_override("font_size", GameConfig.UI_LABEL)
	hint_label.add_theme_color_override("font_color", GameConfig.UI_INK_SOFT)
	text_col.add_child(hint_label)

	row.add_child(_switch(value, on_change))


## A drawn switch, not a CheckButton.
##
## Godot's CheckButton paints a fixed-size bitmap that does not scale with the
## font. Against this screen's type it rendered as a speck at the far right of
## the row — legible as "something is there", not as "this is on".
##
## State is carried by the knob's POSITION first: it sits left when off and
## right when on, which survives any colour vision. The green is the second
## cue, never the only one.
func _switch(value: bool, on_change: Callable) -> Control:
	var button := Button.new()
	button.toggle_mode = true
	button.button_pressed = value
	button.flat = true
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(150, GameConfig.UI_TAP_MIN)
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())

	var track := Panel.new()
	track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	track.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	track.offset_left = -TRACK_W * 0.5
	track.offset_right = TRACK_W * 0.5
	track.offset_top = -TRACK_H * 0.5
	track.offset_bottom = TRACK_H * 0.5
	button.add_child(track)

	var knob := Panel.new()
	knob.mouse_filter = Control.MOUSE_FILTER_IGNORE
	knob.size = Vector2(KNOB, KNOB)
	track.add_child(knob)

	var paint := func(on: bool, animate: bool) -> void:
		var track_style := StyleBoxFlat.new()
		track_style.bg_color = GameConfig.UI_GREEN_DEEP if on \
			else GameConfig.UI_SURFACE_RAISED
		track_style.border_color = GameConfig.UI_GREEN if on else GameConfig.UI_LINE
		track_style.set_border_width_all(2)
		track_style.set_corner_radius_all(int(TRACK_H * 0.5))
		track.add_theme_stylebox_override("panel", track_style)

		var knob_style := StyleBoxFlat.new()
		knob_style.bg_color = GameConfig.UI_GREEN if on else GameConfig.UI_INK_FAINT
		knob_style.set_corner_radius_all(int(KNOB * 0.5))
		knob.add_theme_stylebox_override("panel", knob_style)

		var pad := (TRACK_H - KNOB) * 0.5
		var target := Vector2(TRACK_W - KNOB - pad if on else pad, pad)
		if not animate:
			knob.position = target
			return
		var tween := knob.create_tween()
		tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.tween_property(knob, "position", target, 0.25)

	paint.call(value, false)
	button.toggled.connect(func(on: bool) -> void:
		Haptics.light()
		paint.call(on, true)
		on_change.call(on))
	return button


## A row whose right-hand side is the CURRENT value and whose whole width is
## the control that changes it. The value is drawn in brass with a trailing
## chevron so it reads as "this is a thing you can change", which a plain grey
## string on the right does not.
func _add_choice_row(title: String, value: String, on_press: Callable) -> void:
	var button := Button.new()
	button.custom_minimum_size = Vector2(0, 150)
	button.flat = true
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	button.pressed.connect(func() -> void:
		Haptics.light()
		on_press.call())
	_rows.add_child(button)

	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(row)

	var title_label := Label.new()
	title_label.text = title
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	title_label.add_theme_font_size_override("font_size", GameConfig.UI_HEAD)
	title_label.add_theme_color_override("font_color", GameConfig.UI_INK)
	row.add_child(title_label)

	var value_label := Label.new()
	value_label.text = value
	value_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	value_label.add_theme_font_size_override("font_size", GameConfig.UI_HEAD)
	value_label.add_theme_color_override("font_color", GameConfig.UI_BRASS)
	row.add_child(value_label)

	var chevron := Label.new()
	chevron.text = "  >"
	chevron.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	chevron.add_theme_font_size_override("font_size", GameConfig.UI_BODY)
	chevron.add_theme_color_override("font_color", GameConfig.UI_BRASS_DEEP)
	row.add_child(chevron)


## Rebuild every label from scratch. Needed after a language switch: Godot only
## re-translates nodes whose text is set through the scene's auto-translate
## path, and this screen sets all of its strings in code.
func _rebuild() -> void:
	# remove_child BEFORE queue_free: freeing alone is deferred to the end of
	# the frame, so _ready would spend that frame drawing the new rows on top
	# of the old ones.
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_rows = null
	_reset_confirm = null
	_ready()


func _show_reset_confirm() -> void:
	if _reset_confirm != null and is_instance_valid(_reset_confirm):
		return
	Haptics.medium()
	var overlay := ColorRect.new()
	overlay.color = Color(0.02, 0.02, 0.02, 0.78)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_reset_confirm = overlay

	var card := PanelContainer.new()
	card.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	card.offset_left = -340.0
	card.offset_right = 340.0
	card.offset_top = -280.0
	card.offset_bottom = 280.0
	var style := StyleBoxFlat.new()
	style.bg_color = GameConfig.UI_SURFACE
	style.border_color = GameConfig.UI_RED
	style.set_border_width_all(2)
	style.set_corner_radius_all(18)
	style.set_content_margin_all(32)
	card.add_theme_stylebox_override("panel", style)
	overlay.add_child(card)

	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 24)
	card.add_child(rows)
	var head := Label.new()
	head.text = tr("MENU_NEW_GAME_CONFIRM_TITLE")
	head.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	head.add_theme_font_size_override("font_size", GameConfig.UI_HEAD)
	head.add_theme_color_override("font_color", GameConfig.UI_INK)
	rows.add_child(head)
	var body := Label.new()
	body.text = tr("MENU_NEW_GAME_CONFIRM_BODY")
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_theme_font_size_override("font_size", GameConfig.UI_BODY)
	body.add_theme_color_override("font_color", GameConfig.UI_INK_SOFT)
	rows.add_child(body)
	var cancel := Button.new()
	cancel.text = tr("UI_CANCEL")
	cancel.custom_minimum_size = Vector2(0, GameConfig.UI_TAP_MIN)
	HubScreen.style_secondary(cancel)
	cancel.pressed.connect(func() -> void:
		Haptics.light()
		overlay.queue_free())
	rows.add_child(cancel)
	var confirm_btn := Button.new()
	confirm_btn.text = tr("MENU_NEW_GAME_CONFIRM_ACTION")
	confirm_btn.custom_minimum_size = Vector2(0, GameConfig.UI_TAP_MIN)
	HubScreen.style_primary(confirm_btn)
	confirm_btn.pressed.connect(func() -> void:
		Haptics.medium()
		GameState.erase_save()
		# The whole app has to restart its flow from a wiped save, not just
		# this screen — closing it alone would drop the player back into a
		# hub built from state that no longer exists.
		get_tree().reload_current_scene())
	rows.add_child(confirm_btn)
	add_child(overlay)
