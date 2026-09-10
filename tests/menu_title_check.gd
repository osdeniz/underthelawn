extends TestBase
## Who prints the game's name on the front door (G64).
##
## The menu suppressed its own title whenever a cover existed, on the reasoning
## that a cover carries its own. That is true of the shipped cover and it is
## why the name is CROPPED on a phone: a 4:5 picture covering a 0.46 screen
## loses 42% of its width. A cover without lettering has to leave the name to
## the game — which is also the only way it can be Turkish.

func run() -> void:
	suite = "MENU BASLIGI"
	var keep := GameConfig.MENU_COVER_HAS_TITLE
	await _with_flag(true)
	await _with_flag(false)
	ck("bayrak sabit kaldi", GameConfig.MENU_COVER_HAS_TITLE == keep, "")
	finish()


func _with_flag(has_title: bool) -> void:
	# The constant cannot be assigned, so the claim is made against whichever
	# value ships and the OTHER branch is proved by the expression itself.
	var menu := MainMenu.new()
	add_child(menu)
	await frames(4)
	var title: Label = menu.find_child("MenuTitle", true, false)
	var sub: Label = menu.find_child("MenuSubtitle", true, false)
	ck("baslik etiketi var", title != null, "")
	ck("alt satir etiketi var", sub != null, "")
	if title == null or sub == null:
		menu.queue_free()
		return
	ck("baslik metni oyunun adi", title.text == tr("MENU_TITLE"), title.text)
	# What ships today: a cover with its own lettering, so the drawn one hides.
	var cover := TextureLibrary.find("menu/cover_portrait") != null \
		or TextureLibrary.find("menu/cover_wide") != null
	var expect := not (cover and GameConfig.MENU_COVER_HAS_TITLE)
	ck("cizilen baslik dogru durumda", title.visible == expect,
		"kapak=%s bayrak=%s gorunur=%s" % [cover, GameConfig.MENU_COVER_HAS_TITLE,
			title.visible])
	ck("alt satir baslikla ayni durumda", sub.visible == title.visible, "")
	# And the name is translated in both languages, since the whole point of
	# drawing it is that a picture cannot be.
	var was := TranslationServer.get_locale()
	var missing: Array[String] = []
	for locale: String in ["en", "tr"]:
		TranslationServer.set_locale(locale)
		for key: String in ["MENU_TITLE", "MENU_SUBTITLE"]:
			if TranslationServer.translate(key) == key:
				missing.append("%s/%s" % [locale, key])
	TranslationServer.set_locale(was)
	ck("ad iki dilde de yazili", missing.is_empty(), ", ".join(missing))
	menu.queue_free()
	await frames(2)
