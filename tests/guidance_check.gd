extends TestBase
## What you picked up, and what to do next (G56).
##
## Two complaints, one cause: the game showed the player three grey lumps and a
## chip with a number on it, then left them to guess what either meant. So the
## claims here are about naming — the flying value, the counter, the object in
## the grass — and about the walkthrough that now opens the screen the salvage
## is actually for.

func run() -> void:
	suite = "YONLENDIRME"
	_words()
	_badge()
	_marks()
	await _flying()
	_guide_table()
	_guide_order()
	await _guide_note()
	Guide.reset()
	finish()


## Every new string is written in both languages and carries its number.
func _words() -> void:
	for key: String in ["PICKUP_SCRAP", "PICKUP_FOOD", "WALLET_SALVAGE",
			"WALLET_FOOD", "GUIDE_LABEL", "GUIDE_OK", "GUIDE_OPEN_JOURNAL",
			"GUIDE_RESTORE", "GUIDE_WORKSHOP", "GUIDE_LINK"]:
		ck("metin var: " + key, tr(key) != key, tr(key))
	for key: String in ["PICKUP_SCRAP", "PICKUP_FOOD"]:
		ck("sayi yerini tutuyor: " + key, tr(key).contains("{n}"), tr(key))
		ck("bicimlenince sayi yazilir: " + key,
			tr(key).format({"n": 7}).contains("7"), tr(key).format({"n": 7}))
	# The name beside the number is a word, not the number again.
	ck("hurda adi kisa", tr("WALLET_SALVAGE").length() <= 12, tr("WALLET_SALVAGE"))


## The badge: the counter's own drawing, made readable over grass.
func _badge() -> void:
	var salvage := UiIcons.badge("salvage")
	var food := UiIcons.badge("food")
	ck("rozet uretildi", salvage != null and food != null, "")
	ck("rozet ikondan buyuk", salvage.get_width() > UiIcons.SIZE,
		"%d > %d" % [salvage.get_width(), UiIcons.SIZE])
	ck("rozet kare", salvage.get_width() == salvage.get_height(), "")
	ck("rozet onbellekte", UiIcons.badge("salvage") == salvage, "")
	ck("iki rozet ayri", salvage != food, "")
	var img := salvage.get_image()
	var mid := img.get_width() / 2
	ck("rozetin ortasi opak", img.get_pixel(mid, mid).a > 0.85,
		"%.2f" % img.get_pixel(mid, mid).a)
	ck("rozetin kosesi bos", img.get_pixel(1, 1).a < 0.1,
		"%.2f" % img.get_pixel(1, 1).a)
	# The disc has to reach all four edges. UiIcons' painters clipped to the
	# 64px icon size rather than to the image, so the first badge came back
	# with its right and bottom thirds cut off square (G56).
	ck("rozet sag kenara ulasir", img.get_pixel(img.get_width() - 4, mid).a > 0.8,
		"%.2f" % img.get_pixel(img.get_width() - 4, mid).a)
	ck("rozet alt kenara ulasir", img.get_pixel(mid, img.get_height() - 4).a > 0.8,
		"%.2f" % img.get_pixel(mid, img.get_height() - 4).a)
	# Paper, not ink: every one of these drawings carries its shape in dark
	# strokes and needs a light ground under it.
	ck("rozetin zemini acik", img.get_pixel(mid, 8).get_luminance() > 0.45,
		"%.2f" % img.get_pixel(mid, 8).get_luminance())
	# The two badges have to differ in the middle, not just somewhere: it is the
	# icon inside the disc that says which pickup this is.
	var other := food.get_image()
	var apart := 0
	for x in range(mid - 12, mid + 12):
		if img.get_pixel(x, mid) != other.get_pixel(x, mid):
			apart += 1
	ck("rozetlerin ici farkli", apart > 6, str(apart))


## The mark on the object itself: same drawing, right size, hidden until the
## grass beside it opens.
func _marks() -> void:
	var root := Node3D.new()
	add_child(root)
	var scrap := SalvageProp.spawn(root, Vector3(3.0, 0.0, 4.0))
	var food := FoodProp.spawn(root, Vector3(5.0, 0.0, 2.0))
	var scrap_mark := scrap.get_node_or_null("Mark") as Sprite3D
	var food_mark := food.get_node_or_null("Mark") as Sprite3D
	ck("hurdanin isareti var", scrap_mark != null, "")
	ck("yiyecegin isareti var", food_mark != null, "")
	if scrap_mark == null or food_mark == null:
		root.queue_free()
		return
	ck("isaret sayacin ikonu", scrap_mark.texture == UiIcons.badge("salvage"), "")
	ck("yiyecek isareti kendi ikonu", food_mark.texture == UiIcons.badge("food"), "")
	ck("isaret kameraya doner",
		scrap_mark.billboard == BaseMaterial3D.BILLBOARD_ENABLED,
		str(scrap_mark.billboard))
	ck("isaret isiktan etkilenmez", not scrap_mark.shaded, "")
	var width := scrap_mark.pixel_size * float(scrap_mark.texture.get_width())
	ck("isaretin dunyadaki genisligi ayarli",
		absf(width - GameConfig.PICKUP_MARK_WIDTH) < 0.01, "%.3f m" % width)
	# Both marks end up at the same height above the ground, whatever their
	# prop's own origin does: the crate's is centred, the salvage's is not.
	var scrap_y := scrap.position.y + scrap_mark.position.y
	var food_y := food.position.y + food_mark.position.y
	ck("iki isaret ayni yukseklikte", absf(scrap_y - food_y) < 0.02,
		"%.3f / %.3f" % [scrap_y, food_y])
	ck("isaret otlarin ustunde",
		scrap_mark.position.y > GameConfig.PICKUP_MARK_WIDTH,
		"%.2f" % scrap_mark.position.y)
	# The rule the whole game is built on: the grass hides the world. A marker
	# over a prop nobody has uncovered would give away every pickup at once.
	ck("kesilmeden once gizli", not scrap.visible and not food.visible, "")
	scrap.reveal()
	ck("kesildikten sonra gorunur", scrap.visible and scrap_mark.visible, "")
	root.queue_free()


## The value that flies to the chip says what it is, and the chip says what its
## two numbers are.
func _flying() -> void:
	var game := await open("ch01_aldridge")
	var hud: Node = game.hud
	hud.fly_scrap(3, Vector2(400.0, 1200.0))
	hud.fly_food(2, Vector2(400.0, 1300.0))
	await frames(2)
	var scrap_said := false
	var food_said := false
	for any: Variant in hud.find_children("*", "Label", true, false):
		var text := (any as Label).text
		if text == tr("PICKUP_SCRAP").format({"n": 3}):
			scrap_said = true
		if text == tr("PICKUP_FOOD").format({"n": 2}):
			food_said = true
	ck("ucan hurda degeri adiyla yazilir", scrap_said, "")
	ck("ucan yiyecek degeri adiyla yazilir", food_said, "")
	var chip: Node = hud.find_child("WalletChip", true, false)
	ck("cuzdan seridi var", chip != null, "")
	var names := {}
	for any: Variant in chip.find_children("*", "Label", true, false):
		names[(any as Label).text] = true
	ck("serit hurdayi adlandirir", names.has(tr("WALLET_SALVAGE")),
		", ".join(names.keys()))
	ck("serit yiyecegi adlandirir", names.has(tr("WALLET_FOOD")), "")
	close(game)


## The table of steps: named once, translated, each with a page to open.
func _guide_table() -> void:
	var steps := Guide.steps()
	ck("yol gosterici adimlari var", steps.size() >= 3, str(steps.size()))
	var ids := {}
	var pages := {"restore": true, "workshop": true, "tiles": true}
	var ok_text := true
	var ok_page := true
	for any: Variant in steps:
		var step: Dictionary = any
		ids[str(step.get("id", ""))] = true
		if tr(str(step.get("line", ""))) == str(step.get("line", "")):
			ok_text = false
		if tr(str(step.get("button", ""))) == str(step.get("button", "")):
			ok_text = false
		if not pages.has(str(step.get("page", ""))):
			ok_page = false
	ck("adim kimlikleri tekil", ids.size() == steps.size(),
		"%d / %d" % [ids.size(), steps.size()])
	ck("her adimin metni cevrili", ok_text, "")
	ck("her adim gercek bir sayfa acar", ok_page, "")


## When each step is offered. This is the whole design: never during the
## prologue, never for a screen that cannot pay yet, one at a time, once each.
func _guide_order() -> void:
	var keep_scrap := GameState.scrap_total()
	var keep_done := {}
	for any: Variant in ChapterProgress.chapters():
		var vid := str((any as Dictionary).get("variant_id", ""))
		keep_done[vid] = ChapterProgress.is_done(vid)
	Guide.reset()
	ChapterProgress.reset()
	GameState.spend_scrap(GameState.scrap_total())
	GameState.add_scrap(4000)
	ck("hicbir bahce bitmemisken adim yok", Guide.next().is_empty(),
		str(Guide.next()))

	var first := str((ChapterProgress.chapters()[0] as Dictionary).get("variant_id", ""))
	ChapterProgress.record(first, 0, GameConfig.SECRET_TOTAL)
	ck("parasi varsa ilk adim onarim",
		str(Guide.next().get("id", "")) == "restore", str(Guide.next()))
	ck("bir seferde tek adim", Guide.next().size() > 0
		and str(Guide.next().get("id", "")) == "restore", "")
	Guide.mark("restore")
	ck("gosterilen adim bir daha gelmez",
		str(Guide.next().get("id", "")) != "restore", str(Guide.next()))
	ck("sonra atolye adimi",
		str(Guide.next().get("id", "")) == "workshop"
		and Guide.affordable_mower() >= 0, str(Guide.next()))
	Guide.mark("workshop")

	# Broke: nothing to spend, so neither shop is worth opening.
	Guide.reset()
	GameState.spend_scrap(GameState.scrap_total())
	ck("parasiz oyuncuya dukkan gosterilmez",
		not Guide.can_afford_project() and Guide.affordable_mower() < 0,
		"%d hurda" % GameState.scrap_total())
	var broke: Dictionary = Guide.next()
	ck("parasizken onarim adimi gelmez",
		str(broke.get("id", "")) != "restore" and str(broke.get("id", "")) != "workshop",
		str(broke))

	# The link step needs two finds that are known to say something together.
	DeductionLog.reset()
	var pair: Dictionary = DeductionLog.links()[0]
	var a := str(pair.get("a", ""))
	var b := str(pair.get("b", ""))
	ck("elde ciftin yoksa bag adimi yok", not Guide.pair_in_hand(), "")
	for side: String in [a, b]:
		var vid := DeductionLog.chapter_of(side)
		ChapterProgress.record(vid, LevelVariant.of(vid).evidence_count(),
			GameConfig.SECRET_TOTAL)
	ck("bulgu elde sayilir", Guide.holds(a) and Guide.holds(b), "%s + %s" % [a, b])
	ck("olmayan bulgu elde sayilmaz",
		not Guide.holds(DeductionLog.piece(DeductionLog.chapter_of(a), "yoktur")), "")
	ck("cift elde", Guide.pair_in_hand(), "")
	ck("bag adimi gelir", str(Guide.next().get("id", "")) == "link",
		str(Guide.next()))
	DeductionLog.make(a, b)
	ck("bag kurulduysa adim susar", str(Guide.next().get("id", "")) != "link",
		str(Guide.next()))

	DeductionLog.reset()
	Guide.reset()
	ChapterProgress.reset()
	for key: Variant in keep_done:
		if bool(keep_done[key]):
			ChapterProgress.record(str(key), 0, GameConfig.SECRET_TOTAL)
	GameState.spend_scrap(GameState.scrap_total())
	GameState.add_scrap(keep_scrap)


## The note on the hub: it opens the page it is about, types itself, and its
## button both records the step and closes it. Navigating away also closes it.
func _guide_note() -> void:
	GameConfig.text_instant = false
	Guide.reset()
	var layer := CanvasLayer.new()
	add_child(layer)
	var hub := HubScreen.new()
	layer.add_child(hub)
	await frames(6)
	hub.set_diorama_active(true)
	hub.refresh()
	await frames(2)

	var step: Dictionary = Guide.steps()[0]
	hub.run_guide_step(step)
	await frames(2)
	var note: Node = hub.find_child("GuideNote", true, false)
	ck("yol gosterici notu acilir", note != null, "")
	ck("notun sayfasi acildi", hub._restore_page.visible, "")
	ck("kutucuklar sayfasi kapandi", not hub._tiles_page.visible, "")
	if note == null:
		hub.queue_free()
		layer.queue_free()
		return
	var line: Label = note.find_child("GuideLine", true, false)
	ck("notun cumlesi yerinde", line != null and line.text == tr(str(step.get("line", ""))),
		"" if line == null else line.text)
	ck("notun cumlesi yazilir", hub._guide_typer.typing()
		and line.visible_characters != -1,
		"" if line == null else str(line.visible_characters))
	var go: Button = note.find_child("GuideGo", true, false)
	ck("notun butonu var", go != null and go.text == tr(str(step.get("button", ""))),
		"" if go == null else go.text)
	ck("adim daha isaretlenmedi", not Guide.is_shown(str(step.get("id", ""))), "")
	go.pressed.emit()
	await frames(3)
	ck("buton adimi isaretler", Guide.is_shown(str(step.get("id", ""))), "")
	ck("buton notu kapatir", hub.find_child("GuideNote", true, false) == null, "")

	# Navigating away by hand also closes it: the note belongs to its page.
	Guide.reset()
	hub.run_guide_step(step)
	await frames(2)
	ck("not yeniden acilir", hub.find_child("GuideNote", true, false) != null, "")
	hub.open_map()
	await frames(3)
	ck("baska sayfaya gecince not kapanir",
		hub.find_child("GuideNote", true, false) == null, "")
	hub.queue_free()
	layer.queue_free()
	await frames(2)
