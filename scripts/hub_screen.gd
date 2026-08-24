class_name HubScreen
extends Control
## G8 community hub: the screen the player returns to between searches.
##
## 2D only — no 3D navigation. A full-screen portrait illustration with three
## tappable cards over it, plus two panels that slide in over the same
## background: the case board (chapter selection) and the town (NPC chatter).
##
## Chapter selection emits `chapter_chosen(variant_id)`. It deliberately carries
## an ID, never a scene path: G9 builds every chapter from ONE game scene plus
## variant data, so "one .tscn per chapter" must never become an assumption
## anywhere in this flow.

## The player picked a chapter to search; the argument is a story.json
## chapters[].variant_id.
signal chapter_chosen(variant_id: String)

const PANEL_FADE := 0.22

var _background: TextureRect
var _tiles_page: Control
var _board_page: Control
var _town_page: Control
var _progress_label: Label
var _dialogue: DialogueBox


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_background()
	_build_top_bar()
	_tiles_page = _build_tiles()
	_board_page = _build_board()
	_town_page = _build_town()
	add_child(_tiles_page)
	add_child(_board_page)
	add_child(_town_page)
	_show_page(_tiles_page)


# ---------------------------------------------------------------- chrome

func _build_background() -> void:
	# Warm gradient ground, used as the fallback and as the letterbox behind an
	# illustration that does not match the screen aspect.
	var ground := TextureRect.new()
	ground.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ground.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ground.stretch_mode = TextureRect.STRETCH_SCALE
	ground.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var grad := Gradient.new()
	grad.set_color(0, Color(0.32, 0.22, 0.14))
	grad.set_color(1, Color(0.10, 0.09, 0.08))
	var grad_tex := GradientTexture2D.new()
	grad_tex.gradient = grad
	grad_tex.fill_from = Vector2(0.0, 0.0)
	grad_tex.fill_to = Vector2(0.0, 1.0)
	ground.texture = grad_tex
	add_child(ground)

	_background = TextureRect.new()
	_background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var art := Story.raw("hub.background", "hub/town_square")
	var tex := TextureLibrary.find(art)
	_background.texture = tex
	_background.visible = tex != null
	if tex == null:
		TextureLibrary.warn_missing(art, "hub arkaplani = sicak degrade")
	add_child(_background)

	# Darkens the top and bottom so the bar and the cards stay readable over art.
	var scrim := TextureRect.new()
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scrim.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	scrim.stretch_mode = TextureRect.STRETCH_SCALE
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sg := Gradient.new()
	sg.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
	# Light touch: the illustration already has its own vignette, and stacking a
	# heavy scrim on top turned the whole square muddy.
	sg.colors = PackedColorArray([
		Color(0, 0, 0, 0.46), Color(0, 0, 0, 0.06), Color(0, 0, 0, 0.62)])
	var sg_tex := GradientTexture2D.new()
	sg_tex.gradient = sg
	sg_tex.fill_from = Vector2(0.0, 0.0)
	sg_tex.fill_to = Vector2(0.0, 1.0)
	scrim.texture = sg_tex
	add_child(scrim)


func _build_top_bar() -> void:
	var bar := VBoxContainer.new()
	bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	bar.offset_left = 60
	bar.offset_right = -60
	bar.offset_top = 70
	bar.offset_bottom = 240
	bar.add_theme_constant_override("separation", 10)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bar)

	var title := Label.new()
	title.text = Story.text("case.title")
	title.add_theme_font_size_override("font_size", 52)
	title.add_theme_color_override("font_color", Color(0.96, 0.95, 0.92))
	title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	title.add_theme_constant_override("shadow_offset_y", 4)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(title)

	_progress_label = Label.new()
	_progress_label.add_theme_font_size_override("font_size", 34)
	_progress_label.add_theme_color_override("font_color", GameConfig.CASE_ACCENT)
	_progress_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(_progress_label)
	_refresh_progress()


func _refresh_progress() -> void:
	_progress_label.text = Story.text("hub.progress").format({
		"case": Story.text("case.id"),
		"done": ChapterProgress.done_count(),
		"total": ChapterProgress.count()})


# ---------------------------------------------------------------- pages

func _new_page() -> Control:
	var page := Control.new()
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return page


func _show_page(page: Control) -> void:
	for candidate in [_tiles_page, _board_page, _town_page]:
		if candidate == null:
			continue
		candidate.visible = candidate == page
	if page != _tiles_page:
		page.modulate.a = 0.0
		var tw := create_tween()
		tw.tween_property(page, "modulate:a", 1.0, PANEL_FADE)
	_refresh_progress()


## The three hub cards. A locked card is still shown and still responds, because
## a visible locked door tells the player the game is bigger than this screen.
func _build_tiles() -> Control:
	var page := _new_page()
	var column := VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.offset_left = 60
	column.offset_right = -60
	# Low on the screen: the art's subject is mid-frame, and cards parked over it
	# hid the whole square.
	column.anchor_top = 0.54
	column.offset_top = 0
	column.offset_bottom = -110
	column.alignment = BoxContainer.ALIGNMENT_END
	column.add_theme_constant_override("separation", 28)
	page.add_child(column)

	for tile: Dictionary in Story.list("hub.tiles"):
		column.add_child(_make_tile(tile))
	return page


## Buttons over an illustration need an explicit ground: the default theme's
## button is nearly transparent and reads as a smudge rather than a card.
func _style_card(button: Button, dim := false) -> void:
	var base := StyleBoxFlat.new()
	base.bg_color = Color(0.07, 0.07, 0.065, 0.90 if not dim else 0.80)
	base.set_corner_radius_all(24)
	base.set_content_margin_all(26)
	base.border_color = Color(GameConfig.CASE_ACCENT, 0.42 if not dim else 0.18)
	base.set_border_width_all(3)
	base.shadow_color = Color(0, 0, 0, 0.45)
	base.shadow_size = 10
	button.add_theme_stylebox_override("normal", base)
	var pressed := base.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.13, 0.12, 0.10, 0.95)
	pressed.border_color = Color(GameConfig.CASE_ACCENT, 0.75)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("hover", pressed)
	button.add_theme_stylebox_override("focus", base)


func _make_tile(tile: Dictionary) -> Button:
	var locked := bool(tile.get("locked", false))
	var button := Button.new()
	button.custom_minimum_size = Vector2(0, 190)
	button.add_theme_font_size_override("font_size", 46)
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# The tile dictionary carries the keys directly, so translate them here.
	var hint := tr(str(tile.get("hint", ""))) if not locked \
		else Story.text("hub.locked_note")
	button.text = "%s  %s\n%s" % [str(tile.get("icon", "")),
		tr(str(tile.get("label", ""))), hint]
	if locked:
		button.add_theme_color_override("font_color", Color(0.66, 0.66, 0.62))
	_style_card(button, locked)
	var id := str(tile.get("id", ""))
	button.pressed.connect(_on_tile.bind(id, locked, button))
	return button


func _on_tile(id: String, locked: bool, button: Button) -> void:
	if locked:
		Haptics.light()
		_shake(button)
		return
	Haptics.light()
	match id:
		"case_board":
			_show_page(_board_page)
		"town":
			_show_page(_town_page)
		_:
			_shake(button)


func _shake(control: Control) -> void:
	var home := control.position
	var tw := create_tween()
	for offset: float in [16.0, -12.0, 8.0, -4.0, 0.0]:
		tw.tween_property(control, "position", home + Vector2(offset, 0.0), 0.055)
	tw.tween_callback(func() -> void: control.position = home)


# ---------------------------------------------------------------- case board

func _build_board() -> Control:
	var page := _new_page()
	# A calm ground behind the list: eight card rows straight over the
	# illustration left the art showing through every gap and read as noise.
	page.add_child(_list_backdrop())

	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.offset_left = 50
	scroll.offset_right = -50
	scroll.offset_top = 280
	scroll.offset_bottom = -190
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	page.add_child(scroll)

	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 22)
	column.name = "Chapters"
	scroll.add_child(column)

	var heading := Label.new()
	heading.text = Story.text("case_board.title")
	heading.add_theme_font_size_override("font_size", 40)
	heading.add_theme_color_override("font_color", GameConfig.CASE_ACCENT)
	column.add_child(heading)

	page.add_child(_back_button())
	page.set_meta("column", column)
	return page


## Rebuilt on every entry, so a chapter finished in this session shows as done
## without a hub reload.
func _refresh_board() -> void:
	var column: VBoxContainer = _board_page.get_meta("column")
	for child in column.get_children():
		if child is Button:
			child.queue_free()
	var current := ChapterProgress.current_variant_id()
	for chapter: Dictionary in ChapterProgress.chapters():
		column.add_child(_make_chapter_row(chapter, current))


func _make_chapter_row(chapter: Dictionary, current: String) -> Button:
	var id := str(chapter.get("variant_id", ""))
	var playable := bool(chapter.get("playable", false))
	var done := ChapterProgress.is_done(id)
	var mark := "🔒"
	var state := Story.text("case_board.locked")
	if done:
		mark = "✓"
		state = Story.text("case_board.done")
	elif playable and id == current:
		mark = "►"
		state = Story.text("case_board.active")

	var button := Button.new()
	button.custom_minimum_size = Vector2(0, 150)
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.add_theme_font_size_override("font_size", 38)
	var evidence := Story.text("case_board.evidence").format({
		"found": ChapterProgress.evidence_found(id),
		"total": ChapterProgress.evidence_total(id)})
	button.text = "%s  %s\n%s · %s" % [mark, tr(str(chapter.get("name", ""))),
		state, evidence]
	if not playable:
		button.add_theme_color_override("font_color", Color(0.64, 0.65, 0.61))
	_style_card(button, not playable)
	button.pressed.connect(_on_chapter.bind(id, playable, button))
	return button


func _on_chapter(variant_id: String, playable: bool, button: Button) -> void:
	Haptics.light()
	if not playable:
		_shake(button)
		return
	chapter_chosen.emit(variant_id)


# ---------------------------------------------------------------- town

func _build_town() -> Control:
	var page := _new_page()
	page.add_child(_list_backdrop())
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.offset_left = 50
	scroll.offset_right = -50
	scroll.offset_top = 280
	scroll.offset_bottom = -190
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	page.add_child(scroll)

	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 20)
	scroll.add_child(column)

	var heading := Label.new()
	heading.text = Story.text("town.title")
	heading.add_theme_font_size_override("font_size", 40)
	heading.add_theme_color_override("font_color", GameConfig.CASE_ACCENT)
	column.add_child(heading)

	for person: Dictionary in Story.list("town.people"):
		column.add_child(_make_person_row(person))

	page.add_child(_back_button())
	return page


func _make_person_row(person: Dictionary) -> Button:
	var id := str(person.get("id", ""))
	var button := Button.new()
	button.custom_minimum_size = Vector2(0, 150)
	button.add_theme_font_size_override("font_size", 38)
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# The square face crop generated by tools/crop_faces.gd — the town list wants
	# a face, while the dialogue box uses the full-figure source.
	var face := TextureLibrary.find("portraits/face_" + id)
	if face != null:
		button.icon = face
		button.expand_icon = true
		button.add_theme_constant_override("h_separation", 26)
	button.text = "%s\n%s" % [tr(str(person.get("name", ""))),
		tr(str(person.get("role", "")))]
	_style_card(button)
	button.pressed.connect(_on_person.bind(id))
	return button


func _on_person(person_id: String) -> void:
	if _dialogue != null and is_instance_valid(_dialogue):
		return
	Haptics.light()
	var lines := Dialogue.town_lines(person_id, ChapterProgress.done_count())
	if lines.is_empty():
		return
	_dialogue = DialogueBox.new()
	add_child(_dialogue)
	_dialogue.finished.connect(func() -> void: _dialogue = null)
	_dialogue.play(lines)


# ---------------------------------------------------------------- shared

## Dark rounded ground covering the list area, so a long list of rows reads as
## one panel instead of stripes over the artwork.
func _list_backdrop() -> Panel:
	var panel := Panel.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 30
	panel.offset_right = -30
	panel.offset_top = 250
	panel.offset_bottom = -170
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.05, 0.045, 0.82)
	style.set_corner_radius_all(30)
	style.border_color = Color(GameConfig.CASE_ACCENT, 0.22)
	style.set_border_width_all(2)
	panel.add_theme_stylebox_override("panel", style)
	return panel


func _back_button() -> Button:
	var back := Button.new()
	back.text = tr("UI_BACK")
	back.add_theme_font_size_override("font_size", 40)
	_style_card(back)
	back.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	back.offset_left = 60
	back.offset_right = -60
	back.offset_top = -160
	back.offset_bottom = -60
	back.pressed.connect(func() -> void:
		Haptics.light()
		_show_page(_tiles_page))
	return back


## Called by the flow controller when the hub becomes visible again, so progress
## made in a chapter shows up immediately.
func refresh() -> void:
	_refresh_progress()
	_refresh_board()
	_show_page(_tiles_page)
