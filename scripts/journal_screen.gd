class_name JournalScreen
extends Control
## The Journal (UI/UX redesign, Phase 3).
##
## "Yankılar" was a hub tile whose name told the player nothing about what was
## behind it, and it held one flat list. The redesign brief asks for a named
## hierarchy instead — CASE NOTES / DISCOVERIES / ECHOES — so the three kinds
## of thing the player collects stop being one undifferentiated pile.
##
## Every section reads from data that already existed; nothing new is stored:
##   CASE NOTES  the Marshal's per-chapter deduction (story.json board pins)
##   DISCOVERIES the evidence found, per chapter, across both cases
##   ECHOES      the world-history finds (EchoLog)
##
## Built as its own screen rather than as a fourth hub page so the main menu can
## open it without the hub existing at all.

signal closed()

enum Section { NOTES, DISCOVERIES, ECHOES, ALBUM, RECORDS }

var _section: Section = Section.NOTES
var _tabs: HBoxContainer
var _list: VBoxContainer
var _counter: Label
## Linking two discoveries (G48): the piece waiting for a partner, and the
## line the Marshal answers with.
var _picked := ""
var _picked_row: Control
var _answer: Label
var _answer_card: PanelContainer


func _ready() -> void:
	LocaleSupport.apply()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()
	_refresh()


func _build() -> void:
	var backdrop := ColorRect.new()
	backdrop.color = GameConfig.UI_BG
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)

	var header := Label.new()
	header.name = "JournalHeader"
	# The whole journal's fill, as a number the player can watch grow (G31).
	header.text = "%s · %s" % [tr("JOURNAL_TITLE"),
		tr("JOURNAL_PERCENT").format({"percent": completion_percent()})]
	header.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	header.offset_top = 96.0
	header.offset_bottom = 180.0
	header.offset_left = 60.0
	header.offset_right = -160.0
	header.add_theme_font_size_override("font_size", GameConfig.UI_TITLE)
	header.add_theme_color_override("font_color", GameConfig.UI_INK)
	add_child(header)
	GameConfig.fit_wide(header)

	_counter = Label.new()
	_counter.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_counter.offset_top = 178.0
	_counter.offset_bottom = 232.0
	_counter.offset_left = 60.0
	_counter.offset_right = -160.0
	_counter.add_theme_font_size_override("font_size", GameConfig.UI_LABEL)
	_counter.add_theme_color_override("font_color", GameConfig.UI_BRASS_DEEP)
	add_child(_counter)
	GameConfig.fit_wide(_counter)

	var close := Button.new()
	close.text = "×"
	close.flat = true
	close.custom_minimum_size = Vector2(GameConfig.UI_TAP_MIN, GameConfig.UI_TAP_MIN)
	close.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	close.offset_left = -float(GameConfig.UI_TAP_MIN) - 30.0
	close.offset_top = 90.0
	close.add_theme_font_size_override("font_size", GameConfig.UI_TITLE)
	close.add_theme_color_override("font_color", GameConfig.UI_INK_SOFT)
	close.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	close.pressed.connect(func() -> void:
		Haptics.light()
		closed.emit())
	add_child(close)

	# The Marshal's answer, on its own ground at the foot of the page. It needs
	# both the background and the z_index: the list of slips is a full-rect
	# scroll added after this, so a bare label was drawn UNDER the entries
	# (seen in out/deduction_made.png).
	_answer_card = PanelContainer.new()
	_answer_card.name = "LinkAnswerCard"
	var card := StyleBoxFlat.new()
	card.bg_color = Color(0.07, 0.07, 0.06, 0.97)
	card.border_color = GameConfig.UI_BRASS
	card.set_border_width_all(2)
	card.set_corner_radius_all(14)
	card.set_content_margin_all(GameConfig.UI_GAP)
	_answer_card.add_theme_stylebox_override("panel", card)
	_answer_card.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_answer_card.offset_left = 60
	_answer_card.offset_right = -60
	_answer_card.offset_top = -210
	_answer_card.offset_bottom = -40
	_answer_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_answer_card.z_index = 20
	_answer_card.visible = false
	add_child(_answer_card)
	GameConfig.fit_wide(_answer_card)

	_answer = Label.new()
	_answer.name = "LinkAnswer"
	_answer.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_answer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_answer.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_answer.add_theme_font_size_override("font_size", GameConfig.UI_BODY)
	_answer.add_theme_color_override("font_color", GameConfig.UI_BRASS)
	_answer.add_theme_constant_override("line_spacing", 8)
	_answer_card.add_child(_answer)

	_tabs = HBoxContainer.new()
	_tabs.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_tabs.offset_top = 268.0
	_tabs.offset_bottom = 268.0 + float(GameConfig.UI_TAP_MIN)
	_tabs.offset_left = 60.0
	_tabs.offset_right = -60.0
	_tabs.add_theme_constant_override("separation", GameConfig.UI_GAP_TIGHT)
	add_child(_tabs)
	for spec in [[Section.NOTES, "JOURNAL_TAB_NOTES"],
			[Section.DISCOVERIES, "JOURNAL_TAB_DISCOVERIES"],
			[Section.ECHOES, "JOURNAL_TAB_ECHOES"],
			[Section.ALBUM, "JOURNAL_TAB_ALBUM"],
			[Section.RECORDS, "JOURNAL_TAB_RECORDS"]]:
		var tab := Button.new()
		tab.text = tr(str(spec[1]))
		tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tab.custom_minimum_size = Vector2(0, GameConfig.UI_TAP_MIN)
		tab.add_theme_font_size_override("font_size", GameConfig.UI_BODY)
		tab.focus_mode = Control.FOCUS_NONE
		var which: Section = spec[0]
		tab.set_meta("section", int(which))
		tab.pressed.connect(func() -> void:
			Haptics.light()
			_section = which
			# The Marshal's answer belongs to the tap that asked for it, not to
			# the screen: changing tab puts it away. Cleared HERE rather than
			# in _refresh, which runs right after an answer is given (G48).
			_say("")
			_refresh())
		_tabs.add_child(tab)

	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.offset_left = 60
	scroll.offset_right = -60
	scroll.offset_top = 268.0 + float(GameConfig.UI_TAP_MIN) + GameConfig.UI_GAP_WIDE
	scroll.offset_bottom = -60
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	GameConfig.fit_wide(scroll)
	DragScroll.attach(self, scroll)

	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", GameConfig.UI_GAP_WIDE)
	scroll.add_child(_list)


## Notes written, evidence found, echoes found and postcards kept, over what
## the whole game holds of each — one percentage for the header.
static func completion_percent() -> int:
	var found := 0
	var total := 0
	for pin: Dictionary in Story.list("board.pins"):
		if str(pin.get("note", "")) == "":
			continue
		total += 1
		if ChapterProgress.is_done(str(pin.get("chapter", ""))):
			found += 1
	for chapter: Dictionary in ChapterProgress.chapters():
		var vid := str(chapter.get("variant_id", ""))
		var variant := LevelVariant.of(vid)
		total += variant.evidence_count()
		found += mini(ChapterProgress.evidence_found(vid), variant.evidence_count())
		if not variant.echo_info().is_empty():
			total += 1
			if EchoLog.is_found(vid):
				found += 1
		total += 1
		if Postcard.has(vid):
			found += 1
	for vid: String in GameConfig.HARVEST_VARIANTS:
		total += 1
		if Postcard.has(vid):
			found += 1
	if total == 0:
		return 0
	return int(round(100.0 * float(found) / float(total)))


func _refresh() -> void:
	for tab in _tabs.get_children():
		var button := tab as Button
		if button != null:
			HubScreen._style_tab(button, int(button.get_meta("section", -1)) == int(_section))
	_clear_pick()
	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	match _section:
		Section.NOTES:
			_fill_notes()
		Section.DISCOVERIES:
			_fill_discoveries()
		Section.ECHOES:
			_fill_echoes()
		Section.ALBUM:
			_fill_album()
		Section.RECORDS:
			_fill_records()


## What the Marshal wrote down after each finished chapter. A chapter that is
## not finished is not listed at all rather than shown as a locked row: an
## empty journal that grows is a better promise than a full one that is greyed.
func _fill_notes() -> void:
	var written := 0
	for pin: Dictionary in Story.list("board.pins"):
		var vid := str(pin.get("chapter", ""))
		var note_key := str(pin.get("note", ""))
		if note_key == "" or not ChapterProgress.is_done(vid):
			continue
		written += 1
		_list.add_child(_entry(
			tr(str(ChapterProgress.entry(vid).get("name", ""))),
			tr(note_key), written))
	var deductions: Array = DeductionLog.made_links()
	if not deductions.is_empty():
		_list.add_child(_group(tr("LINK_HEADER")))
		var n := 0
		for any: Variant in deductions:
			var link: Dictionary = any
			n += 1
			written += 1
			_list.add_child(_entry("%s + %s" % [
				DeductionLog.name_of(str(link.get("a", ""))),
				DeductionLog.name_of(str(link.get("b", "")))],
				tr(str(link.get("note", ""))), n))
	_counter.text = tr("JOURNAL_NOTES_COUNT").format({"count": written})
	if written == 0:
		_list.add_child(_empty_note(tr("JOURNAL_NOTES_EMPTY")))


## Every piece of evidence the player is actually holding, grouped by chapter,
## across both cases.
func _fill_discoveries() -> void:
	var found := 0
	var total := 0
	# The whole tutorial for the mechanic, in one line at the top (G48).
	_list.add_child(_empty_note(tr("LINK_HINT")))
	for chapter: Dictionary in ChapterProgress.chapters():
		var vid := str(chapter.get("variant_id", ""))
		var variant := LevelVariant.of(vid)
		var have := ChapterProgress.evidence_found(vid)
		total += variant.evidence_count()
		# The chapter heading is written only once something under it exists,
		# so the list never opens with a run of empty titles.
		var headed := false
		var in_chapter := 0
		for slot in variant.evidence_count():
			if slot >= have:
				continue
			if not headed:
				headed = true
				_list.add_child(_group(tr(str(chapter.get("name", "")))))
			found += 1
			in_chapter += 1
			var info := variant.evidence_info(slot)
			var row := _entry(str(info.get("name", "")),
				str(info.get("line", "")), in_chapter)
			_make_pickable(row, DeductionLog.piece(vid, str(info.get("id", ""))))
			_list.add_child(row)
	_counter.text = "%s · %s" % [
		tr("JOURNAL_DISCOVERIES_COUNT").format({"found": found, "total": total}),
		tr("LINK_COUNT").format({"done": DeductionLog.made_count(),
			"total": DeductionLog.total()})]
	if found == 0:
		_list.add_child(_empty_note(tr("JOURNAL_DISCOVERIES_EMPTY")))


func _fill_echoes() -> void:
	var found := 0
	for chapter: Dictionary in ChapterProgress.chapters():
		var vid := str(chapter.get("variant_id", ""))
		var info := LevelVariant.of(vid).echo_info()
		if info.is_empty() or not EchoLog.is_found(vid):
			continue
		found += 1
		_list.add_child(_entry(str(info.get("name", "")),
			str(info.get("line", "")), found))
	_counter.text = tr("JOURNAL_ECHOES_COUNT").format(
		{"found": found, "total": EchoLog.total()})
	if found == 0:
		_list.add_child(_empty_note(Story.text("echoes.empty")))


## A heading over a run of entries — which chapter they came out of. Drawn as a
## label over a hairline rather than as another panel, so the eye reads it as a
## divider in a notebook and not as one more card in a stack.
## The records (G33): what has been done, dated, then what has not, greyed,
## each with the sentence that says what it is. Opening the tab also checks
## the list, so a record earned outside a yard (the dog's name) appears.
func _fill_records() -> void:
	Achievements.evaluate()
	var earned: Array[String] = []
	var open: Array[String] = []
	for id in Achievements.ids():
		if Achievements.is_earned(id):
			earned.append(id)
		else:
			open.append(id)
	_counter.text = tr("JOURNAL_RECORDS_COUNT").format(
		{"done": earned.size(), "total": Achievements.ids().size()})
	var index := 0
	for id in earned:
		index += 1
		_list.add_child(_entry(tr(Achievements.name_key(id)),
			"%s · %s" % [tr(Achievements.line_key(id)), Achievements.earned_on(id)], index))
	if not open.is_empty():
		_list.add_child(_group(tr("JOURNAL_RECORDS_OPEN")))
	for id in open:
		index += 1
		var row := _entry(tr(Achievements.name_key(id)), tr(Achievements.line_key(id)), index)
		row.modulate = Color(1, 1, 1, 0.55)
		_list.add_child(row)


## The postcards (G27): every finished yard's photograph, newest first, two to
## a row, each one tappable to see it whole. The empty album says what fills it.
func _fill_album() -> void:
	var cards := Postcard.all()
	_counter.text = tr("JOURNAL_ALBUM_COUNT").format({"count": cards.size()})
	if cards.is_empty():
		_list.add_child(_empty_note(tr("JOURNAL_ALBUM_EMPTY")))
		return
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", GameConfig.UI_GAP)
	grid.add_theme_constant_override("v_separation", GameConfig.UI_GAP)
	_list.add_child(grid)
	var cell_w := (GameConfig.UI_MAX_WIDTH - 120.0 - float(GameConfig.UI_GAP)) * 0.5
	for card: Dictionary in cards:
		var tex := Postcard.load_texture(str(card["path"]))
		if tex == null:
			continue
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", GameConfig.UI_GAP_TIGHT)
		var thumb := TextureButton.new()
		thumb.texture_normal = tex
		thumb.ignore_texture_size = true
		thumb.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		thumb.custom_minimum_size = Vector2(cell_w,
			cell_w * float(Postcard.CARD.y) / float(Postcard.CARD.x))
		var path := str(card["path"])
		thumb.pressed.connect(func() -> void:
			Haptics.light()
			var view := PostcardView.new()
			add_child(view)
			view.setup(tex, path))
		box.add_child(thumb)
		var caption := Label.new()
		caption.text = Postcard.title_for(str(card["id"]))
		caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		caption.add_theme_font_size_override("font_size", GameConfig.UI_LABEL)
		caption.add_theme_color_override("font_color", GameConfig.UI_INK_SOFT)
		box.add_child(caption)
		grid.add_child(box)


## A discovery answers a tap. The button covers its whole slip rather than
## replacing it, so the entry keeps the look every other list has.
func _make_pickable(row: Control, id: String) -> void:
	var hit := Button.new()
	hit.name = DeductionLog.node_name(id)
	hit.flat = true
	hit.focus_mode = Control.FOCUS_NONE
	hit.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hit.pressed.connect(func() -> void: _pick(id, row))
	row.add_child(hit)


## First tap holds a piece, second tap asks the question. Tapping the same
## piece again puts it down — a player who changes their mind should not have
## to make a wrong pair to get out of it.
func _pick(id: String, row: Control) -> void:
	Haptics.light()
	if _picked == id:
		_clear_pick()
		return
	if _picked == "":
		_picked = id
		_picked_row = row
		_mark_pick(row, true)
		_say("")
		return
	var first := _picked
	_clear_pick()
	_ask(first, id)


## The Marshal's answer to a pair. A confirmed link is written down once; a
## wrong one costs nothing but a flat sentence, and the sentence rotates so it
## does not read as one canned buzzer.
func _ask(a: String, b: String) -> void:
	var link := DeductionLog.find_link(a, b)
	if link.is_empty():
		_say(tr("LINK_NO_%d" % (randi() % 3 + 1)))
		return
	if DeductionLog.is_made(a, b):
		_say(tr("LINK_ALREADY"))
		return
	DeductionLog.make(a, b)
	Haptics.success()
	Analytics.track(AnalyticsEvents.DEDUCTION_MADE, {"link": str(link.get("note", ""))})
	_say(tr(str(link.get("note", ""))))
	# The counter in the header moves, and the deduction is now in the notes.
	_refresh()


func _mark_pick(row: Control, on: bool) -> void:
	if row == null or not is_instance_valid(row):
		return
	var panel := row as PanelContainer
	if panel == null:
		return
	var style := panel.get_theme_stylebox("panel") as StyleBoxFlat
	if style == null:
		return
	var copy := style.duplicate() as StyleBoxFlat
	copy.border_width_left = 18 if on else 6
	copy.bg_color = GameConfig.UI_SURFACE_RAISED if on else GameConfig.UI_SURFACE
	panel.add_theme_stylebox_override("panel", copy)


func _clear_pick() -> void:
	if _picked_row != null:
		_mark_pick(_picked_row, false)
	_picked = ""
	_picked_row = null


func _say(line: String) -> void:
	if _answer == null or not is_instance_valid(_answer):
		return
	_answer.text = line
	if _answer_card != null and is_instance_valid(_answer_card):
		_answer_card.visible = line != ""


func _group(title: String) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", GameConfig.UI_GAP_TIGHT)
	var label := Label.new()
	label.text = title.to_upper()
	label.add_theme_font_size_override("font_size", GameConfig.UI_LABEL)
	label.add_theme_color_override("font_color", GameConfig.UI_BRASS_DEEP)
	box.add_child(label)
	var rule := ColorRect.new()
	rule.color = GameConfig.UI_LINE
	rule.custom_minimum_size = Vector2(0, 2)
	box.add_child(rule)
	return box


## One journal entry: an index in the margin, a title, and the sentence under
## it — a slip out of a case file rather than a card in a feed.
##
## The first version gave every entry an even rounded border, and thirty of
## them in a column read as a settings list. What carries the look now is a
## brass rule down the left edge, the way a ruled margin runs down a notebook
## page, with the corners nearly square: aged paper does not have a 12px
## radius. The index number is not decoration either — it is the one cue that
## survives when colour does not, so an entry stays countable and locatable for
## a player who cannot tell the brass from the ink.
func _entry(title: String, body: String, index: int) -> Control:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = GameConfig.UI_SURFACE
	style.set_corner_radius_all(4)
	style.set_content_margin_all(GameConfig.UI_GAP_WIDE)
	style.content_margin_left = GameConfig.UI_GAP_WIDE + 8
	# The margin rule: a border on one edge only.
	style.border_color = GameConfig.UI_BRASS
	style.border_width_left = 6
	panel.add_theme_stylebox_override("panel", style)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", GameConfig.UI_GAP)
	panel.add_child(row)

	var number := Label.new()
	number.text = "%02d" % index
	number.custom_minimum_size = Vector2(78, 0)
	number.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	number.add_theme_font_size_override("font_size", GameConfig.UI_HEAD)
	number.add_theme_color_override("font_color", GameConfig.UI_BRASS_DEEP)
	row.add_child(number)

	var rows := VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation", GameConfig.UI_GAP_TIGHT)
	row.add_child(rows)

	var title_label := Label.new()
	title_label.text = title
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_label.add_theme_font_size_override("font_size", GameConfig.UI_HEAD)
	title_label.add_theme_color_override("font_color", GameConfig.UI_BRASS)
	rows.add_child(title_label)

	var body_label := Label.new()
	body_label.text = body
	body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body_label.add_theme_font_size_override("font_size", GameConfig.UI_BODY)
	body_label.add_theme_color_override("font_color", GameConfig.UI_INK)
	# Prose, not a label: a little air between lines is most of the difference
	# between a paragraph you read and one you skip.
	body_label.add_theme_constant_override("line_spacing", 10)
	rows.add_child(body_label)
	return panel


func _empty_note(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", GameConfig.UI_BODY)
	label.add_theme_color_override("font_color", GameConfig.UI_INK_SOFT)
	label.add_theme_constant_override("line_spacing", 10)
	return label
