class_name MainMenu
extends Control
## The game's front door (UI/UX redesign, Phase 1).
##
## Nothing like this existed before: the app went straight from a splash frame
## into the intro cards, every launch, forever — there was no CONTINUE, no way
## to start over on purpose, and no home for Settings. This is the first screen
## a player sees, cold or returning, and the only place "new game" is a choice
## rather than an accident of an empty save file.
##
## Quiet on purpose: one illustration, one title, a short list of plain-text
## actions. No cards, no dashboard, no restating what the game is — the cards
## after this earn that.

signal continue_pressed()
signal new_game_pressed()
signal journal_pressed()
signal settings_pressed()

const FADE_IN := 0.6

var _confirm: Control


func _ready() -> void:
	LocaleSupport.apply()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	modulate.a = 0.0
	_build()
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 1.0, FADE_IN)


func _build() -> void:
	var ground := ColorRect.new()
	ground.color = GameConfig.INTRO_GROUND
	ground.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ground.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ground)

	var art := TextureRect.new()
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.texture = _cover_art()
	art.visible = art.texture != null
	add_child(art)

	# A gradient rather than a flat scrim: the top stays legible for the title
	# and the art stays visible near the horizon, where the game's subject is.
	#
	# The bottom stop is heavy on purpose. The illustration's brightest area is
	# the lit road, which is exactly where the action list sits — at 0.78 the
	# secondary items washed out against it and only the amber CONTINUE was
	# comfortably readable. Text over art needs its own ground, not the art's.
	#
	# The 0.68 stop is what the action list actually stands on. Sampling the
	# rendered menu, the four off-white rows measured 6-7.6:1 there but the
	# brass CONTINUE — the one row that matters most — came in at 4.1:1, under
	# the 4.5:1 floor, because brass is simply darker than off-white and was
	# being asked to carry the same ground. Deepening the band under the list
	# fixes the primary row without touching the palette, and costs nothing:
	# the art's subject is the houses and the horizon, not the asphalt.
	var grad := Gradient.new()
	grad.set_color(0, Color(0.05, 0.05, 0.05, 0.86))
	grad.add_point(0.42, Color(0.05, 0.05, 0.05, 0.18))
	grad.add_point(0.60, Color(0.04, 0.04, 0.05, 0.72))
	grad.add_point(0.68, Color(0.03, 0.03, 0.04, 0.90))
	grad.set_color(grad.get_point_count() - 1, Color(0.03, 0.03, 0.04, 0.95))
	var grad_tex := GradientTexture2D.new()
	grad_tex.gradient = grad
	grad_tex.fill_from = Vector2(0.0, 0.0)
	grad_tex.fill_to = Vector2(0.0, 1.0)
	var scrim := TextureRect.new()
	scrim.texture = grad_tex
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scrim.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(scrim)

	# A cover carries its own title — it is the whole point of a cover — so the
	# menu stops drawing a second one over it. On the fallback street art,
	# which has no lettering, the drawn title is still the only title there is.
	var title := Label.new()
	title.visible = not _has_cover
	title.text = tr("MENU_TITLE")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	title.offset_top = 220.0
	title.offset_bottom = 420.0
	title.offset_left = 60.0
	title.offset_right = -60.0
	title.add_theme_font_size_override("font_size", GameConfig.UI_DISPLAY)
	title.add_theme_color_override("font_color", GameConfig.UI_INK)
	title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	title.add_theme_constant_override("shadow_offset_y", 3)
	add_child(title)

	var sub := Label.new()
	sub.text = tr("MENU_SUBTITLE")
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	sub.offset_top = 340.0
	sub.offset_bottom = 400.0
	sub.add_theme_font_size_override("font_size", GameConfig.UI_LABEL)
	sub.visible = not _has_cover
	sub.add_theme_color_override("font_color", GameConfig.UI_INK_SOFT)
	add_child(sub)

	var rows := VBoxContainer.new()
	rows.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	rows.offset_left = 90.0
	rows.offset_right = -90.0
	rows.offset_top = -760.0
	rows.offset_bottom = -120.0
	rows.add_theme_constant_override("separation", GameConfig.UI_GAP_TIGHT)
	add_child(rows)

	var has_progress := GameState.has_progress()
	if has_progress:
		rows.add_child(_action(tr("MENU_CONTINUE"), true,
			func() -> void: continue_pressed.emit()))
	rows.add_child(_action(
		tr("MENU_NEW_GAME") if has_progress else tr("MENU_PLAY"),
		not has_progress,
		func() -> void: _on_new_game_pressed(has_progress)))
	if has_progress:
		rows.add_child(_action(tr("MENU_JOURNAL"), false,
			func() -> void: journal_pressed.emit()))
	rows.add_child(_action(tr("MENU_SETTINGS"), false,
		func() -> void: settings_pressed.emit()))
	# Quitting is a desktop convention; iOS treats a self-quit button as broken
	# behaviour and Apple's review guidelines say so directly, so it only
	# appears on platforms where a player expects it.
	if not OS.has_feature("mobile"):
		rows.add_child(_action(tr("MENU_QUIT"), false,
			func() -> void: get_tree().quit()))

	var version := Label.new()
	version.text = "v%s" % str(ProjectSettings.get_setting(
		"application/config/version", "1.0.0"))
	version.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	version.offset_left = -160.0
	version.offset_top = -56.0
	version.offset_right = -30.0
	version.offset_bottom = -20.0
	version.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	version.add_theme_font_size_override("font_size", GameConfig.UI_MICRO)
	version.add_theme_color_override("font_color", GameConfig.UI_INK_FAINT)
	add_child(version)


## The cover, picked for the shape of the screen.
##
## Drop either or both of these in and they are used automatically:
##
##     textures/menu/cover_portrait.(png|jpg|webp)   phones
##     textures/menu/cover_wide.(png|jpg|webp)       desktop, Steam
##
## The art is drawn STRETCH_KEEP_ASPECT_COVERED, so it always fills the screen
## and the overflow is cropped rather than letterboxed. That is why the two
## shapes are worth having: this game's phone viewport is 1170x2532, an aspect
## of 0.46, and a 4:5 cover is 0.80 — covering that screen scales it to the
## height and throws away about two fifths of its width, a fifth off each side.
## Keep anything that must survive — a title, a face — inside the middle three
## fifths, or supply a taller crop.
##
## With neither file present this falls back to the opening card's golden-hour
## street, which is what the menu shipped with: quiet, warm, already the game's
## tone, and no new art to make.
## True once _cover_art has found a real cover rather than the intro fallback.
## Set before the title is built, which is the only reason the order in _build
## matters.
var _has_cover := false


func _cover_art() -> Texture2D:
	var rect := get_viewport_rect().size
	var wide := rect.x >= rect.y
	for name in (["menu/cover_wide", "menu/cover_portrait"] if wide
			else ["menu/cover_portrait", "menu/cover_wide"]):
		var found := TextureLibrary.find(name)
		if found != null:
			_has_cover = true
			return found
	return TextureLibrary.find("intro/intro_1")


## A plain-text row, not a card: the menu's whole point is that these five
## actions do not need a box each to read as important. `primary` picks the one
## action every player's eye should land on first.
func _action(label_text: String, primary: bool, on_press: Callable) -> Button:
	var button := Button.new()
	button.text = label_text
	button.custom_minimum_size = Vector2(0, GameConfig.UI_TAP_MIN)
	button.flat = true
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.add_theme_font_size_override("font_size",
		GameConfig.UI_TITLE if primary else GameConfig.UI_HEAD)
	var ink: Color = GameConfig.CASE_ACCENT if primary else Color(0.94, 0.92, 0.87)
	var dim := ink
	dim.a = 0.72
	for state in ["font_color", "font_focus_color"]:
		button.add_theme_color_override(state, ink)
	for state in ["font_hover_color", "font_pressed_color"]:
		button.add_theme_color_override(state, dim)
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	button.pressed.connect(func() -> void:
		Haptics.light()
		on_press.call())
	return button


func _on_new_game_pressed(had_progress: bool) -> void:
	if not had_progress:
		new_game_pressed.emit()
		return
	# Destructive, and irreversible the moment it runs — this erases whatever
	# is on the device. A tap that quiet gets a confirmation, the same way the
	# rest of the app never deletes anything without asking first.
	_show_confirm()


func _show_confirm() -> void:
	if _confirm != null and is_instance_valid(_confirm):
		return
	_confirm = PanelContainer.new()
	_confirm.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var scrim := ColorRect.new()
	scrim.color = Color(0.02, 0.02, 0.02, 0.72)
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	_confirm.add_child(scrim)

	var card := PanelContainer.new()
	card.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	card.offset_left = -300.0
	card.offset_right = 300.0
	card.offset_top = -220.0
	card.offset_bottom = 220.0
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.10, 0.09, 0.08, 0.98)
	style.border_color = GameConfig.CASE_ACCENT
	style.set_border_width_all(2)
	style.set_corner_radius_all(18)
	style.set_content_margin_all(32)
	card.add_theme_stylebox_override("panel", style)
	_confirm.add_child(card)

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
		_confirm.queue_free())
	rows.add_child(cancel)

	var confirm_btn := Button.new()
	confirm_btn.text = tr("MENU_NEW_GAME_CONFIRM_ACTION")
	confirm_btn.custom_minimum_size = Vector2(0, GameConfig.UI_TAP_MIN)
	HubScreen.style_primary(confirm_btn)
	confirm_btn.pressed.connect(func() -> void:
		Haptics.medium()
		new_game_pressed.emit())
	rows.add_child(confirm_btn)

	add_child(_confirm)
