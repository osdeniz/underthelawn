class_name MarshalPage
extends Control
## The page the Marshal writes when a case closes (G52).
##
## Every case ended on a picture — Ellie home, the convoy, the gate — and then
## the player was back at the board with nothing in their hand saying what the
## case had actually amounted to. This is that: a leaf out of his own book,
## dated, in his handwriting, listing what was found and every deduction the
## player worked out for themselves, in the sentences they earned.
##
## Nothing here is generated prose. The head and the closing line are written
## per case; the middle is the player's own deductions, which is exactly why
## the page is worth having — two players who closed the same case do not read
## the same page.

signal finished()

const FADE := 0.4
const MARGIN := 90


var case_key := "case_01"

var _paper: TextureRect
var _lines: VBoxContainer
var _hint: Label
var _fade: ColorRect
var _typer := Typewriter.new()
var _lock := 0.0


## `case_key` is "case_01" / "case_02" / "case_03"; the layer is the caller's.
static func open(parent: Node, key: String) -> MarshalPage:
	var page := MarshalPage.new()
	page.name = "MarshalPage"
	page.case_key = key
	parent.add_child(page)
	return page


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	_fill()


func _build() -> void:
	var ground := ColorRect.new()
	ground.color = GameConfig.INTRO_GROUND
	ground.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ground.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ground)

	# The same sheet the postcards are mounted on, so his book and the album
	# are made of one paper.
	_paper = TextureRect.new()
	_paper.name = "Paper"
	_paper.texture = MapArt.parchment(512, 3301)
	_paper.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_paper.stretch_mode = TextureRect.STRETCH_SCALE
	_paper.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_paper.offset_left = 40
	_paper.offset_right = -40
	_paper.offset_top = 150
	_paper.offset_bottom = -150
	_paper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_paper)
	GameConfig.fit_wide(_paper)

	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.offset_left = MARGIN
	scroll.offset_right = -MARGIN
	scroll.offset_top = 230
	scroll.offset_bottom = -230
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	GameConfig.fit_wide(scroll)

	_lines = VBoxContainer.new()
	_lines.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lines.add_theme_constant_override("separation", GameConfig.UI_GAP_WIDE)
	scroll.add_child(_lines)

	_hint = Label.new()
	_hint.text = Story.text("intro.skip_hint", "tap to continue")
	_hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_hint.offset_top = -120
	_hint.offset_bottom = -50
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.add_theme_font_size_override("font_size", 30)
	_hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.45))
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint.visible = false
	add_child(_hint)

	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 1)
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fade)
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 0.0, FADE)


## The page, in order: whose file it is, what was found, what was worked out,
## and one line to close it.
func _fill() -> void:
	var ink := Color(0.20, 0.15, 0.09)
	var typed: Array = []
	typed.append(_write("%s — %s" % [tr(case_key.to_upper() + "_ID"),
		tr(case_key.to_upper() + "_TITLE")], 46, GameConfig.MAP_PARCHMENT_DARK.darkened(0.35), true))
	typed.append(_write(tr("PAGE_DATED").format(
		{"date": Time.get_date_string_from_system()}), 28, ink.lightened(0.35), false))
	typed.append(_write(tr("PAGE_FOUND").format({
		"found": _evidence_found(), "total": _evidence_total(),
		"yards": _yards_done()}), 34, ink, false))

	var made := _case_deductions()
	if made.is_empty():
		typed.append(_write(tr("PAGE_NO_LINKS"), 34, ink, false))
	else:
		typed.append(_write(tr("PAGE_LINKS"), 28,
			GameConfig.MAP_PARCHMENT_DARK.darkened(0.2), false))
		for any: Variant in made:
			var link: Dictionary = any
			typed.append(_write("— " + tr(str(link.get("note", ""))), 32, ink, false))
	typed.append(_write(DogName.fill(tr(case_key.to_upper() + "_PAGE_CLOSE")), 34,
		ink, false))
	typed.append(_write(tr("PAGE_SIGNED"), 30, ink.lightened(0.2), false))
	_typer.play(typed, FADE)


func _write(text: String, size: int, colour: Color, heading: bool) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", GameConfig.fs(size))
	label.add_theme_color_override("font_color", colour)
	label.add_theme_constant_override("line_spacing", 8)
	if heading:
		label.add_theme_constant_override("line_spacing", 2)
	_lines.add_child(label)
	return label


## The chapters of this case, from the story file rather than from the spelling
## of a chapter id.
func _chapters() -> Array:
	if case_key == "case_01":
		return Story.list("chapters")
	return Story.list(case_key + ".chapters")


func _evidence_found() -> int:
	var n := 0
	for any: Variant in _chapters():
		var vid := str((any as Dictionary).get("variant_id", ""))
		n += mini(ChapterProgress.evidence_found(vid),
			LevelVariant.of(vid).evidence_count())
	return n


func _evidence_total() -> int:
	var n := 0
	for any: Variant in _chapters():
		n += LevelVariant.of(str((any as Dictionary).get("variant_id", ""))).evidence_count()
	return n


func _yards_done() -> int:
	var n := 0
	for any: Variant in _chapters():
		if ChapterProgress.is_done(str((any as Dictionary).get("variant_id", ""))):
			n += 1
	return n


## Only this case's deductions: a link is keyed by chapter, so the case a link
## belongs to is the case its chapters belong to (G48.1 keeps them from ever
## crossing).
func _case_deductions() -> Array:
	var mine := {}
	for any: Variant in _chapters():
		mine[str((any as Dictionary).get("variant_id", ""))] = true
	var out: Array = []
	for any: Variant in DeductionLog.made_links():
		var link: Dictionary = any
		if mine.has(DeductionLog.chapter_of(str(link.get("a", "")))):
			out.append(link)
	return out


func _process(delta: float) -> void:
	_lock = maxf(_lock - delta, 0.0)
	_typer.advance(delta)
	_hint.visible = not _typer.typing()


func _gui_input(event: InputEvent) -> void:
	if _lock > 0.0:
		return
	var pressed := event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed
	var clicked := event is InputEventMouseButton and (event as InputEventMouseButton).pressed
	if not (pressed or clicked):
		return
	accept_event()
	if _typer.typing():
		# The page is his handwriting: the first tap finishes it, the second
		# closes the book. The same two taps every card in the game asks for.
		_typer.finish()
		_lock = 0.35
		return
	_close()


func _close() -> void:
	set_process(false)
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 1.0, FADE)
	tw.tween_callback(func() -> void:
		finished.emit()
		queue_free())
