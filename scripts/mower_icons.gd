class_name MowerIcons
extends RefCounted
## Small drawn icons for the mower picker (G12.9).
##
## The picker showed an EMOJI plus a label, which on a phone renders as a blank
## box: iOS's default font has no emoji glyphs. The blank box still took its
## width, which is why the labels looked shoved to the right. These are painted
## into an ImageTexture at startup instead — no font, no art file, and each
## machine keeps the silhouette and colour it has in the world.

const SIZE := 96

static var _cache := {}


static func icon_for(type_index: int) -> Texture2D:
	if _cache.has(type_index):
		return _cache[type_index]
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	match type_index:
		GameConfig.MOWER_PUSH: _draw_push(img)
		GameConfig.MOWER_TRACTOR: _draw_tractor(img)
		GameConfig.MOWER_ROBOT: _draw_robot(img)
		GameConfig.MOWER_BLADE: _draw_blade(img)
	var tex := ImageTexture.create_from_image(img)
	_cache[type_index] = tex
	return tex


static func _rect(img: Image, x: int, y: int, w: int, h: int, c: Color) -> void:
	for py in range(maxi(y, 0), mini(y + h, SIZE)):
		for px in range(maxi(x, 0), mini(x + w, SIZE)):
			img.set_pixel(px, py, c)


static func _disc(img: Image, cx: int, cy: int, r: int, c: Color) -> void:
	for py in range(maxi(cy - r, 0), mini(cy + r + 1, SIZE)):
		for px in range(maxi(cx - r, 0), mini(cx + r + 1, SIZE)):
			if Vector2(px - cx, py - cy).length() <= float(r):
				img.set_pixel(px, py, c)


## Red deck, handle bar, two wheels.
static func _draw_push(img: Image) -> void:
	var red := Color(0.78, 0.16, 0.14)
	var dark := Color(0.16, 0.16, 0.18)
	_rect(img, 20, 46, 56, 26, red)
	_rect(img, 30, 20, 8, 30, Color(0.55, 0.56, 0.58))
	_rect(img, 30, 18, 34, 7, Color(0.55, 0.56, 0.58))
	_disc(img, 28, 74, 9, dark)
	_disc(img, 68, 74, 9, dark)


## Green body, yellow trim, one big rear wheel.
static func _draw_tractor(img: Image) -> void:
	var green := GameConfig.TRACTOR_BODY_COLOR
	var trim := GameConfig.TRACTOR_ACCENT_COLOR
	var dark := Color(0.14, 0.14, 0.16)
	_rect(img, 16, 40, 44, 24, green)
	_rect(img, 46, 26, 24, 20, green)
	_rect(img, 16, 36, 44, 5, trim)
	_disc(img, 62, 66, 15, dark)
	_disc(img, 62, 66, 7, trim)
	_disc(img, 26, 70, 9, dark)


## A small pale dome with a sensor eye.
static func _draw_robot(img: Image) -> void:
	var shell := Color(0.86, 0.87, 0.84)
	var dark := Color(0.18, 0.19, 0.22)
	var eye := Color(0.35, 0.80, 0.45)
	_disc(img, 48, 54, 26, shell)
	_rect(img, 22, 54, 52, 22, shell)
	_rect(img, 22, 70, 52, 8, dark)
	_disc(img, 48, 46, 7, eye)


## The chakram: a gold ring with four horns.
static func _draw_blade(img: Image) -> void:
	var gold := GameConfig.BLADE_GOLD
	var pale := GameConfig.BLADE_CREAM
	_disc(img, 48, 48, 30, gold)
	_disc(img, 48, 48, 20, pale)
	_disc(img, 48, 48, 10, Color(0, 0, 0, 0))
	for i in 4:
		var angle := TAU * float(i) / 4.0 + PI * 0.25
		var cx := 48 + int(sin(angle) * 30.0)
		var cy := 48 + int(cos(angle) * 30.0)
		_disc(img, cx, cy, 8, gold)
