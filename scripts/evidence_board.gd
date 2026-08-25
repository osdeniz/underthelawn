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
## Breathing room around a pinned note, and how far it stays off the board edge.
const NOTE_GAP := 14.0
const NOTE_MARGIN := 28.0
## The board is taller than the screen and scrolls. Eight chapters of two cards
## plus a wrapped note plus the finale simply do not fit one portrait screen;
## squeezing them was what put the sentences on top of each other (G12.10).
const BOARD_SCALE := 2.5

var _cork: Control
var _cards_layer: Control
## Strings need their own layer: a Control's _draw renders UNDER its children,
## so drawing on the board itself put the thread beneath the cork.
var _strings: Control
var _pin_points: Array[Vector2] = []   # per chapter: midpoint between its cards
## Every card and note already placed, so a note can be pushed clear of them
## instead of landing on top (G12.10).
var _claimed: Array[Rect2] = []
## The height card positions are derived from. Fixed, so the board can grow to
## fit its notes without moving the cards on the next refresh.
var _layout_height := 0.0
## Likewise the width: inside a ScrollContainer the control has no size until
## the container lays it out, and refresh() runs before that.
var _layout_width := 0.0


func _ready() -> void:
	# Sized by its host ScrollContainer, not anchored to the screen.
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Whatever the host already gave us, else the screen: inside a
	# ScrollContainer the control still has no size at this point.
	var screen := get_viewport_rect().size
	_layout_width = size.x if size.x > 0.0 else screen.x
	_layout_height = maxf(size.y, screen.y * BOARD_SCALE)
	custom_minimum_size = Vector2(0.0, _layout_height)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_cork()
	_strings = Control.new()
	_strings.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_strings.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_strings.draw.connect(_draw_strings)
	add_child(_strings)
	_cards_layer = Control.new()
	_cards_layer.name = "Cards"
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
	# remove_child, not queue_free: queue_free defers to the end of the frame,
	# so a second refresh in the same frame (tab in, tab out) laid a fresh set
	# of cards over the old one and the solver counted both.
	for child in _cards_layer.get_children():
		_cards_layer.remove_child(child)
		child.queue_free()
	_pin_points.clear()
	_claimed.clear()
	var pins := Story.list("board.pins")
	# Two passes. Notes dodge whatever is already on the board, so every card
	# has to exist before the first note is positioned — a single pass let each
	# note dodge only the chapters above it and get landed on from below.
	for pin: Dictionary in pins:
		_place_chapter(pin)
	for pin: Dictionary in pins:
		_place_chapter_note(pin)
	# Last, so it can sit under everything the chapters claimed.
	if not pins.is_empty() and ChapterProgress.is_done(
			str((pins.back() as Dictionary).get("chapter", ""))):
		_place_finale()
	# Grow to whatever the notes actually needed. Card positions came from
	# _layout_height, so this cannot shift them on the next refresh.
	var needed := 0.0
	for taken: Rect2 in _claimed:
		needed = maxf(needed, taken.end.y)
	custom_minimum_size.y = maxf(_layout_height, needed + NOTE_MARGIN)
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
		var card := _make_card(info, slot < found, at)
		_cards_layer.add_child(card)
		_cards_layer.add_child(_pin_head(at))
		# A PanelContainer grows past custom_minimum_size when its label wraps,
		# so claim what the card will actually occupy, not CARD_SIZE.
		_claimed.append(Rect2(at, card.get_combined_minimum_size().max(CARD_SIZE)))



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


## The Marshal's note under a chapter's cards, once that chapter is done.
func _place_chapter_note(pin: Dictionary) -> void:
	var note_key := str(pin.get("note", ""))
	if note_key == "" or not ChapterProgress.is_done(str(pin.get("chapter", ""))):
		return
	var note := _make_note(tr(note_key))
	_cards_layer.add_child(note)
	_place_note(note,
		_at(float(pin.get("x", 0.5)), float(pin.get("y", 0.5))),
		_at(float(pin.get("x2", 0.5)), float(pin.get("y2", 0.5))))


## Places a note clear of everything already pinned, and inside the board.
##
## The board does not scroll, and the last chapters sit near the bottom edge, so
## "always below the cards" ran the final notes off the screen. Candidates are
## tried below first (it reads as a note pinned under its evidence), then above,
## and the first one that is both on the board and untouched wins.
func _place_note(note: Label, at_a: Vector2, at_b: Vector2) -> void:
	# The Label only knows its own height once it has laid its text out.
	note.size = Vector2(note.custom_minimum_size.x, 0.0)
	var height := note.get_combined_minimum_size().y
	note.size.y = height

	var width := note.custom_minimum_size.x
	var centre: float = (at_a.x + at_b.x) * 0.5 + CARD_SIZE.x * 0.5 - width * 0.5
	var below: float = maxf(at_a.y, at_b.y) + CARD_SIZE.y + NOTE_GAP
	var above: float = minf(at_a.y, at_b.y) - height - NOTE_GAP

	var best := Vector2(centre, below)
	var best_score := INF
	# Below reads best (a note pinned under its evidence), then above; each is
	# tried centred first and then shouldered aside, because on a board this
	# dense the vertical push alone runs out of room.
	for top_start: float in [below, above]:
		for nudge: float in [0.0, -width * 0.25, width * 0.25,
				-width * 0.5, width * 0.5, -width * 0.75, width * 0.75,
				-width, width]:
			var left := clampf(centre + nudge, NOTE_MARGIN,
				maxf(NOTE_MARGIN, _layout_width - width - NOTE_MARGIN))
			var top := top_start
			for _attempt in 12:
				var rect := Rect2(Vector2(left, top), Vector2(width, height))
				var hit := 0.0
				var pushed := top
				for taken: Rect2 in _claimed:
					var area := rect.intersection(taken).get_area()
					if area > 0.0:
						hit += area
						pushed = maxf(pushed, taken.end.y + NOTE_GAP)
				var off: bool = (top < NOTE_MARGIN
					or top + height > _layout_height - NOTE_MARGIN)
				var score := hit + (1.0e6 if off else 0.0)
				if score < best_score:
					best_score = score
					best = Vector2(left, clampf(top, NOTE_MARGIN,
						maxf(NOTE_MARGIN,
							_layout_height - height - NOTE_MARGIN)))
				if score <= 0.0 or pushed <= top:
					break
				top = pushed
			if best_score <= 0.0:
				break
		if best_score <= 0.0:
			break
	note.position = best
	# Claimed with its gap included, so the next note keeps its distance instead
	# of coming to rest exactly against this one.
	_claimed.append(Rect2(best, Vector2(width, height)).grow(NOTE_GAP * 0.5))


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
	var card_size := Vector2(260, 220)
	card.custom_minimum_size = card_size
	# Below every chapter, centred: this is the note the board ends on, and
	# dropping it in the middle at a fixed 0.42 landed it on the mid-board
	# chapters and then off the bottom edge when pushed clear (G12.10).
	var lowest := 0.0
	for taken: Rect2 in _claimed:
		lowest = maxf(lowest, taken.end.y)
	var spot := Vector2((_layout_width - card_size.x) * 0.5, lowest + NOTE_GAP * 2.0)
	card.position = spot
	_claimed.append(Rect2(spot, card_size))
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
	_cards_layer.add_child(card)
	var final_note := _make_note(Story.text("board.final_note"))
	_cards_layer.add_child(final_note)
	_place_note(final_note, spot, spot + Vector2(card_size.x - CARD_SIZE.x,
		card_size.y - CARD_SIZE.y))


func _at(fx: float, fy: float) -> Vector2:
	# Positions are fractions of the usable board (under the top bar, above the
	# back button), minus the card so nothing hangs off the right edge.
	var top := 40.0
	var bottom := _layout_height - 60.0
	return Vector2(fx * (_layout_width - CARD_SIZE.x - 60.0) + 30.0,
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
