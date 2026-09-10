extends TestBase
## What Ellie's drawings actually look like on the phone (G67), and how much of
## the frame the paper gets.
##
## A 4:3 sheet in a 9:16 window is the reverse of every other picture in this
## game, so the number that matters is not how much of the picture survives —
## it is how much of the SCREEN the paper fills, and whether the words under it
## have room without the sheet shrinking to a stamp.

func run() -> void:
	suite = "CIZIM CEKIM"
	min_checks = 7
	get_window().content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	await frames(2)
	for i in Drawings.total():
		GameState.set_setting(ChapterProgress.SECTION,
			Drawings.chapter_of(i) + "_done", true)
		GameState.set_setting(Drawings.SECTION, Drawings.id_of(i) + "_seen", false)

	var card := DrawingCard.new()
	add_child(card)
	card.play(3)
	await settle(0.6)
	await drawn_frame()
	var frame := get_viewport().get_visible_rect()
	var shot := get_viewport().get_texture().get_image().get_region(
		Rect2i(Vector2i(frame.position), Vector2i(frame.size)))
	shot.save_png("res://out/drawing_card.png")
	print("[cekim] out/drawing_card.png yazildi")

	var view := frame.size
	var paper := card.find_child("DrawingPaper", true, false) as TextureRect
	ck("kagit bulundu", paper != null)
	if paper == null:
		return
	var rect := paper.get_global_rect()
	var wide := rect.size.x / view.x
	var tall := rect.size.y / view.y
	print("[olcum] kagit: ekranin genisliginin %%%.0f'i, yuksekliginin %%%.0f'i" % [
		wide * 100.0, tall * 100.0])
	print("[olcum] kagit y: %%%.0f - %%%.0f" % [
		rect.position.y / view.y * 100.0, rect.end.y / view.y * 100.0])
	ck("kagit genisligin en az %80'ini alir", wide >= 0.80, "%.2f" % wide)
	ck("kagit yuksekligin en az %30'unu alir", tall >= 0.30, "%.2f" % tall)
	var column := card.find_child("DrawingColumn", true, false) as Control
	if column != null:
		var col := column.get_global_rect()
		print("[olcum] blok y: %%%.0f - %%%.0f, ortasi %%%.0f (50 olmali)" % [
			col.position.y / view.y * 100.0, col.end.y / view.y * 100.0,
			(col.position.y + col.size.y * 0.5) / view.y * 100.0])
	ck("blok dikeyde ortalanmis", column != null
		and absf((column.get_global_rect().position.y
			+ column.get_global_rect().size.y * 0.5) / view.y - 0.5) < 0.04,
		"" if column == null else "%.3f" % ((column.get_global_rect().position.y
			+ column.get_global_rect().size.y * 0.5) / view.y))
	var line := card.find_child("DrawingLine", true, false) as Label
	var close := card.find_child("DrawingClose", true, false) as Button
	ck("not kagidin altinda kalir",
		line != null and line.get_global_rect().position.y >= rect.end.y - 1.0,
		"" if line == null else "%.0f vs %.0f" % [line.get_global_rect().position.y, rect.end.y])
	# The one thing a phone cannot forgive: a card whose button is off-screen.
	# G56's guide note went 22 px past the bottom edge exactly this way.
	ck("kapatma dugmesi ekranin icinde",
		close != null and close.get_global_rect().end.y <= view.y,
		"" if close == null else "%.0f / %.0f" % [close.get_global_rect().end.y, view.y])

	# The night drawing is the one at risk: it is the darkest of the four and it
	# is shown UNVEILED, so what the screen gets must still be the picture.
	var mid := shot.get_region(Rect2i(
		Vector2i(int(rect.position.x) + 8, int(rect.position.y) + 8),
		Vector2i(maxi(int(rect.size.x) - 16, 1), maxi(int(rect.size.y) - 16, 1))))
	var sum := 0.0
	var n := 0
	for y in range(0, mid.get_height(), 4):
		for x in range(0, mid.get_width(), 4):
			sum += mid.get_pixel(x, y).get_luminance() * 255.0
			n += 1
	var lit := sum / maxf(float(n), 1.0)
	print("[olcum] gece cizimi ekranda ortalama parlaklik: %.0f (dosyada 79)" % lit)
	ck("gece cizimi perdelenmemis", lit >= 60.0, "%.0f" % lit)
	card.queue_free()
	await frames(2)
