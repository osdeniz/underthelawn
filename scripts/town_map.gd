class_name TownMap
extends Control
## The case board's map: a region layer and a town layer (G13.5).
##
## This replaces the PLACES list. A list told the player which chapters exist; a
## map tells them where Ellie went — Case 1 reads west to east across the town,
## and that line is the story without a sentence of exposition.
##
## Both layers are drawn in code. `textures/map/world_map.png` and
## `town_map.png` are used when present; without them the parchment, the roads
## and the creek are generated, so the screen is never a missing-art placeholder.
## The generated version is the one this was designed against.

## One stop on the east road. Sized so two neighbouring stops cannot overlap at
## the spacing story.json gives them — the first pass used 96 px buttons at
## 56 px apart, and a tap near one landed on the next (G13).
const STOP_SIZE := 72.0
const STOP_RADIUS := 20.0

signal place_chosen(variant_id: String)
signal shortcut_chosen(page_id: String)

enum Layer { WORLD, TOWN }

var _layer: int = Layer.WORLD
var _world: Control
var _town: Control
var _sheet: TextureRect
var _panel: PanelContainer
var _selected := ""
var _pulse := 0.0
var _clouds := 0.0
## Filled once per layout so _draw and the pin buttons agree on the map rect.
var _map_rect := Rect2()
## True when hand-painted sheets were found. The generated roads, creek, hills
## and fog are then NOT drawn: the art already has them, and drawing over it
## would be two maps at once (G13.5).
var _painted := false
## How far the sheet has been dragged. Zero is the top-left corner on screen.
var _pan := Vector2.ZERO
var _drag_finger := -1
var _drag_from := Vector2.ZERO
var _drag_pan := Vector2.ZERO


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	clip_contents = true
	_painted = TextureLibrary.find("map/town_map") != null
	if _painted:
		var desk := TextureRect.new()
		desk.name = "Desk"
		desk.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		desk.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		desk.stretch_mode = TextureRect.STRETCH_SCALE
		desk.texture = MapArt.parchment(256, 2211)
		desk.modulate = Color(0.62, 0.56, 0.44)
		desk.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(desk)
	_build_world()
	_build_town()
	_build_east_road()
	# Lay the sheets out before the first frame: _ready never called this, so
	# until something triggered a refresh both layers used their unpositioned
	# full-rect size and the region came out cropped.
	_layout_sheets()
	_update_world()
	show_layer(Layer.WORLD, false)
	set_process(true)


## Rebuilds every pin from progress. Called whenever the screen is opened.
func refresh() -> void:
	if _town == null:
		return
	_layout_sheets()
	_build_pins()
	_update_world()


## The painted sheets are 3:2; a portrait screen keeps that shape and centres it.
## Both layers and every pin are placed inside THIS rect, so the art and the
## marks on it can never drift apart.
## The region sheet is FITTED, the town sheet is FILLED.
##
## They want opposite things: the region has to be seen whole — that layer's
## entire job is "the world is large and you are one dot in it" — while the town
## is a working surface and has to be big enough to read. Sharing one rule left
## the region cropped with the light in the east off the screen (G13.5).
func _world_rect() -> Rect2:
	if not _painted:
		return Rect2(Vector2.ZERO, size)
	var width := size.x
	var height := width / GameConfig.MAP_SHEET_ASPECT
	if height > size.y:
		height = size.y
		width = height * GameConfig.MAP_SHEET_ASPECT
	return Rect2(Vector2((size.x - width) * 0.5, (size.y - height) * 0.5),
		Vector2(width, height))


func _sheet_rect() -> Rect2:
	if not _painted:
		return Rect2(Vector2.ZERO, size)
	# FILLS the screen rather than fitting inside it: a 3:2 sheet letterboxed
	# into a portrait screen was only 40% of it, with the town too small to read
	# and two bands of empty desk. It is scaled to cover and dragged instead —
	# which is what every map screen on a phone does (G13.5).
	var width := size.x
	var height := width / GameConfig.MAP_SHEET_ASPECT
	if height < size.y:
		height = size.y
		width = height * GameConfig.MAP_SHEET_ASPECT
	return Rect2(_pan, Vector2(width, height))


## Keeps the dragged sheet from leaving a gap at any edge.
func _clamp_pan() -> void:
	var sheet := _sheet_rect().size
	_pan.x = clampf(_pan.x, minf(0.0, size.x - sheet.x), 0.0)
	_pan.y = clampf(_pan.y, minf(0.0, size.y - sheet.y), 0.0)


## Centres the sheet on a point given in sheet fractions.
func _pan_to(at: Vector2) -> void:
	var sheet := _sheet_rect().size
	_pan = size * 0.5 - sheet * at
	_clamp_pan()
	refresh()


## Puts both sheets in the centred rect. Stretch mode becomes KEEP_ASPECT so the
## art is never cropped: COVERED cut the greenhouse and the water tower off the
## sides, which are the two edge landmarks the case needs.
func _layout_sheets() -> void:
	_map_rect = _sheet_rect()
	for entry: Array in [[_world, _world_rect()], [_town, _sheet_rect()]]:
		var host := entry[0] as Control
		if host == null:
			continue
		var box := entry[1] as Rect2
		for child in host.get_children():
			var sheet := child as TextureRect
			if sheet == null:
				continue
			sheet.set_anchors_preset(Control.PRESET_TOP_LEFT)
			sheet.position = box.position
			sheet.size = box.size
			sheet.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED


# ---------------------------------------------------------------- layers

func show_layer(which: int, animate := true) -> void:
	_layer = which
	var showing: Control = _world if which == Layer.WORLD else _town
	var hiding: Control = _town if which == Layer.WORLD else _world
	_close_panel()
	if not animate:
		showing.visible = true
		showing.modulate.a = 1.0
		showing.scale = Vector2.ONE
		hiding.visible = false
		return
	# Zoom-fade: the town grows out of the region rather than cutting to it, so
	# the two layers read as the same place at two distances.
	showing.visible = true
	showing.pivot_offset = size * 0.5
	hiding.pivot_offset = size * 0.5
	showing.modulate.a = 0.0
	showing.scale = Vector2.ONE * (0.86 if which == Layer.TOWN else 1.14)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(showing, "modulate:a", 1.0, GameConfig.MAP_ZOOM_SECONDS)
	tween.tween_property(showing, "scale", Vector2.ONE, GameConfig.MAP_ZOOM_SECONDS) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(hiding, "modulate:a", 0.0, GameConfig.MAP_ZOOM_SECONDS * 0.7)
	tween.tween_property(hiding, "scale",
		Vector2.ONE * (1.14 if which == Layer.TOWN else 0.86),
		GameConfig.MAP_ZOOM_SECONDS)
	tween.chain().tween_callback(func() -> void: hiding.visible = false)
	if which == Layer.TOWN:
		if _painted and _pan == Vector2.ZERO:
			_pan_to(Vector2(0.5, 0.5))
		Analytics.track(AnalyticsEvents.MAP_OPENED, {})
	else:
		Analytics.track(AnalyticsEvents.WORLD_MAP_VIEWED, {})


## Opens straight onto the town, focused on a place. Used by the chapter-end
## "next" button so finishing a search leads back to the map rather than a list.
func focus_place(variant_id: String) -> void:
	_selected = variant_id
	# A Case 02 chapter is a stop on the east road, and the east road is on the
	# WORLD sheet. Sending it to the town layer put the player on a map that
	# does not contain the place they were being taken to, and then opened
	# nothing — which is what "the Case 02 transition is broken" looked like
	# from the outside (G13).
	if _is_east_road(variant_id):
		show_layer(Layer.WORLD, _layer == Layer.TOWN)
		_update_east_road()
		_open_panel(variant_id)
		return
	show_layer(Layer.TOWN, _layer == Layer.WORLD)
	if variant_id == GameConfig.HARVEST_VARIANT:
		# The harvest is not a case place, so it has no route slot to focus:
		# pan to the farm and open its own sheet (G13.6).
		_pan_to(GameConfig.MAP_BUILDINGS["farm"]["at"] as Vector2)
		_open_harvest_panel()
	elif GameConfig.MAP_PLACES.has(variant_id):
		# Bring the place into view before opening its sheet, or the panel talks
		# about a pin that is off the side of the screen.
		_pan_to(GameConfig.MAP_PLACES[variant_id] as Vector2)
		_open_panel(variant_id)
	else:
		refresh()


# ---------------------------------------------------------------- world layer

func _build_world() -> void:
	_world = Control.new()
	_world.name = "WorldLayer"
	_world.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_world.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(_world)

	var art := TextureLibrary.find("map/world_map")
	var sheet := TextureRect.new()
	sheet.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sheet.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sheet.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	sheet.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sheet.texture = art if art != null else MapArt.parchment(512, 8801)
	if art == null:
		TextureLibrary.warn_missing("map/world_map", "prosedurel parsomen")
	_world.add_child(sheet)

	# The region's coastline and roads are drawn over the sheet.
	var ink := Control.new()
	ink.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ink.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ink.draw.connect(_draw_world.bind(ink))
	_world.add_child(ink)

	var title := Label.new()
	title.name = "RegionTitle"
	title.text = tr("MAP_REGION")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	title.offset_top = 70.0
	title.offset_bottom = 150.0
	title.add_theme_font_size_override("font_size", 54)
	title.add_theme_color_override("font_color", GameConfig.MAP_INK)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_world.add_child(title)

	var sub := Label.new()
	sub.text = tr("MAP_REGION_SUB")
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	sub.offset_top = 146.0
	sub.offset_bottom = 196.0
	sub.add_theme_font_size_override("font_size", 30)
	sub.add_theme_color_override("font_color", GameConfig.MAP_INK_FAINT)
	sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_world.add_child(sub)

	# The one interactive thing on this layer: our own town.
	var town_button := Button.new()
	town_button.name = "TownButton"
	town_button.flat = true
	town_button.custom_minimum_size = Vector2(260, 260)
	town_button.tooltip_text = tr("MAP_REGION")
	town_button.pressed.connect(func() -> void:
		Haptics.medium()
		show_layer(Layer.TOWN))
	_world.add_child(town_button)

	var hint := Label.new()
	hint.text = tr("MAP_WORLD_HINT")
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	hint.offset_top = -150.0
	hint.offset_bottom = -90.0
	hint.add_theme_font_size_override("font_size", 28)
	hint.add_theme_color_override("font_color", GameConfig.MAP_INK_FAINT)
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_world.add_child(hint)


## Coast, roads, the fog over everywhere that is not ours, and one far light.
func _draw_world(canvas: Control) -> void:
	var rect := _world_rect()
	if _painted:
		# The painted region sheet already has its coast, hills, fog and the
		# light in the east. Nothing is drawn over it.
		return
	MapArt.draw_region(canvas, rect, _clouds)
	var town := rect.position + rect.size * GameConfig.MAP_TOWN_AT
	# Our region: a clear ring around the town, everything else washed out.
	# Our own circle is the only COLOURED part of the region: the fog lifts, the
	# ground is green, and there is a hard rim. Everything else is washed grey.
	var ring := rect.size.x * 0.155
	canvas.draw_circle(town, ring, Color(0.86, 0.86, 0.62, 0.75))
	canvas.draw_circle(town, ring * 0.92, Color(0.68, 0.76, 0.48, 0.55))
	canvas.draw_arc(town, ring, 0.0, TAU, 48, GameConfig.MAP_INK, 5.0, true)
	MapArt.draw_town_mark(canvas, town, rect.size.x * 0.075,
		GameConfig.MAP_INK)
	var font_name := ThemeDB.fallback_font
	canvas.draw_string(font_name, town + Vector2(-ring * 0.62, ring * 0.72),
		tr("MAP_REGION"), HORIZONTAL_ALIGNMENT_LEFT, ring * 1.4, 32,
		GameConfig.MAP_INK)

	# The light in the east: no name, no pin, nothing to press. Just a reason to
	# look that way — Concord, two cases from now.
	var far := rect.position + rect.size * GameConfig.MAP_FAR_LIGHT
	var glow := 0.45 + 0.30 * sin(_pulse * 1.4)
	canvas.draw_circle(far, 52.0, Color(1.0, 0.84, 0.48, 0.09 * glow))
	canvas.draw_circle(far, 26.0, Color(1.0, 0.86, 0.52, 0.16 * glow))
	canvas.draw_circle(far, 11.0, Color(1.0, 0.90, 0.62, glow))
	var font := ThemeDB.fallback_font
	canvas.draw_string(font, far + Vector2(34.0, 16.0), "?",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 52, GameConfig.MAP_INK)


func _update_world() -> void:
	if _world == null:
		return
	var button := _world.get_node_or_null("TownButton") as Control
	if button != null:
		var box := _world_rect()
		var at := box.position + box.size * GameConfig.MAP_TOWN_AT
		button.position = at - button.custom_minimum_size * 0.5
		button.size = button.custom_minimum_size
	_update_east_road()


# ------------------------------------------------------- the east road (G13)

## Case 02 leaves the town, so the map has to leave it too. From Act 2 the
## chapters are not pins on the town sheet any more; they are stops along a road
## that runs east off the edge of everything the player knows.
##
## Nothing here is drawn until the road is EARNED: before Case 02 opens the
## world sheet is exactly the one Case 01 shipped with.
func _build_east_road() -> void:
	if _world == null:
		return
	var holder := Control.new()
	holder.name = "EastRoad"
	holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# IGNORE, not PASS. PASS still receives the click and hands it to its
	# PARENT, which means a full-rect layer swallows everything behind it — this
	# one sat over the world map's town button and the town stopped opening.
	# IGNORE lets the click through; the stop buttons inside are unaffected,
	# because a parent's filter does not apply to its children.
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_world.add_child(holder)

	var ink := Control.new()
	ink.name = "RoadInk"
	ink.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ink.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ink.draw.connect(_draw_east_road.bind(ink))
	holder.add_child(ink)

	for pin: Dictionary in Story.list("east_road.pins"):
		var vid := str(pin.get("chapter", ""))
		var stop := Button.new()
		stop.name = "Stop_" + vid
		stop.custom_minimum_size = Vector2(STOP_SIZE, STOP_SIZE)
		stop.flat = true
		stop.focus_mode = Control.FOCUS_NONE
		stop.set_meta("chapter", vid)
		stop.set_meta("at", Vector2(float(pin.get("x", 0.5)),
			float(pin.get("y", 0.5))))
		stop.draw.connect(_draw_stop.bind(stop))
		stop.pressed.connect(func() -> void:
			Haptics.light()
			Analytics.track(AnalyticsEvents.MAP_PIN_TAPPED, {"chapter": vid})
			_open_panel(vid))
		holder.add_child(stop)


## Places the stops and repaints them, so a chapter finished since the map was
## last opened turns green without the map being rebuilt.
func _update_east_road() -> void:
	var holder := _world.get_node_or_null("EastRoad") as Control
	if holder == null:
		return
	holder.visible = ChapterProgress.case_two_open()
	if not holder.visible:
		return
	var box := _world_rect()
	for child in holder.get_children():
		var stop := child as Button
		if stop == null:
			continue
		var at: Vector2 = stop.get_meta("at", Vector2(0.5, 0.5))
		stop.position = box.position + box.size * at \
			- stop.custom_minimum_size * 0.5
		stop.size = stop.custom_minimum_size
		stop.queue_redraw()
	var ink := holder.get_node_or_null("RoadInk") as Control
	if ink != null:
		ink.queue_redraw()


## The road itself, dashed, with the stretch already travelled inked solid.
## Reclaim works out here too: the road behind you is the part that is safe.
func _draw_east_road(canvas: Control) -> void:
	var box := _world_rect()
	var points: Array[Vector2] = [box.position + box.size * GameConfig.MAP_TOWN_AT]
	var done_to := 0
	var index := 0
	for pin: Dictionary in Story.list("east_road.pins"):
		index += 1
		points.append(box.position + box.size * Vector2(
			float(pin.get("x", 0.5)), float(pin.get("y", 0.5))))
		if ChapterProgress.is_done(str(pin.get("chapter", ""))):
			done_to = index
	for i in points.size() - 1:
		var a: Vector2 = points[i]
		var b: Vector2 = points[i + 1]
		var travelled := i < done_to
		# MAP_INK, not MAP_INK_FAINT: the faint ink is for labels on parchment
		# and the road ahead disappeared into the paper entirely.
		var col: Color = GameConfig.MAP_PIN_DONE if travelled \
			else Color(GameConfig.MAP_INK, 0.55)
		var width := 7.0 if travelled else 5.0
		if travelled:
			canvas.draw_line(a, b, col, width, true)
			continue
		# Ahead of the player the road is dashed: not walked yet. Long dashes,
		# and started clear of the ring at each end — short ones fell entirely
		# inside the two stop markers and nothing was drawn between them.
		var ring := 26.0 / maxf(a.distance_to(b), 1.0)
		var from := a.lerp(b, ring)
		var to := a.lerp(b, 1.0 - ring)
		var steps := maxi(int(from.distance_to(to) / 30.0), 1)
		for k in steps:
			if k % 2 == 1:
				continue
			canvas.draw_line(from.lerp(to, float(k) / float(steps)),
				from.lerp(to, float(k + 1) / float(steps)), col, width, true)


## One stop: a ring, filled when the chapter is finished.
func _draw_stop(stop: Button) -> void:
	var vid := str(stop.get_meta("chapter", ""))
	var centre := stop.custom_minimum_size * 0.5
	var done := ChapterProgress.is_done(vid)
	var active := ChapterProgress.current_variant_id() == vid
	var ring: Color = GameConfig.MAP_PIN_DONE if done \
		else (GameConfig.MAP_PIN_ACTIVE if active else GameConfig.MAP_INK_FAINT)
	stop.draw_circle(centre, STOP_RADIUS, Color(0.96, 0.93, 0.85, 0.92))
	stop.draw_arc(centre, STOP_RADIUS, 0.0, TAU, 28, ring, 5.0, true)
	if done:
		stop.draw_circle(centre, STOP_RADIUS * 0.55, ring)
	elif active:
		# The next stop breathes, the same way the town map's active pin does.
		stop.draw_circle(centre, 8.0 + 2.0 * sin(_pulse * 3.0), ring)


# ---------------------------------------------------------------- town layer

func _build_town() -> void:
	_town = Control.new()
	_town.name = "TownLayer"
	_town.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_town.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(_town)

	var art := TextureLibrary.find("map/town_map")
	_sheet = TextureRect.new()
	_sheet.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_sheet.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_sheet.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_sheet.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sheet.texture = art if art != null else MapArt.parchment(512, 4407)
	if art == null:
		TextureLibrary.warn_missing("map/town_map", "prosedurel kasaba haritasi")
	_town.add_child(_sheet)

	var ink := Control.new()
	ink.name = "TownInk"
	ink.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ink.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ink.draw.connect(_draw_town.bind(ink))
	_town.add_child(ink)

	var pins := Control.new()
	pins.name = "Pins"
	pins.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pins.mouse_filter = Control.MOUSE_FILTER_PASS
	_town.add_child(pins)

	var back := Button.new()
	back.text = tr("MAP_BACK_WORLD")
	back.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	back.offset_left = 44.0
	back.offset_right = 260.0
	back.offset_top = 60.0
	back.offset_bottom = 132.0
	back.add_theme_font_size_override("font_size", 30)
	HubScreen.style_secondary(back)
	back.pressed.connect(func() -> void:
		Haptics.light()
		show_layer(Layer.WORLD))
	_town.add_child(back)
	_town.visible = false


## Roads, the creek and its bridge, the square — laid out to agree with the
## diorama: the square in the middle, paths radiating from it, the creek
## crossing the low ground where the flooded lot sits.
func _draw_town(canvas: Control) -> void:
	var rect := _sheet_rect()
	_map_rect = rect
	if not _painted:
		MapArt.draw_town(canvas, rect, _clouds)
	# Finished places brighten the paper around them: the reclaimed band's
	# answer on paper (G13.4).
	for id: String in GameConfig.MAP_PLACES:
		if not ChapterProgress.is_done(id):
			continue
		var at := rect.position + rect.size * (GameConfig.MAP_PLACES[id] as Vector2)
		canvas.draw_circle(at, rect.size.x * GameConfig.MAP_RECLAIM_RADIUS,
			Color(0.56, 0.74, 0.42, 0.16))
	# The route: a dotted line through the places in order, drawn only as far as
	# the player has actually been. It is Ellie's path, and it points east.
	var walked: Array = []
	for id: String in GameConfig.MAP_PLACES:
		if ChapterProgress.is_done(id):
			walked.append(rect.position + rect.size
				* (GameConfig.MAP_PLACES[id] as Vector2))
	for i in range(1, walked.size()):
		MapArt.draw_dotted(canvas, walked[i - 1], walked[i],
			Color(0.72, 0.40, 0.30, 0.75), 4.0, 15.0)


# ---------------------------------------------------------------- pins

func _build_pins() -> void:
	var host := _town.get_node_or_null("Pins") as Control
	if host == null:
		return
	for child in host.get_children():
		host.remove_child(child)
		child.queue_free()
	var rect := _sheet_rect()

	# Restored buildings first, so a case pin is always on top of them.
	for id: String in GameConfig.MAP_BUILDINGS:
		if not RestoreBoard.is_built(id):
			continue
		var spec: Dictionary = GameConfig.MAP_BUILDINGS[id]
		var mark := _building_mark(id, str(spec["opens"]))
		mark.position = rect.position + rect.size * (spec["at"] as Vector2) \
			- Vector2(30, 30)
		host.add_child(mark)

	# The harvest, when the town is asking for it: a gold badge on the farm,
	# outside the case's own sequence entirely (G13.6).
	if HarvestLog.is_offered():
		var farm: Dictionary = GameConfig.MAP_BUILDINGS["farm"]
		var call_pin := _harvest_pin()
		call_pin.position = rect.position + rect.size * (farm["at"] as Vector2) \
			- Vector2(44, 62)
		host.add_child(call_pin)

	var order: Array = GameConfig.MAP_PLACES.keys()
	var next_id := _next_place(order)
	for id_any: Variant in order:
		var id := str(id_any)
		var pin := _place_pin(id, id == next_id)
		pin.position = rect.position \
			+ rect.size * (GameConfig.MAP_PLACES[id] as Vector2) - Vector2(44, 62)
		host.add_child(pin)


## The first place that is not finished — the one the case is asking for.
## True for a chapter that lives on the east road rather than in the town.
func _is_east_road(variant_id: String) -> bool:
	for pin: Dictionary in Story.list("east_road.pins"):
		if str(pin.get("chapter", "")) == variant_id:
			return true
	return false


## The chapter ids of the case `variant_id` belongs to, in board order.
func _case_order(variant_id: String) -> Array:
	var out: Array = []
	for chapter: Dictionary in ChapterProgress.case_of(variant_id):
		out.append(str(chapter.get("variant_id", "")))
	return out


func _next_place(order: Array) -> String:
	for id_any: Variant in order:
		if not ChapterProgress.is_done(str(id_any)):
			return str(id_any)
	return ""


func _place_pin(variant_id: String, is_next: bool) -> Button:
	var done := ChapterProgress.is_done(variant_id)
	var missed := done and ChapterProgress.evidence_found(variant_id) \
		< ChapterProgress.evidence_total(variant_id)
	var locked := not done and not is_next

	var pin := Button.new()
	pin.name = "Pin_" + variant_id
	pin.flat = true
	pin.custom_minimum_size = Vector2(88, 88)
	pin.size = pin.custom_minimum_size
	pin.tooltip_text = tr(_place_name(variant_id))
	var colour := GameConfig.MAP_PIN_LOCKED
	if done:
		colour = GameConfig.MAP_PIN_DONE
	elif is_next:
		colour = GameConfig.MAP_PIN_ACTIVE
	pin.set_meta("colour", colour)
	pin.set_meta("done", done)
	pin.set_meta("missed", missed)
	pin.set_meta("locked", locked)
	pin.set_meta("next", is_next)
	pin.draw.connect(_draw_pin.bind(pin))
	pin.pressed.connect(func() -> void:
		Haptics.light()
		Analytics.track(AnalyticsEvents.MAP_PIN_TAPPED, {"id": variant_id})
		_open_panel(variant_id))

	var label := Label.new()
	label.text = tr(_place_name(variant_id))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(200, 0)
	label.position = Vector2(-56, 86)
	label.add_theme_font_size_override("font_size", 26)
	label.add_theme_color_override("font_color", Color(0.13, 0.11, 0.09))
	# On painted ground a drop shadow is not enough — the name needs its own
	# patch of paper under it or it disappears into the trees.
	var plate := StyleBoxFlat.new()
	plate.bg_color = Color(0.90, 0.84, 0.68, 0.86)
	plate.set_corner_radius_all(8)
	plate.content_margin_left = 10.0
	plate.content_margin_right = 10.0
	plate.content_margin_top = 3.0
	plate.content_margin_bottom = 3.0
	label.add_theme_stylebox_override("normal", plate)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pin.add_child(label)
	return pin


## A map pin: teardrop body, a ring, and the state mark inside it.
func _draw_pin(pin: Button) -> void:
	var colour: Color = pin.get_meta("colour")
	var centre := Vector2(44, 34)
	var scale := 1.0
	if bool(pin.get_meta("next", false)):
		# The active pin breathes, so the eye finds it without a label.
		scale = 1.0 + 0.09 * sin(_pulse * 3.0)
	MapArt.draw_pin(pin, centre, 26.0 * scale, colour)
	var font := ThemeDB.fallback_font
	var mark := ""
	if bool(pin.get_meta("missed", false)):
		mark = "!"
	elif bool(pin.get_meta("done", false)):
		mark = "✓"
	elif bool(pin.get_meta("locked", false)):
		mark = "—"
	if mark != "":
		var ink := Color(0.14, 0.12, 0.10) if mark != "!" else Color(0.72, 0.22, 0.16)
		pin.draw_string(font, centre + Vector2(-9, 10), mark,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 30, ink)


## A restored building on the map: a small square that opens its screen.
func _building_mark(project_id: String, opens: String) -> Button:
	var mark := Button.new()
	mark.name = "Mark_" + project_id
	mark.flat = true
	mark.custom_minimum_size = Vector2(60, 60)
	mark.size = mark.custom_minimum_size
	mark.tooltip_text = project_id
	mark.draw.connect(func() -> void:
		MapArt.draw_building(mark, Vector2(30, 30), 14.0))
	mark.pressed.connect(func() -> void:
		Haptics.light()
		shortcut_chosen.emit(opens))
	return mark


# ---------------------------------------------------------------- place panel

## The sheet that slides up when a pin is tapped: where it is, how it went, and
## the one button that starts the search. The chapter-start path itself is
## untouched — this is a new door onto the same room.
func _open_panel(variant_id: String) -> void:
	_close_panel()
	_selected = variant_id
	var done := ChapterProgress.is_done(variant_id)
	var found := ChapterProgress.evidence_found(variant_id)
	var total := ChapterProgress.evidence_total(variant_id)
	if total <= 0:
		total = LevelVariant.of(variant_id).evidence_count()
	# The order this place belongs to, not Case 01's. MAP_PLACES lists the eight
	# town places, so an east-road stop was never anybody's "next" and every
	# Case 02 chapter was permanently locked — the whole case was unreachable
	# from the map (G13).
	var order := _case_order(variant_id)
	var is_next := _next_place(order) == variant_id
	var locked := not done and not is_next

	_panel = PanelContainer.new()
	_panel.name = "PlacePanel"
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.11, 0.09, 0.96)
	style.border_color = GameConfig.CASE_ACCENT
	style.set_border_width_all(3)
	style.set_corner_radius_all(20)
	style.set_content_margin_all(28)
	_panel.add_theme_stylebox_override("panel", style)
	_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_panel.offset_left = 40.0
	_panel.offset_right = -40.0
	_panel.offset_top = -430.0
	_panel.offset_bottom = -40.0
	add_child(_panel)

	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 14)
	_panel.add_child(rows)

	# Title row: name on the left, close on the right. The close button used to
	# be a second child of the PanelContainer, which stretches its children, so
	# it landed in the middle of the sheet (G13.5).
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	rows.add_child(head)

	var name_label := Label.new()
	name_label.text = tr(_place_name(variant_id))
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_theme_font_size_override("font_size", 44)
	name_label.add_theme_color_override("font_color", Color(0.96, 0.94, 0.88))
	head.add_child(name_label)

	var close := Button.new()
	close.text = "×"
	close.flat = true
	close.custom_minimum_size = Vector2(64, 64)
	close.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	close.add_theme_font_size_override("font_size", 44)
	close.add_theme_color_override("font_color", GameConfig.CASE_MUTED)
	close.pressed.connect(_close_panel)
	head.add_child(close)

	var state := Label.new()
	var missed := done and found < total
	if missed:
		state.text = tr("MAP_STATE_MISSED")
		state.add_theme_color_override("font_color", Color(0.94, 0.72, 0.36))
	elif done:
		state.text = tr("MAP_STATE_DONE")
		state.add_theme_color_override("font_color", GameConfig.MAP_PIN_DONE)
	elif is_next:
		state.text = tr("MAP_STATE_ACTIVE")
		state.add_theme_color_override("font_color", GameConfig.MAP_PIN_ACTIVE)
	else:
		state.text = tr("MAP_STATE_LOCKED")
		state.add_theme_color_override("font_color", Color(0.70, 0.68, 0.64))
	state.add_theme_font_size_override("font_size", 30)
	rows.add_child(state)

	var count := Label.new()
	count.text = tr("MAP_EVIDENCE").format({"found": found, "total": total})
	count.add_theme_font_size_override("font_size", 30)
	count.add_theme_color_override("font_color", GameConfig.CASE_MUTED)
	rows.add_child(count)

	var go := Button.new()
	go.custom_minimum_size = Vector2(0, 104)
	go.add_theme_font_size_override("font_size", 36)
	if locked:
		go.text = tr("MAP_LOCKED_NOTE")
		go.disabled = true
		HubScreen.style_secondary(go)
	else:
		go.text = tr("MAP_AGAIN") if done else tr("MAP_START")
		HubScreen.style_primary(go)
		go.pressed.connect(func() -> void:
			Haptics.medium()
			place_chosen.emit(variant_id))
	rows.add_child(go)

	# Slides up rather than appearing: the map stays the subject.
	_panel.position.y += 90.0
	_panel.modulate.a = 0.0
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_panel, "position:y", _panel.position.y - 90.0, 0.22)
	tween.tween_property(_panel, "modulate:a", 1.0, 0.22)


func _close_panel() -> void:
	if _panel != null and is_instance_valid(_panel):
		_panel.queue_free()
	_panel = null


## The harvest badge. It is not a case place, so it gets its own pin rather than
## a slot in the route.
func _harvest_pin() -> Button:
	var pin := Button.new()
	pin.name = "Pin_harvest"
	pin.flat = true
	pin.custom_minimum_size = Vector2(88, 88)
	pin.size = pin.custom_minimum_size
	pin.tooltip_text = tr("HARVEST_PLACE")
	pin.set_meta("colour", GameConfig.HARVEST_GOLD)
	pin.set_meta("harvest", true)
	pin.draw.connect(func() -> void:
		var beat := 1.0 + 0.10 * sin(_pulse * 3.0)
		MapArt.draw_pin(pin, Vector2(44, 34), 26.0 * beat,
			GameConfig.HARVEST_GOLD)
		pin.draw_string(ThemeDB.fallback_font, Vector2(35, 44), "\u2605",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color(0.30, 0.22, 0.06)))
	pin.pressed.connect(func() -> void:
		Haptics.light()
		Analytics.track(AnalyticsEvents.HARVEST_OFFERED, {})
		_open_harvest_panel())

	var label := Label.new()
	label.text = tr("HARVEST_PLACE")
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.custom_minimum_size = Vector2(200, 0)
	label.position = Vector2(-56, 86)
	label.add_theme_font_size_override("font_size", 26)
	label.add_theme_color_override("font_color", Color(0.13, 0.11, 0.09))
	var plate := StyleBoxFlat.new()
	plate.bg_color = Color(0.95, 0.86, 0.56, 0.90)
	plate.set_corner_radius_all(8)
	plate.content_margin_left = 10.0
	plate.content_margin_right = 10.0
	plate.content_margin_top = 3.0
	plate.content_margin_bottom = 3.0
	label.add_theme_stylebox_override("normal", plate)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pin.add_child(label)
	return pin


## Gus's invitation, in the same sheet shape a place uses.
func _open_harvest_panel() -> void:
	_close_panel()
	_panel = PanelContainer.new()
	_panel.name = "PlacePanel"
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.14, 0.12, 0.08, 0.96)
	style.border_color = GameConfig.MAP_PIN_ACTIVE
	style.set_border_width_all(3)
	style.set_corner_radius_all(20)
	style.set_content_margin_all(28)
	_panel.add_theme_stylebox_override("panel", style)
	_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_panel.offset_left = 40.0
	_panel.offset_right = -40.0
	_panel.offset_top = -390.0
	_panel.offset_bottom = -40.0
	add_child(_panel)

	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 16)
	_panel.add_child(rows)
	for spec: Array in [["HARVEST_PLACE", 44, Color(0.96, 0.94, 0.88)],
			["HARVEST_CALL", 30, GameConfig.CASE_MUTED]]:
		var line := Label.new()
		line.text = tr(str(spec[0]))
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		line.add_theme_font_size_override("font_size", int(spec[1]))
		line.add_theme_color_override("font_color", spec[2])
		rows.add_child(line)
	var go := Button.new()
	go.text = tr("HARVEST_START")
	go.custom_minimum_size = Vector2(0, 104)
	go.add_theme_font_size_override("font_size", 36)
	HubScreen.style_primary(go)
	go.pressed.connect(func() -> void:
		Haptics.medium()
		Analytics.track(AnalyticsEvents.HARVEST_STARTED, {})
		place_chosen.emit(GameConfig.HARVEST_VARIANT))
	rows.add_child(go)


## The chapter's display name, from story.json.
## Both cases, not just the first. The east road's stops are Case 02 chapters,
## and looking in Case 01 alone made their panels show the raw variant id —
## "ch12_river_crossing" where the place's name belongs (G13).
func _place_name(variant_id: String) -> String:
	for path in ["chapters", "case_02.chapters"]:
		for chapter_any: Variant in Story.list(path):
			var chapter: Dictionary = chapter_any
			if str(chapter.get("variant_id", "")) == variant_id:
				return str(chapter.get("name", variant_id))
	return variant_id


## Dragging the sheet. Pins are buttons and take their own presses, so this only
## ever sees a touch that started on open paper.
func _gui_input(event: InputEvent) -> void:
	if not _painted or _layer != Layer.TOWN:
		return
	var touch := event as InputEventScreenTouch
	if touch != null:
		if touch.pressed and _drag_finger < 0:
			_drag_finger = touch.index
			_drag_from = touch.position
			_drag_pan = _pan
		elif not touch.pressed and touch.index == _drag_finger:
			_drag_finger = -1
		return
	var drag := event as InputEventScreenDrag
	if drag != null and drag.index == _drag_finger:
		_pan = _drag_pan + (drag.position - _drag_from)
		_clamp_pan()
		refresh()


# ---------------------------------------------------------------- life

func _process(delta: float) -> void:
	if _town == null or _world == null:
		return
	_pulse += delta
	_clouds += delta
	# The active pin's breathing and the cloud shadow both need a repaint; at
	# 30 fps behind a menu this is the cheapest possible animation.
	# is_visible_in_tree(), not visible: `visible` is this node's OWN flag, so
	# it stayed true while the hub layer above it was hidden for a chapter and
	# the map repainted into nothing for the whole run (G16).
	if not is_visible_in_tree():
		return
	var ink := _town.get_node_or_null("TownInk") as Control
	if ink != null and _town.visible:
		ink.queue_redraw()
	if _world != null and _world.visible:
		for child in _world.get_children():
			if child is Control and not (child is TextureRect):
				(child as Control).queue_redraw()
	var pins := _town.get_node_or_null("Pins") as Control
	if pins != null and _town.visible:
		for child in pins.get_children():
			var pin := child as Button
			if pin != null and bool(pin.get_meta("next", false)):
				pin.queue_redraw()


func _notification(what: int) -> void:
	# RESIZED arrives when the node enters the tree, which is BEFORE _ready has
	# built the layers — refreshing then walks into a null _town.
	if what == NOTIFICATION_RESIZED and _town != null:
		refresh()
