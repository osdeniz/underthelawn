class_name UiIcons
extends RefCounted
## Small drawn icons for the HUD chips and the cost buttons (G12.10).
##
## These were emoji — 💵 and 📋 — which on a phone render as a blank box that
## still takes its width: iOS's default font carries no colour-emoji glyphs and
## Godot does not fall back to the system emoji font. Evidence cards solved the
## same problem by rendering the object's mesh, but money and "evidence" are not
## objects, so they are painted here instead, the way MowerIcons paints the
## machines. No font, no art file.

const SIZE := 64

static var _cache := {}


## A banknote: what the wallet chip and every cost button show.
static func money() -> Texture2D:
	return _make("money")


## A clipboard: the evidence counter.
static func evidence() -> Texture2D:
	return _make("evidence")


## The hub tiles. Each was an emoji in data/story.json.
static func for_tile(tile_id: String) -> Texture2D:
	match tile_id:
		"case_board": return evidence()
		"station": return _make("station")
		"map": return _make("map")
		"objectives": return _make("objectives")
		"town": return _make("town")
		"restore": return _make("restore")
		"workshop": return _make("workshop")
		"echoes": return _make("echoes")
	return null


## The speaker on the mute button, with or without its waves.
static func sound(on: bool) -> Texture2D:
	return _make("sound_on" if on else "sound_off")


## A padlock, for chapters that are not open yet.
static func lock() -> Texture2D:
	return _make("lock")


## A checklist: the objectives door. Two ticked lines and one empty box, which
## is the whole idea of the screen in one 64px picture.
static func objectives() -> Texture2D:
	return _make("objectives")


## The town's food store: a sack, tied at the neck.
static func food() -> Texture2D:
	return _make("food")


## How many people live here: two figures, the second set back.
static func people() -> Texture2D:
	return _make("people")


## A single house: one finished restoration project.
static func house() -> Texture2D:
	return _make("house")


static func _make(id: String) -> Texture2D:
	if _cache.has(id):
		return _cache[id]
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	match id:
		"money": _draw_money(img)
		"evidence": _draw_evidence(img)
		"map": _draw_map(img)
		"town": _draw_town(img)
		"restore": _draw_restore(img)
		"workshop": _draw_workshop(img)
		"echoes": _draw_echoes(img)
		"station": _draw_station(img)
		"sound_on": _draw_sound(img, true)
		"sound_off": _draw_sound(img, false)
		"lock": _draw_lock(img)
		"house": _draw_house(img)
		"food": _draw_food(img)
		"people": _draw_people(img)
		"objectives": _draw_objectives(img)
	var tex := ImageTexture.create_from_image(img)
	_cache[id] = tex
	return tex


static func _rect(img: Image, x: int, y: int, w: int, h: int, c: Color) -> void:
	for py in range(maxi(y, 0), mini(y + h, SIZE)):
		for px in range(maxi(x, 0), mini(x + w, SIZE)):
			img.set_pixel(px, py, c)


static func _frame(img: Image, x: int, y: int, w: int, h: int, t: int,
		c: Color) -> void:
	_rect(img, x, y, w, t, c)
	_rect(img, x, y + h - t, w, t, c)
	_rect(img, x, y, t, h, c)
	_rect(img, x + w - t, y, t, h, c)


static func _disc(img: Image, cx: int, cy: int, r: int, c: Color) -> void:
	for py in range(maxi(cy - r, 0), mini(cy + r + 1, SIZE)):
		for px in range(maxi(cx - r, 0), mini(cx + r + 1, SIZE)):
			if Vector2(px - cx, py - cy).length() <= float(r):
				img.set_pixel(px, py, c)


## One banknote, drawn big and high-contrast. A first version stacked two notes
## with a small oval; at the 38 px the chip actually renders it, the second note
## read as noise and the whole thing went muddy against the dark green chip.
static func _draw_money(img: Image) -> void:
	var rim := Color(0.07, 0.17, 0.09)
	var body := Color(0.58, 0.92, 0.58)
	var mark := Color(0.13, 0.34, 0.16)
	_rect(img, 4, 16, 56, 32, rim)
	_rect(img, 7, 19, 50, 26, body)
	# A fat centre disc and two corner ticks: at icon size these three shapes
	# are the whole difference between "banknote" and "green rectangle".
	_disc(img, 32, 32, 10, mark)
	_disc(img, 32, 32, 6, body)
	_rect(img, 11, 23, 9, 4, mark)
	_rect(img, 44, 37, 9, 4, mark)


## A clipboard: board, clip, and two written lines.
static func _draw_evidence(img: Image) -> void:
	var board := Color(0.80, 0.72, 0.55)
	var edge := Color(0.36, 0.28, 0.18)
	var clip := Color(0.62, 0.64, 0.68)
	var line := Color(0.36, 0.30, 0.22)
	_rect(img, 13, 12, 38, 44, edge)
	_rect(img, 15, 14, 34, 40, board)
	_rect(img, 24, 8, 16, 9, clip)
	_rect(img, 27, 5, 10, 5, clip)
	_rect(img, 20, 26, 24, 4, line)
	_rect(img, 20, 35, 24, 4, line)
	_rect(img, 20, 44, 14, 4, line)
	_frame(img, 13, 12, 38, 44, 2, edge)


## Two roofs side by side.
## A folded paper map with a route crossing it and a pin where the route ends.
## The fold lines are what stop it reading as a plain sheet: two vertical
## creases and the panels stepped by a pixel, the way a road map never lies
## quite flat again once it has been opened.
static func _draw_map(img: Image) -> void:
	var paper := Color(0.86, 0.80, 0.66)
	var shade := Color(0.72, 0.66, 0.52)
	var crease := Color(0.58, 0.52, 0.40)
	var road := Color(0.42, 0.36, 0.26)
	var pin := Color(0.87, 0.38, 0.30)
	# Three panels, the middle one lifted, the outer two dropped.
	_rect(img, 4, 14, 19, 38, paper)
	_rect(img, 23, 11, 18, 38, paper)
	_rect(img, 41, 14, 19, 38, shade)
	_rect(img, 22, 11, 2, 41, crease)
	_rect(img, 40, 11, 2, 41, crease)
	# The road: down, across, and away.
	_rect(img, 11, 20, 3, 14, road)
	_rect(img, 11, 32, 22, 3, road)
	_rect(img, 30, 22, 3, 13, road)
	_rect(img, 30, 22, 18, 3, road)
	# The pin at the far end.
	_disc(img, 48, 20, 6, pin)
	_rect(img, 46, 24, 4, 8, pin)


## A grain sack. The neck is narrower than the body and tied with a band, which
## is the whole difference between a sack and a bag of cement.
static func _draw_food(img: Image) -> void:
	var cloth := Color(0.80, 0.68, 0.42)
	var shade := Color(0.62, 0.50, 0.30)
	var band := Color(0.42, 0.33, 0.20)
	_rect(img, 24, 10, 16, 8, cloth)
	_rect(img, 22, 18, 20, 4, band)
	_rect(img, 16, 22, 32, 32, cloth)
	_rect(img, 38, 22, 10, 32, shade)
	_rect(img, 16, 50, 32, 4, shade)


## Two people. The one behind is drawn smaller and offset rather than simply
## overlapped, so at 64px it still reads as two and not as one wide figure.
static func _draw_people(img: Image) -> void:
	var near := Color(0.86, 0.82, 0.74)
	var far := Color(0.58, 0.55, 0.50)
	_disc(img, 40, 22, 7, far)
	_rect(img, 33, 32, 15, 20, far)
	_disc(img, 24, 20, 9, near)
	_rect(img, 14, 32, 21, 22, near)


static func _draw_town(img: Image) -> void:
	var wall := Color(0.82, 0.78, 0.70)
	var roof := Color(0.58, 0.30, 0.24)
	var dark := Color(0.28, 0.24, 0.20)
	_roof(img, 8, 22, 22, roof)
	_rect(img, 10, 34, 20, 22, wall)
	_rect(img, 17, 44, 7, 12, dark)
	_roof(img, 36, 14, 24, roof)
	_rect(img, 38, 27, 22, 29, wall)
	_rect(img, 46, 38, 7, 18, dark)


## A hammer over a board. The head is deliberately lopsided — a symmetric bar
## on a centred handle just read as the letter T.
static func _draw_restore(img: Image) -> void:
	var wood := Color(0.66, 0.48, 0.28)
	var steel := Color(0.70, 0.72, 0.76)
	var dark := Color(0.24, 0.20, 0.16)
	_rect(img, 4, 46, 56, 12, wood)
	_rect(img, 4, 46, 56, 3, dark)
	_rect(img, 27, 18, 9, 26, wood)
	# Face on the left, claw tapering away on the right.
	_rect(img, 14, 8, 16, 14, steel)
	_rect(img, 30, 10, 10, 9, steel)
	_rect(img, 40, 12, 8, 6, steel)
	_rect(img, 14, 8, 34, 3, dark)


## A wrench.
static func _draw_workshop(img: Image) -> void:
	var steel := Color(0.72, 0.74, 0.78)
	var dark := Color(0.26, 0.27, 0.30)
	_rect(img, 26, 20, 12, 38, steel)
	_rect(img, 26, 20, 12, 3, dark)
	_disc(img, 32, 18, 13, steel)
	_disc(img, 32, 16, 6, Color(0, 0, 0, 0))
	_rect(img, 26, 6, 12, 8, Color(0, 0, 0, 0))


## A scroll: the town's old voices.
static func _draw_echoes(img: Image) -> void:
	var paper := Color(0.86, 0.82, 0.70)
	var edge := Color(0.44, 0.38, 0.28)
	var line := Color(0.40, 0.34, 0.26)
	_rect(img, 12, 10, 40, 44, paper)
	_frame(img, 12, 10, 40, 44, 3, edge)
	_rect(img, 19, 22, 26, 3, line)
	_rect(img, 19, 30, 26, 3, line)
	_rect(img, 19, 38, 16, 3, line)


## The Marshal's station: a wide roof over a doorway.
static func _draw_station(img: Image) -> void:
	var wall := Color(0.78, 0.74, 0.66)
	var roof := Color(0.36, 0.40, 0.46)
	var dark := Color(0.22, 0.20, 0.18)
	var lamp := Color(0.98, 0.86, 0.48)
	_roof(img, 4, 12, 56, roof)
	_rect(img, 10, 30, 44, 26, wall)
	_rect(img, 26, 38, 12, 18, dark)
	_disc(img, 18, 38, 4, lamp)
	_disc(img, 46, 38, 4, lamp)


## Two ticked rows and one empty one.
static func _draw_objectives(img: Image) -> void:
	var paper := Color(0.86, 0.86, 0.82)
	var ink := Color(0.30, 0.32, 0.34)
	var tick := Color(0.36, 0.78, 0.38)
	_rect(img, 8, 8, 48, 48, ink)
	_rect(img, 11, 11, 42, 42, paper)
	for row in 3:
		# 17 + row * 14 put the third row's box at y 45..55, past the paper's
		# own bottom edge at 53.
		var y := 15 + row * 13
		if row < 2:
			# A tick: a short down-stroke and a long up-stroke.
			for i in 4:
				_rect(img, 16 + i, y + 2 + i, 3, 3, tick)
			for i in 7:
				_rect(img, 20 + i, y + 6 - i, 3, 3, tick)
		else:
			_frame(img, 16, y, 10, 10, 2, ink)
		_rect(img, 30, y + 3, 20, 4, ink)


## A triangular roof: `x` left edge, `y` apex, `w` span.
static func _roof(img: Image, x: int, y: int, w: int, c: Color) -> void:
	var rows := w / 2
	for r in rows:
		var inset := rows - r - 1
		_rect(img, x + inset, y + r, w - inset * 2, 1, c)


## Speaker cone plus either two arcs (on) or a cross (off).
static func _draw_sound(img: Image, on: bool) -> void:
	var body := Color(0.92, 0.92, 0.88)
	var off := Color(0.90, 0.42, 0.36)
	_rect(img, 10, 26, 10, 12, body)
	# The cone: a wedge opening to the right.
	for i in 16:
		_rect(img, 20 + i, 32 - i, 2, 2 + i * 2, body)
	if on:
		for r in [10, 16]:
			for step in 22:
				var a: float = -0.7 + float(step) / 21.0 * 1.4
				var px := 38 + int(cos(a) * float(r))
				var py := 32 + int(sin(a) * float(r))
				_rect(img, px, py, 3, 3, body)
	else:
		for i in 14:
			_rect(img, 40 + i, 25 + i, 4, 4, off)
			_rect(img, 40 + i, 39 - i, 4, 4, off)


## Shackle over a body, with a keyhole.
static func _draw_lock(img: Image) -> void:
	var metal := Color(0.74, 0.74, 0.70)
	var dark := Color(0.30, 0.30, 0.28)
	for i in 20:
		var a: float = PI + float(i) / 19.0 * PI
		_rect(img, 32 + int(cos(a) * 13.0) - 2, 24 + int(sin(a) * 13.0) - 2,
			5, 5, metal)
	_rect(img, 14, 28, 36, 28, metal)
	_frame(img, 14, 28, 36, 28, 3, dark)
	_disc(img, 32, 40, 5, dark)
	_rect(img, 30, 40, 4, 10, dark)


## One roof over one wall: a restored home.
static func _draw_house(img: Image) -> void:
	var wall := Color(0.84, 0.80, 0.72)
	var roof := Color(0.60, 0.32, 0.26)
	var dark := Color(0.28, 0.24, 0.20)
	_roof(img, 8, 14, 48, roof)
	_rect(img, 14, 38, 36, 20, wall)
	_rect(img, 28, 46, 9, 12, dark)
