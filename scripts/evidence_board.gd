class_name EvidenceBoard
extends Control
## The detective corkboard (G10). Every found piece of evidence hangs as a
## pinned card at its authored board position; unfound ones are empty
## silhouettes with a "?". Red string runs BETWEEN CHAPTERS the player has
## completed — the game draws the connections, never the player (the fantasy
## layer rule), and each string carries the Marshal's one-line deduction.
##
## Layout comes from data/story.json "board": fractional positions, so the same
## data fits every screen. Drawing order: cork, strings (_draw), cards, notes.

const CARD_SIZE := Vector2(190, 150)

var _cork: Control
var _cards_layer: Control
## Strings need their own layer: a Control's _draw renders UNDER its children,
## so drawing on the board itself put the thread beneath the cork.
var _strings: Control
var _pin_points: Array[Vector2] = []   # per chapter: midpoint between its cards


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_cork()
	_strings = Control.new()
	_strings.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_strings.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_strings.draw.connect(_draw_strings)
	add_child(_strings)
	_cards_layer = Control.new()
	_cards_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_cards_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Strings draw on THIS control (under the cards layer added after).
	add_child(_cards_layer)
	refresh()


func _build_cork() -> void:
	_cork = Control.new()
	_cork.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_cork.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_cork)
	var art := TextureLibrary.find("hub/corkboard")
	if art != null:
		var rect := TextureRect.new()
		rect.texture = art
		rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_cork.add_child(rect)
		return
	TextureLibrary.warn_missing("hub/corkboard", "pano = kahve zemin")
	var ground := ColorRect.new()
	ground.color = Color(0.42, 0.30, 0.20)
	ground.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_cork.add_child(ground)
	# A darker frame edge so the fallback still reads as a BOARD.
	var frame := ReferenceRect.new()
	frame.border_color = Color(0.24, 0.16, 0.10)
	frame.border_width = 14.0
	frame.editor_only = false
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_cork.add_child(frame)


func refresh() -> void:
	for child in _cards_layer.get_children():
		child.queue_free()
	_pin_points.clear()
	var pins := Story.list("board.pins")
	for pin: Dictionary in pins:
		_place_chapter(pin)
	# The finished case: Ellie's card in the middle once B8 is done.
	if not pins.is_empty() and ChapterProgress.is_done(
			str((pins.back() as Dictionary).get("chapter", ""))):
		_place_finale()
	_strings.queue_redraw()


func _place_chapter(pin: Dictionary) -> void:
	var chapter_id := str(pin.get("chapter", ""))
	var variant := LevelVariant.of(chapter_id)
	var found := ChapterProgress.evidence_found(chapter_id)
	var at_a := _at(float(pin.get("x", 0.5)), float(pin.get("y", 0.5)))
	var at_b := _at(float(pin.get("x2", 0.5)), float(pin.get("y2", 0.5)))
	_pin_points.append((at_a + at_b) * 0.5 + CARD_SIZE * 0.5)
	for slot in 2:
		var info := variant.evidence_info(slot)
		var at := at_a if slot == 0 else at_b
		_cards_layer.add_child(_make_card(info, slot < found, at))
		_cards_layer.add_child(_pin_head(at))
	# The Marshal's note under the chapter's cards, once it is done.
	var note_key := str(pin.get("note", ""))
	if note_key != "" and ChapterProgress.is_done(chapter_id):
		var note := _make_note(tr(note_key))
		note.position = (at_a + at_b) * 0.5 + Vector2(-40, CARD_SIZE.y + 8)
		_cards_layer.add_child(note)


func _make_card(info: Dictionary, found: bool, at: Vector2) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = CARD_SIZE
	card.position = at
	card.rotation = deg_to_rad(randf_range(-4.0, 4.0))
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.93, 0.90, 0.82) if found else Color(0.55, 0.48, 0.40, 0.75)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(12)
	style.shadow_color = Color(0, 0, 0, 0.4)
	style.shadow_size = 6
	card.add_theme_stylebox_override("panel", style)

	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 2)
	card.add_child(rows)
	var icon := Label.new()
	icon.text = str(info.get("emoji", "?")) if found else tr("BOARD_UNKNOWN")
	icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon.add_theme_font_size_override("font_size", 52)
	rows.add_child(icon)
	var name_label := Label.new()
	name_label.text = str(info.get("name", "")) if found else "———"
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.add_theme_font_size_override("font_size", 24)
	name_label.add_theme_color_override("font_color",
		Color(0.15, 0.13, 0.10) if found else Color(0.32, 0.28, 0.24))
	rows.add_child(name_label)
	return card


## PanelContainer stretches its children, so the pin head is a sibling laid over
## the card's top edge rather than a child inside it.
func _pin_head(at: Vector2) -> ColorRect:
	var pin_dot := ColorRect.new()
	pin_dot.color = Color(0.75, 0.15, 0.12)
	pin_dot.size = Vector2(16, 16)
	pin_dot.position = at + Vector2(CARD_SIZE.x * 0.5 - 8.0, -6.0)
	pin_dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return pin_dot


func _make_note(text: String) -> Label:
	var note := Label.new()
	note.text = text
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.custom_minimum_size = Vector2(CARD_SIZE.x * 2.4, 0)
	note.add_theme_font_size_override("font_size", 24)
	note.add_theme_color_override("font_color", Color(0.96, 0.93, 0.85))
	note.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	note.add_theme_constant_override("shadow_offset_y", 2)
	note.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return note


func _place_finale() -> void:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(260, 220)
	card.position = _at(0.5, 0.42) - Vector2(35, 35)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.95, 0.92, 0.84)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(14)
	style.shadow_color = Color(0, 0, 0, 0.5)
	style.shadow_size = 10
	card.add_theme_stylebox_override("panel", style)
	var rows := VBoxContainer.new()
	card.add_child(rows)
	var face := TextureRect.new()
	face.custom_minimum_size = Vector2(0, 150)
	face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	var art := TextureLibrary.find("hub/case2_teaser")
	face.texture = art if art != null else TextureLibrary.find("portraits/face_ellie")
	rows.add_child(face)
	var final_note := _make_note(Story.text("board.final_note"))
	final_note.position = card.position + Vector2(-60, 240)
	_cards_layer.add_child(card)
	_cards_layer.add_child(final_note)


func _at(fx: float, fy: float) -> Vector2:
	# Positions are fractions of the usable board (under the top bar, above the
	# back button), minus the card so nothing hangs off the right edge.
	var top := 260.0
	var bottom := size.y - 200.0
	return Vector2(fx * (size.x - CARD_SIZE.x - 60.0) + 30.0,
		top + fy * (bottom - top - CARD_SIZE.y))


## The red string: chapter N's midpoint to N+1's, drawn with a lazy sag so it
## reads as thread rather than a diagram edge. Only for completed chapters.
func _draw_strings() -> void:
	var pins := Story.list("board.pins")
	for i in range(1, pins.size()):
		var prev_id := str((pins[i - 1] as Dictionary).get("chapter", ""))
		var this_id := str((pins[i] as Dictionary).get("chapter", ""))
		if not (ChapterProgress.is_done(prev_id) and ChapterProgress.is_done(this_id)):
			continue
		if i - 1 >= _pin_points.size() or i >= _pin_points.size():
			continue
		var a := _pin_points[i - 1]
		var b := _pin_points[i]
		var points := PackedVector2Array()
		for step in 17:
			var t := float(step) / 16.0
			var sag := sin(t * PI) * 26.0
			points.append(a.lerp(b, t) + Vector2(0.0, sag))
		_strings.draw_polyline(points, Color(0.78, 0.12, 0.10, 0.9), 4.0, true)
