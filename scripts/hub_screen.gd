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
## Replay the opening cards (the STORY button moved here from the game HUD).
signal replay_intro_requested()

const PANEL_FADE := 0.22


## Shared button styles for every hub-family page (workshop, board): filled
## accent for the one action that spends or progresses, dark card for the rest.
static func style_primary(button: Button) -> void:
	var base := StyleBoxFlat.new()
	base.bg_color = Color(0.72, 0.58, 0.24)
	base.set_corner_radius_all(20)
	base.set_content_margin_all(22)
	button.add_theme_stylebox_override("normal", base)
	var pressed := base.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.88, 0.72, 0.34)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("hover", pressed)
	button.add_theme_stylebox_override("focus", base)
	for state in ["font_color", "font_pressed_color", "font_hover_color"]:
		button.add_theme_color_override(state, Color(0.08, 0.07, 0.05))


## A tab always states its own name clearly; only its GROUND changes. Styling
## the inactive tab as a dark card made its label unreadable over the artwork.
static func _style_tab(tab: Button, active: bool) -> void:
	var base := StyleBoxFlat.new()
	base.bg_color = Color(0.76, 0.62, 0.26) if active \
		else Color(0.16, 0.16, 0.15, 0.95)
	base.set_corner_radius_all(18)
	base.set_content_margin_all(18)
	base.border_color = Color(GameConfig.CASE_ACCENT, 0.9 if active else 0.35)
	base.set_border_width_all(3)
	for state in ["normal", "hover", "pressed", "focus"]:
		tab.add_theme_stylebox_override(state, base)
	var ink := Color(0.08, 0.07, 0.05) if active else Color(0.94, 0.92, 0.86)
	for state in ["font_color", "font_hover_color", "font_pressed_color"]:
		tab.add_theme_color_override(state, ink)


static func style_secondary(button: Button) -> void:
	var base := StyleBoxFlat.new()
	base.bg_color = Color(0.10, 0.10, 0.09, 0.94)
	base.set_corner_radius_all(20)
	base.set_content_margin_all(22)
	base.border_color = Color(GameConfig.CASE_ACCENT, 0.40)
	base.set_border_width_all(2)
	button.add_theme_stylebox_override("normal", base)
	var pressed := base.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.17, 0.15, 0.11, 0.97)
	pressed.border_color = Color(GameConfig.CASE_ACCENT, 0.8)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("hover", pressed)
	button.add_theme_stylebox_override("focus", base)

var _background: TextureRect
var _tiles_page: Control
var _board_page: Control
var _town_page: Control
var _workshop_page: WorkshopPage
var _board_view: EvidenceBoard
var _board_scroll: ScrollContainer
var _board_tab_places: Button
var _board_tab_evidence: Button
var _scrap_label: Label
var _restore_page: Control
var _echoes_page: Control
var _restore_list: VBoxContainer
var _echo_list: VBoxContainer
var _restore_note: Label
var _tier2_announced := false
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
	_workshop_page = _build_workshop()
	_restore_page = _build_restore()
	_echoes_page = _build_echoes()
	add_child(_tiles_page)
	add_child(_board_page)
	add_child(_town_page)
	add_child(_workshop_page)
	add_child(_restore_page)
	add_child(_echoes_page)
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


## Two columns, not three stacked rows: the case identity on the left, the
## wallet as its own chip on the right. Stacking title + progress + money
## overflowed the panel, because three lines of that type simply do not fit a
## bar this tall — and growing the bar would eat the artwork instead.
func _build_top_bar() -> void:
	# PanelContainer, NOT Panel: a plain Panel does not lay out its children, so
	# the row collapsed to its own width and the wallet clung to the title.
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	panel.offset_left = 30
	panel.offset_right = -30
	panel.offset_top = 76
	panel.offset_bottom = 236
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.04, 0.05, 0.04, 0.70)
	panel_style.set_corner_radius_all(26)
	panel_style.content_margin_left = 30.0
	panel_style.content_margin_right = 22.0
	panel_style.content_margin_top = 18.0
	panel_style.content_margin_bottom = 18.0
	panel.add_theme_stylebox_override("panel", panel_style)
	add_child(panel)

	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 20)
	columns.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(columns)

	var identity := VBoxContainer.new()
	identity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	identity.alignment = BoxContainer.ALIGNMENT_CENTER
	identity.add_theme_constant_override("separation", 4)
	identity.mouse_filter = Control.MOUSE_FILTER_IGNORE
	columns.add_child(identity)

	var title := Label.new()
	title.text = Story.text("case.title")
	title.add_theme_font_size_override("font_size", 46)
	title.add_theme_color_override("font_color", Color(0.96, 0.95, 0.92))
	title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	title.add_theme_constant_override("shadow_offset_y", 3)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	identity.add_child(title)

	_progress_label = Label.new()
	_progress_label.add_theme_font_size_override("font_size", 30)
	_progress_label.add_theme_color_override("font_color", GameConfig.CASE_ACCENT)
	_progress_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	identity.add_child(_progress_label)

	# The wallet reads as a thing you own, so it gets its own chip.
	var wallet := PanelContainer.new()
	wallet.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	wallet.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var chip := StyleBoxFlat.new()
	chip.bg_color = Color(0.09, 0.16, 0.09, 0.92)
	chip.set_corner_radius_all(18)
	chip.content_margin_left = 22.0
	chip.content_margin_right = 22.0
	chip.content_margin_top = 12.0
	chip.content_margin_bottom = 12.0
	chip.border_color = Color(0.40, 0.78, 0.42, 0.55)
	chip.set_border_width_all(2)
	wallet.add_theme_stylebox_override("panel", chip)
	columns.add_child(wallet)

	_scrap_label = Label.new()
	_scrap_label.add_theme_font_size_override("font_size", 40)
	_scrap_label.add_theme_color_override("font_color", Color(0.62, 0.95, 0.60))
	_scrap_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_scrap_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wallet.add_child(_scrap_label)
	_refresh_progress()


func _refresh_progress() -> void:
	_progress_label.text = Story.text("hub.progress").format({
		"case": Story.text("case.id"),
		"done": ChapterProgress.done_count(),
		"total": ChapterProgress.count()})
	_scrap_label.text = "%s %d" % [GameConfig.SCRAP_ICON, GameState.scrap_total()]


# ---------------------------------------------------------------- pages

func _new_page() -> Control:
	var page := Control.new()
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return page


func _show_page(page: Control) -> void:
	for candidate in [_tiles_page, _board_page, _town_page, _workshop_page,
			_restore_page, _echoes_page]:
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
	column.anchor_top = 0.52
	column.offset_top = 0
	column.offset_bottom = -110
	column.alignment = BoxContainer.ALIGNMENT_END
	column.add_theme_constant_override("separation", 28)
	page.add_child(column)

	for tile: Dictionary in Story.list("hub.tiles"):
		column.add_child(_make_tile(tile))
	page.set_meta("column", column)

	var story := Button.new()
	story.text = tr("UI_STORY")
	story.custom_minimum_size = Vector2(0, 110)
	story.add_theme_font_size_override("font_size", 34)
	story.add_theme_color_override("font_color", Color(0.8, 0.8, 0.76))
	_style_card(story, true)
	story.pressed.connect(func() -> void:
		Haptics.light()
		replay_intro_requested.emit())
	column.add_child(story)
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
	var label := tr(str(tile.get("label", "")))
	var icon := str(tile.get("icon", ""))
	# G12.7: once the station is built, the case screens live in it and the card
	# says so. Grouping, not a new screen — the chapter list and the corkboard
	# are already two tabs behind this one door.
	if str(tile.get("id", "")) == "case_board" and RestoreBoard.station_built():
		label = tr("HUB_STATION")
		hint = tr("HUB_STATION_HINT")
		icon = "🏛️"
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.text = "%s   %s\n%s" % [icon, label, hint]
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
			_rebuild_town()
			_show_page(_town_page)
		"workshop":
			_workshop_page.refresh()
			_show_page(_workshop_page)
		"restore":
			_refresh_restore()
			_show_page(_restore_page)
		"echoes":
			_refresh_echoes()
			_show_page(_echoes_page)
		_:
			_shake(button)


func _shake(control: Control) -> void:
	var home := control.position
	var tw := create_tween()
	for offset: float in [16.0, -12.0, 8.0, -4.0, 0.0]:
		tw.tween_property(control, "position", home + Vector2(offset, 0.0), 0.055)
	tw.tween_callback(func() -> void: control.position = home)


# ---------------------------------------------------------------- restore (G12.6)

## What the money is FOR once the workshop has what it needs. Deliberately a
## separate screen from the workshop: mixing "the tool I need" with "the thing I
## give back" would let one crowd out the other.
func _build_restore() -> Control:
	var page := _new_page()
	page.add_child(_list_backdrop(280.0))
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.offset_left = 50
	scroll.offset_right = -50
	scroll.offset_top = 300
	scroll.offset_bottom = -190
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	page.add_child(scroll)

	_restore_list = VBoxContainer.new()
	_restore_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_restore_list.add_theme_constant_override("separation", 20)
	scroll.add_child(_restore_list)
	page.add_child(_back_button())
	return page


func _refresh_restore() -> void:
	for child in _restore_list.get_children():
		child.queue_free()
	var heading := Label.new()
	heading.text = Story.text("restore.title")
	heading.add_theme_font_size_override("font_size", 40)
	heading.add_theme_color_override("font_color", GameConfig.CASE_ACCENT)
	_restore_list.add_child(heading)
	_restore_note = Label.new()
	_restore_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_restore_note.add_theme_font_size_override("font_size", 30)
	_restore_note.add_theme_color_override("font_color", Color(0.78, 0.76, 0.7))
	_restore_list.add_child(_restore_note)
	var tier2_shown := false
	for project: Dictionary in RestoreBoard.projects():
		if int(project.get("tier", 1)) >= 2 and not tier2_shown:
			tier2_shown = true
			var header := Label.new()
			header.text = tr("RESTORE_TIER2")
			header.add_theme_font_size_override("font_size", 34)
			header.add_theme_color_override("font_color",
				Color(0.86, 0.84, 0.78))
			_restore_list.add_child(header)
		_restore_list.add_child(_make_project_row(project))


func _make_project_row(project: Dictionary) -> Button:
	var id := str(project.get("id", ""))
	var built := RestoreBoard.is_built(id)
	var locked := RestoreBoard.is_locked(id)
	var cost := int(project.get("cost", 0))
	var button := Button.new()
	button.custom_minimum_size = Vector2(0, 190)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.add_theme_font_size_override("font_size", 38)
	var tail := tr("RESTORE_DONE") if built \
		else tr("RESTORE_BUY").format({"cost": cost})
	if locked and not built:
		# Locked doors stay priced and visible: that is what makes them a goal.
		tail = "🔒  %s   ·   %s" % [RestoreBoard.lock_reason(id),
			tr("RESTORE_BUY").format({"cost": cost})]
	var bonus := str(project.get("bonus_text", ""))
	if bonus == "":
		bonus = str(project.get("effect_text", ""))
	var extra := "\n%s" % tr(bonus) if bonus != "" else ""
	button.text = "%s\n%s%s\n%s" % [tr(str(project.get("name", ""))),
		tr(str(project.get("desc", ""))), extra, tail]
	if built:
		button.add_theme_color_override("font_color", Color(0.62, 0.86, 0.56))
		_style_card(button, true)
	elif locked:
		button.add_theme_color_override("font_color", Color(0.64, 0.65, 0.61))
		_style_card(button, true)
	else:
		_style_card(button)
	button.pressed.connect(_on_project.bind(id, built or locked, button))
	return button


func _on_project(project_id: String, built: bool, source: Button) -> void:
	Haptics.light()
	if built:
		return
	if RestoreBoard.is_locked(project_id):
		_restore_note.text = RestoreBoard.lock_reason(project_id)
		_shake(source)
		return
	var project := RestoreBoard.of(project_id)
	if GameState.scrap_total() < int(project.get("cost", 0)):
		_restore_note.text = Story.text("restore.locked_note")
		_shake(source)
		return
	if RestoreBoard.buy(project_id):
		AudioDirector.play_scrap()
		Haptics.success()
		_restore_note.text = tr(str(project.get("crumb", "")))
		if RestoreBoard.tier2_open() and not _tier2_announced:
			_tier2_announced = true
			Analytics.track("restore_tier2_unlocked", {})
		_refresh_restore()
		_refresh_progress()
		_apply_restore_layers()
		_refresh_tiles()


## Completed projects add a layer to the hub art; without the art file they add
## a small badge instead, so progress is always visible.
func _apply_restore_layers() -> void:
	for child in get_children():
		if child is Control and (child as Control).name.begins_with("Restore_"):
			child.queue_free()
	var badges := 0
	for project: Dictionary in RestoreBoard.projects():
		var id := str(project.get("id", ""))
		if not RestoreBoard.is_built(id):
			continue
		var art := TextureLibrary.find("hub/" + str(project.get("layer", "")))
		if art != null:
			var layer := TextureRect.new()
			layer.name = "Restore_" + id
			layer.texture = art
			layer.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			# KEEP_ASPECT, not COVERED: the layer must fit inside its authored
			# box, not fill it — covering would crop the building.
			layer.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
			layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var rect: Variant = project.get("layer_rect", null)
			if rect is Dictionary:
				var r := rect as Dictionary
				layer.set_anchors_preset(Control.PRESET_TOP_LEFT)
				layer.anchor_left = float(r.get("x", 0.0))
				layer.anchor_top = float(r.get("y", 0.0))
				layer.anchor_right = float(r.get("x", 0.0)) + float(r.get("w", 1.0))
				layer.anchor_bottom = float(r.get("y", 0.0)) + float(r.get("h", 1.0))
				layer.offset_left = 0
				layer.offset_top = 0
				layer.offset_right = 0
				layer.offset_bottom = 0
			else:
				layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			add_child(layer)
			move_child(layer, 2)
			continue
		var badge := Label.new()
		badge.name = "Restore_" + id
		badge.text = "🏘️"
		badge.add_theme_font_size_override("font_size", 44)
		badge.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
		badge.offset_left = -120 - badges * 64
		badge.offset_right = -60 - badges * 64
		badge.offset_top = 262
		badge.offset_bottom = 322
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(badge)
		badges += 1


# ---------------------------------------------------------------- echoes (G12.6)

func _build_echoes() -> Control:
	var page := _new_page()
	page.add_child(_list_backdrop(280.0))
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.offset_left = 50
	scroll.offset_right = -50
	scroll.offset_top = 300
	scroll.offset_bottom = -190
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	page.add_child(scroll)
	_echo_list = VBoxContainer.new()
	_echo_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_echo_list.add_theme_constant_override("separation", 18)
	scroll.add_child(_echo_list)
	page.add_child(_back_button())
	return page


## Found echoes are readable; the rest are blank slots, so the collection shows
## its own size without spoiling what is in it.
func _refresh_echoes() -> void:
	for child in _echo_list.get_children():
		child.queue_free()
	var heading := Label.new()
	heading.text = "%s   %d/%d" % [Story.text("echoes.title"),
		EchoLog.found_count(), EchoLog.total()]
	heading.add_theme_font_size_override("font_size", 40)
	heading.add_theme_color_override("font_color", GameConfig.CASE_ACCENT)
	_echo_list.add_child(heading)
	var sub := Label.new()
	sub.text = Story.text("echoes.header")
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub.add_theme_font_size_override("font_size", 30)
	sub.add_theme_color_override("font_color", Color(0.76, 0.74, 0.68))
	_echo_list.add_child(sub)

	if EchoLog.found_count() == 0:
		var empty := Label.new()
		empty.text = Story.text("echoes.empty")
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty.add_theme_font_size_override("font_size", 34)
		empty.add_theme_color_override("font_color", Color(0.66, 0.64, 0.6))
		_echo_list.add_child(empty)

	for chapter: Dictionary in ChapterProgress.chapters():
		var vid := str(chapter.get("variant_id", ""))
		var info := LevelVariant.of(vid).echo_info()
		if info.is_empty():
			continue
		var found := EchoLog.is_found(vid)
		var row := Label.new()
		row.custom_minimum_size = Vector2(0, 110)
		row.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.add_theme_font_size_override("font_size", 34)
		if found:
			row.text = "%s  %s\n%s" % [info["emoji"], info["name"], info["line"]]
			row.add_theme_color_override("font_color", Color(0.92, 0.90, 0.84))
		else:
			row.text = "·  ———"
			row.add_theme_color_override("font_color", Color(0.5, 0.5, 0.46))
		_echo_list.add_child(row)


# ---------------------------------------------------------------- workshop

func _build_workshop() -> Control:
	var page := WorkshopPage.new()
	page.visible = false
	page.purchased.connect(_refresh_progress)
	page.add_child(_back_button())
	return page


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
	scroll.offset_top = 376
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

	# G10: the detective corkboard lives behind a tab pair on the same page.
	# The corkboard is taller than the screen, so it scrolls (G12.10).
	_board_scroll = ScrollContainer.new()
	_board_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_board_scroll.offset_top = 366
	_board_scroll.offset_bottom = -190
	_board_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_board_scroll.visible = false
	page.add_child(_board_scroll)
	_board_view = EvidenceBoard.new()
	_board_scroll.add_child(_board_view)

	var tabs := HBoxContainer.new()
	tabs.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	tabs.offset_left = 50
	tabs.offset_right = -50
	tabs.offset_top = 272
	tabs.offset_bottom = 356
	tabs.add_theme_constant_override("separation", 18)
	page.add_child(tabs)
	_board_tab_places = Button.new()
	_board_tab_places.text = tr("BOARD_TAB_CHAPTERS")
	_board_tab_evidence = Button.new()
	_board_tab_evidence.text = tr("BOARD_TAB_EVIDENCE")
	for tab: Button in [_board_tab_places, _board_tab_evidence]:
		tab.add_theme_font_size_override("font_size", 34)
		tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tab.custom_minimum_size = Vector2(0, 84)
		tabs.add_child(tab)
	_board_tab_places.pressed.connect(func() -> void: _show_board_tab(false))
	_board_tab_evidence.pressed.connect(func() -> void: _show_board_tab(true))
	page.set_meta("scroll", scroll)

	page.add_child(_back_button())
	page.set_meta("column", column)
	return page


## Swaps between the chapter list and the corkboard, restyling the tab pair so
## the active one reads pressed.
func _show_board_tab(evidence: bool) -> void:
	Haptics.light()
	var scroll: Control = _board_page.get_meta("scroll")
	scroll.visible = not evidence
	_board_scroll.visible = evidence
	if evidence:
		_board_view.refresh()
	if _board_tab_evidence != null:
		_style_tab(_board_tab_places, not evidence)
		_style_tab(_board_tab_evidence, evidence)


## Opens the case board page directly on the corkboard (the case-notes button).
func open_evidence_board() -> void:
	_show_page(_board_page)
	_refresh_board()
	_show_board_tab(true)


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
		mark = "▶"
		state = Story.text("case_board.active")

	var button := Button.new()
	button.custom_minimum_size = Vector2(0, 162)
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.add_theme_font_size_override("font_size", 40)
	var evidence := Story.text("case_board.evidence").format({
		"found": ChapterProgress.evidence_found(id),
		"total": ChapterProgress.evidence_total(id)})
	button.text = "%s  %s\n%s · %s" % [mark, tr(str(chapter.get("name", ""))),
		state, evidence]
	if not playable:
		button.add_theme_color_override("font_color", Color(0.64, 0.65, 0.61))
	elif done:
		button.add_theme_color_override("font_color", Color(0.62, 0.86, 0.56))
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
	page.add_child(_list_backdrop(280.0))
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.offset_left = 50
	scroll.offset_right = -50
	scroll.offset_top = 300
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

	page.set_meta("column", column)
	page.add_child(_back_button())
	_town_page = page
	_rebuild_town()
	return page


## Rebuilt per visit: who is in town changes as the case moves.
func _rebuild_town() -> void:
	if _town_page == null:
		return
	var column: VBoxContainer = _town_page.get_meta("column")
	for child in column.get_children():
		if child is Button or child is PanelContainer:
			child.queue_free()
	# Ellie heads the page until she is found. She is not someone you can talk
	# to, so she is a poster rather than a person row — putting a missing child
	# in the list of neighbours to chat with read wrong (G12.10).
	if ChapterProgress.done_count() < GameConfig.ELLIE_FOUND_AFTER:
		column.add_child(_make_missing_card())
	for person: Dictionary in Story.list("town.people"):
		if ChapterProgress.done_count() < int(person.get("requires_done", 0)):
			continue
		column.add_child(_make_person_row(person))


## The MISSING poster for the town page: portrait, name, and how long she has
## been gone. Deliberately not a Button — there is nothing to press.
func _make_missing_card() -> PanelContainer:
	var frame := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = GameConfig.POSTER_BG
	style.border_color = GameConfig.CASE_ACCENT
	style.set_border_width_all(4)
	style.set_corner_radius_all(14)
	style.set_content_margin_all(22)
	frame.add_theme_stylebox_override("panel", style)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 26)
	frame.add_child(row)

	var face := TextureLibrary.find("portraits/face_ellie")
	if face != null:
		var picture := TextureRect.new()
		picture.texture = face
		picture.custom_minimum_size = Vector2(190, 190)
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		row.add_child(picture)

	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(text)
	for line: Array in [[tr("POSTER_MISSING"), 46, GameConfig.CASE_ACCENT],
			[tr("POSTER_NAME"), 52, Color.WHITE],
			[tr("POSTER_SINCE"), 34, GameConfig.CASE_MUTED]]:
		var label := Label.new()
		label.text = str(line[0])
		label.add_theme_font_size_override("font_size", int(line[1]))
		label.add_theme_color_override("font_color", line[2])
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text.add_child(label)
	return frame


func _make_person_row(person: Dictionary) -> Button:
	var id := str(person.get("id", ""))
	var button := Button.new()
	button.custom_minimum_size = Vector2(0, 168)
	# Portrait left, name and role left-aligned beside it: a centred label next
	# to a left-hand portrait reads as two unrelated elements.
	var face := TextureLibrary.find("portraits/face_" + id)
	if face != null:
		button.icon = face
		button.expand_icon = true
		button.add_theme_constant_override("h_separation", 30)
		button.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	# A badge per finished project for this person: whose life changed, at a
	# glance, without a second screen (G12.7).
	var badges := ""
	for project: Dictionary in RestoreBoard.projects_for(id):
		badges += " 🏠"
	button.text = "%s%s\n%s" % [tr(str(person.get("name", ""))), badges,
		tr(str(person.get("role", "")))]
	button.add_theme_font_size_override("font_size", 40)
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_style_card(button)
	button.pressed.connect(_on_person.bind(id))
	return button


func _on_person(person_id: String) -> void:
	if _dialogue != null and is_instance_valid(_dialogue):
		return
	Haptics.light()
	var lines := Dialogue.town_lines(person_id, ChapterProgress.done_count())
	# A finished project earns a permanent thank-you, appended after whatever
	# this character normally says (G12.6).
	var project := RestoreBoard.thanks_for(person_id)
	if not project.is_empty():
		lines = lines.duplicate()
		lines.append({"speaker": person_id,
			"text": str(project.get("thanks", ""))})
		lines.append({"speaker": person_id,
			"text": str(project.get("crumb", ""))})
	if lines.is_empty():
		return
	_dialogue = DialogueBox.new()
	add_child(_dialogue)
	_dialogue.finished.connect(func() -> void: _dialogue = null)
	_dialogue.play(lines)


# ---------------------------------------------------------------- shared

## Dark rounded ground covering the list area, so a long list of rows reads as
## one panel instead of stripes over the artwork.
func _list_backdrop(top := 346.0) -> Panel:
	var panel := Panel.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 30
	panel.offset_right = -30
	panel.offset_top = top
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
	_show_board_tab(false)
	_apply_restore_layers()
	_show_page(_tiles_page)


## Rebuilt when a project lands, so the STATION card renames itself the moment
## the station is finished rather than on the next hub visit.
func _refresh_tiles() -> void:
	if _tiles_page == null:
		return
	var column: VBoxContainer = _tiles_page.get_meta("column")
	for child in column.get_children():
		child.queue_free()
	for tile: Dictionary in Story.list("hub.tiles"):
		column.add_child(_make_tile(tile))
	var story := Button.new()
	story.text = tr("UI_STORY")
	story.custom_minimum_size = Vector2(0, 110)
	story.add_theme_font_size_override("font_size", 34)
	story.add_theme_color_override("font_color", Color(0.8, 0.8, 0.76))
	_style_card(story, true)
	story.pressed.connect(func() -> void:
		Haptics.light()
		replay_intro_requested.emit())
	column.add_child(story)
