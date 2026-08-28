class_name EvidenceBoard
extends VBoxContainer
## The detective corkboard — V2 (G13).
##
## WHAT CHANGED AND WHY. V1 pinned every card at an authored fractional position
## and then tried to fit the Marshal's notes into whatever space was left,
## dodging rectangles it had already claimed. That worked for eight chapters and
## one case. It could not survive eighteen: each note is a Label that wraps to as
## many lines as its sentence needs, so the amount of board a chapter occupies
## is not knowable until the text has been laid out, and the solver was
## effectively guessing. G12.10 was one bug from that guess; there would have
## been more.
##
## V2 has no solver. The board is a column of chapter blocks and the engine's own
## containers do the layout, which means the board is correct for any number of
## chapters with notes of any length, and it grows to whatever it needs instead
## of to a hand-tuned multiple of the screen. BOARD_SCALE is gone with it.
##
## What did NOT change: a card still renders the object itself rather than an
## emoji, unfound evidence is still a silhouette, and the clinic still buys
## Dr. Cole's reading of every find. The Marshal's own margin note is new beside
## it — the detective's take next to the doctor's.

## One evidence card. Wider than V1's because a card is now a column with its
## notes under it rather than a free-floating rectangle.
const CARD_WIDTH := 300.0
const ICON_VIEW := Vector2i(150, 150)
const BLOCK_GAP := 26.0

## Which case the board is showing. Chapters are only ever listed under the case
## they belong to, so the tabs are the only place the two can be confused.
var _case_index := 0
var _tabs: HBoxContainer
var _blocks: VBoxContainer
var _cork: Texture2D


func _ready() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", int(BLOCK_GAP))
	mouse_filter = Control.MOUSE_FILTER_PASS
	_cork = TextureLibrary.find("hub/corkboard")
	if _cork == null:
		TextureLibrary.warn_missing("hub/corkboard", "pano = kahve zemin")
	_tabs = HBoxContainer.new()
	_tabs.name = "CaseTabs"
	_tabs.add_theme_constant_override("separation", 12)
	add_child(_tabs)
	_blocks = VBoxContainer.new()
	_blocks.name = "Cards"
	_blocks.add_theme_constant_override("separation", int(BLOCK_GAP))
	_blocks.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(_blocks)
	refresh()


## The cork sheet and the red string, PAINTED rather than parented.
##
## Both were child Controls in the first pass, which is wrong for a container:
## a VBoxContainer lays out every child as a row, so the backdrop and the thread
## were given a slice of the column and collapsed to nothing. A Control's _draw
## renders under its children, which is exactly the layer they want.
func _draw() -> void:
	if _cork != null:
		draw_texture_rect(_cork, Rect2(Vector2.ZERO, size), true)
	else:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.42, 0.30, 0.20))
	_draw_thread()


## The cases that have anything on the board. Case 02 appears only once it is
## open, so a player still on Case 01 sees no tabs at all.
func _cases() -> Array:
	var out: Array = [{"path": "chapters", "title": "case.id"}]
	if ChapterProgress.case_two_open():
		out.append({"path": "case_02.chapters", "title": "case_02.id"})
	return out


func refresh() -> void:
	var cases := _cases()
	_case_index = clampi(_case_index, 0, cases.size() - 1)
	_build_tabs(cases)
	# remove_child before queue_free: queue_free defers to the end of the frame,
	# so a second refresh in the same frame laid a fresh set over the old one.
	for child in _blocks.get_children():
		_blocks.remove_child(child)
		child.queue_free()
	for chapter: Dictionary in Story.list(str(cases[_case_index]["path"])):
		_blocks.add_child(_build_block(chapter))
	queue_redraw()


func _build_tabs(cases: Array) -> void:
	for child in _tabs.get_children():
		_tabs.remove_child(child)
		child.queue_free()
	_tabs.visible = cases.size() > 1
	if not _tabs.visible:
		return
	for i in cases.size():
		var tab := Button.new()
		tab.text = Story.text(str(cases[i]["title"]))
		tab.custom_minimum_size = Vector2(0, 78)
		tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tab.add_theme_font_size_override("font_size", 32)
		tab.focus_mode = Control.FOCUS_NONE
		if i == _case_index:
			HubScreen.style_primary(tab)
		else:
			HubScreen.style_secondary(tab)
		var index := i
		tab.pressed.connect(func() -> void:
			Haptics.light()
			_case_index = index
			refresh())
		_tabs.add_child(tab)


## One chapter: its name, its two pieces of evidence side by side with their
## notes underneath, and the Marshal's deduction across the bottom.
func _build_block(chapter: Dictionary) -> PanelContainer:
	var vid := str(chapter.get("variant_id", ""))
	var variant := LevelVariant.of(vid)
	var found := ChapterProgress.evidence_found(vid)
	var done := ChapterProgress.is_done(vid)

	var block := PanelContainer.new()
	block.name = "Block_" + vid
	block.set_meta("chapter", vid)
	block.mouse_filter = Control.MOUSE_FILTER_PASS
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.30, 0.21, 0.14, 0.55) if done \
		else Color(0.24, 0.18, 0.13, 0.40)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(18)
	block.add_theme_stylebox_override("panel", style)

	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 12)
	block.add_child(rows)

	var header := Label.new()
	header.text = "%s   %s" % [tr(str(chapter.get("name", ""))),
		tr("MAP_STATE_DONE") if done else tr("MAP_STATE_LOCKED")]
	header.add_theme_font_size_override("font_size", 30)
	header.add_theme_color_override("font_color",
		Color(0.95, 0.90, 0.78) if done else Color(0.70, 0.64, 0.56))
	rows.add_child(header)

	var cards := HBoxContainer.new()
	cards.add_theme_constant_override("separation", 16)
	rows.add_child(cards)
	for slot in variant.evidence_count():
		cards.add_child(_build_card(variant.evidence_info(slot), slot < found))

	var note_key := str(chapter.get("note", ""))
	if done and note_key != "":
		rows.add_child(_build_note(tr(note_key)))
	return block


## One piece of evidence as a column: the object, its name, and — once the town
## has paid for them — the two readings of it.
func _build_card(info: Dictionary, found: bool) -> VBoxContainer:
	var column := VBoxContainer.new()
	column.custom_minimum_size = Vector2(CARD_WIDTH, 0)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 6)

	var card := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.93, 0.90, 0.82) if found \
		else Color(0.55, 0.48, 0.40, 0.75)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(12)
	style.shadow_color = Color(0, 0, 0, 0.4)
	style.shadow_size = 6
	card.add_theme_stylebox_override("panel", style)
	column.add_child(card)

	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 4)
	card.add_child(inner)
	# The object itself, not an emoji: iOS's default font has no emoji glyphs,
	# so every card icon was a blank box on a phone (G12.10).
	if found:
		var preview := ItemPreview.new()
		preview.view_size = ICON_VIEW
		preview.spin = false
		preview.custom_minimum_size = Vector2(0, 96)
		inner.add_child(preview)
		preview.show_item(str(info.get("id", "")))
	else:
		var unknown := Label.new()
		unknown.text = tr("BOARD_UNKNOWN")
		unknown.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		unknown.custom_minimum_size = Vector2(0, 96)
		unknown.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		unknown.add_theme_font_size_override("font_size", 46)
		unknown.add_theme_color_override("font_color", Color(0.32, 0.28, 0.24))
		inner.add_child(unknown)

	var name_label := Label.new()
	name_label.text = str(info.get("name", "")) if found else "———"
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.add_theme_font_size_override("font_size", 24)
	name_label.add_theme_color_override("font_color",
		Color(0.15, 0.13, 0.10) if found else Color(0.32, 0.28, 0.24))
	inner.add_child(name_label)

	if not found:
		return column
	# The Marshal reads it as a detective; the clinic buys the doctor's reading
	# beside it (G13.4). Two voices on one object is the whole point of a board.
	_add_reading(column, str(info.get("marshal_note", "")),
		Color(0.90, 0.84, 0.70), true)
	if RestoreBoard.is_built("clinic"):
		_add_reading(column, str(info.get("cole_note", "")),
			Color(0.72, 0.84, 0.94), false)
	return column


func _add_reading(column: VBoxContainer, key: String, colour: Color,
		marshal: bool) -> void:
	if key == "":
		return
	var label := Label.new()
	label.text = "%s %s" % ["—" if marshal else "·", tr(key)]
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 19)
	label.add_theme_color_override("font_color", colour)
	column.add_child(label)


## The Marshal's chapter deduction: a torn slip across the bottom of the block.
func _build_note(text: String) -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.95, 0.93, 0.84)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(14)
	style.shadow_color = Color(0, 0, 0, 0.35)
	style.shadow_size = 5
	panel.add_theme_stylebox_override("panel", style)
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_color_override("font_color", Color(0.16, 0.14, 0.11))
	panel.add_child(label)
	return panel


## The red string. In V1 it ran between free-positioned cards; here the blocks
## are a column, so it runs down the spine of the finished ones — the same
## meaning, and it cannot land on top of anything.
func _draw_thread() -> void:
	var points: Array[Vector2] = []
	for child in _blocks.get_children():
		var block := child as Control
		if block == null:
			continue
		if not ChapterProgress.is_done(str(block.get_meta("chapter", ""))):
			continue
		points.append(_blocks.position + block.position
			+ Vector2(16.0, block.size.y * 0.5))
	for i in points.size() - 1:
		draw_line(points[i], points[i + 1], GameConfig.BOARD_STRING, 5.0, true)
	for point in points:
		draw_circle(point, 8.0, GameConfig.BOARD_STRING)
