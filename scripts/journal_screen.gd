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

enum Section { NOTES, DISCOVERIES, ECHOES }

var _section: Section = Section.NOTES
var _tabs: HBoxContainer
var _list: VBoxContainer
var _counter: Label


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
	header.text = tr("JOURNAL_TITLE")
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
			[Section.ECHOES, "JOURNAL_TAB_ECHOES"]]:
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
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", GameConfig.UI_GAP_WIDE)
	scroll.add_child(_list)


func _refresh() -> void:
	for tab in _tabs.get_children():
		var button := tab as Button
		if button != null:
			HubScreen._style_tab(button, int(button.get_meta("section", -1)) == int(_section))
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
	_counter.text = tr("JOURNAL_NOTES_COUNT").format({"count": written})
	if written == 0:
		_list.add_child(_empty_note(tr("JOURNAL_NOTES_EMPTY")))


## Every piece of evidence the player is actually holding, grouped by chapter,
## across both cases.
func _fill_discoveries() -> void:
	var found := 0
	var total := 0
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
			_list.add_child(_entry(str(info.get("name", "")),
				str(info.get("line", "")), in_chapter))
	_counter.text = tr("JOURNAL_DISCOVERIES_COUNT").format(
		{"found": found, "total": total})
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
