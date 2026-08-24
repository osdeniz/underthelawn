extends SceneTree
## G7: every narrative string the UI asks for must exist in data/story.json.
##
## The UI falls back to placeholder text for a missing key rather than crashing,
## which is the right runtime behaviour but hides typos completely — so the
## contract is checked here instead.

## Every story.json field that must hold a translation key.
const STORY_KEY_PATHS: Array[String] = [
	"case.id", "case.title", "case.objective", "case.hud_line",
	"hub.progress", "hub.locked_note",
	"case_board.title", "case_board.evidence", "case_board.locked",
	"case_board.active", "case_board.done",
	"town.title", "complete.return",
	"opening.headline", "opening.subline",
	"evidence.card_header", "evidence.counter_label",
	"complete.title", "complete.notes_header", "complete.notes_full",
	"complete.notes_partial", "complete.incomplete",
	"complete.teaser_title", "complete.teaser_line",
	"complete.teaser_locked", "intro.skip_hint",
]

var _fails := 0


func _initialize() -> void:
	# Each of these must resolve, through the key, to a non-empty sentence.
	for path in [
		"case.hud_line", "case.id", "case.title", "case.objective",
		"opening.headline", "opening.subline",
		"evidence.card_header", "evidence.counter_icon", "evidence.counter_label",
		"complete.title", "complete.notes_header", "complete.notes_full",
		"complete.notes_partial", "complete.incomplete",
		"complete.teaser_title", "complete.teaser_line", "complete.teaser_locked",
		"intro.skip_hint",
	]:
		var value := Story.text(path, "")
		ck("metin %s" % path, value != "", "'%s'" % value)

	# Exactly three opening cards, each with art and one or two lines.
	var cards := Story.list("intro.cards")
	ck("aciliş kart sayisi", cards.size() == 3, str(cards.size()))
	for i in cards.size():
		var card: Dictionary = cards[i]
		ck("kart %d gorseli" % i, str(card.get("image", "")) != "", str(card))
		var lines: Array = card.get("lines", [])
		ck("kart %d satir sayisi (1-2)" % i,
			lines.size() >= 1 and lines.size() <= 2, str(lines.size()))

	# One evidence entry per secret the lawn actually places, or the completion
	# panel would show a slot with no name.
	var items := Story.list("evidence.items")
	ck("kanit sayisi = SECRET_TOTAL", items.size() == GameConfig.SECRET_TOTAL,
		"%d / %d" % [items.size(), GameConfig.SECRET_TOTAL])
	for i in items.size():
		var item: Dictionary = items[i]
		for key in ["emoji", "name", "line"]:
			ck("kanit %d.%s" % [i, key], str(item.get(key, "")) != "", str(item))
		# SecretItem.info_for must reach the story data, not its own fallback.
		var info := SecretItem.info_for(i)
		ck("info_for(%d) story'den geliyor" % i,
			info.get("name", "") == item.get("name", ""), str(info))

	# --- i18n contract -------------------------------------------------------
	# The json must hold KEYS, not sentences: every key it names has to exist in
	# i18n/strings.csv, and none of them may look like prose.
	# Parsed with get_csv_line, NOT split(","): half these strings contain commas
	# inside quotes and a plain split would shred them.
	var locales: Array[String] = []
	var rows: Array = []
	var file := FileAccess.open("res://i18n/strings.csv", FileAccess.READ)
	ck("strings.csv okunabiliyor", file != null, "")
	if file != null:
		var header := file.get_csv_line()
		for i in range(1, header.size()):
			if header[i].strip_edges() != "":
				locales.append(header[i].strip_edges())
		while not file.eof_reached():
			var row := file.get_csv_line()
			if row.size() >= 2 and row[0].strip_edges() != "":
				rows.append(row)
		file.close()

	var known := {}
	for row: PackedStringArray in rows:
		known[row[0].strip_edges()] = row
	ck("csv anahtar sayisi", known.size() > 30, str(known.size()))
	ck("en az iki dil kolonu", locales.size() >= 2, str(locales))

	for path in STORY_KEY_PATHS:
		var key := Story.raw(path, "")
		ck("csv'de var: %s -> %s" % [path, key], known.has(key), key)
		# A key never contains a space; a sentence always does. This is what
		# catches someone pasting prose back into the json.
		ck("anahtar gibi gorunuyor: %s" % path, not key.contains(" "), key)

	for i in Story.list("intro.cards").size():
		for j in 2:
			var key := Story.raw("intro.cards.%d.lines.%d" % [i, j], "")
			ck("kart %d satir %d csv'de" % [i, j], known.has(key), key)

	for i in Story.list("evidence.items").size():
		for field in ["name", "line"]:
			var key := Story.raw("evidence.items.%d.%s" % [i, field], "")
			ck("kanit %d.%s csv'de" % [i, field], known.has(key), key)

	# G8: hub tiles, chapter names, town people.
	for tile: Dictionary in Story.list("hub.tiles"):
		for field in ["label", "hint"]:
			var key := str(tile.get(field, ""))
			ck("hub karti %s csv'de" % key, known.has(key), key)
	for chapter: Dictionary in Story.list("chapters"):
		var key := str(chapter.get("name", ""))
		ck("bolum adi csv'de %s" % key, known.has(key), key)
	for person: Dictionary in Story.list("town.people"):
		for field in ["name", "role"]:
			var key := str(person.get(field, ""))
			ck("kasaba %s csv'de" % key, known.has(key), key)

	# Every dialogue line, in every conversation and every town variant.
	for entry: Dictionary in _all_dialogue_entries():
		if entry.has("text"):
			var key := str(entry["text"])
			ck("diyalog satiri csv'de: %s" % key, known.has(key), key)
		if entry.has("choice"):
			for option: Dictionary in entry["choice"].get("options", []):
				ck("secenek csv'de: %s" % option.get("text", ""),
					known.has(str(option.get("text", ""))), str(option))
	# A speaker id doubles as a portrait file name, so it must be a known
	# character or the portrait silently falls back forever.
	for entry: Dictionary in _all_dialogue_entries():
		if entry.has("speaker"):
			ck("konusmaci taninir: %s" % entry["speaker"],
				Dialogue.speakers().has(str(entry["speaker"])), str(entry))
			ck("konusmaci adi csv'de",
				known.has("CHAR_" + str(entry["speaker"]).to_upper()), str(entry))

	# Mower labels are keys too (they show in the picker).
	for entry: Dictionary in GameConfig.MOWER_TYPES:
		var key := str(entry["label"])
		ck("mower etiketi csv'de: %s" % key, known.has(key), key)

	# The UI's own strings.
	for key in ["UI_PERCENT_MOWED", "UI_EVIDENCE_COUNTER", "UI_STATS",
			"UI_RESTART", "UI_STORY", "UI_EMPTY_SLOT", "UI_NOTHING_RECOVERED",
			"UI_BACK", "UI_RETURN_TOWN"]:
		ck("UI anahtari csv'de: %s" % key, known.has(key), key)

	# Placeholders must be NAMED, so a translator can reorder them. A positional
	# %d cannot move; {pct} can.
	for pair in [["UI_PERCENT_MOWED", "{pct}"], ["UI_STATS", "{cells}"],
			["UI_STATS", "{time}"], ["UI_EVIDENCE_COUNTER", "{found}"]]:
		var raw_text := TranslationServer.translate(pair[0])
		ck("%s icinde %s" % [pair[0], pair[1]], raw_text.contains(pair[1]), raw_text)

	# Every key must be filled in for EVERY language, or that language silently
	# shows English (or the bare key) at that spot.
	for key: String in known:
		var row: PackedStringArray = known[key]
		for i in locales.size():
			var column := i + 1
			var value := row[column].strip_edges() if column < row.size() else ""
			ck("%s / %s dolu" % [key, locales[i]], value != "", "")

	# The English column must not carry Turkish leftovers. Checked on the COLUMN,
	# not the whole file — the Turkish column contains these words on purpose.
	for key: String in known:
		var english: String = (known[key] as PackedStringArray)[1]
		for letter in ["ı", "ş", "ğ", "İ", "Ş", "Ğ", "â"]:
			ck("en kolonunda Turkce harf yok (%s)" % key,
				not english.contains(letter), english)

	# Named placeholders have to survive translation in every language, or that
	# language crashes into a literal "{cells}" on screen.
	for key in ["UI_PERCENT_MOWED", "UI_STATS", "UI_EVIDENCE_COUNTER"]:
		var row: PackedStringArray = known[key]
		var expected := _placeholders(row[1])
		for i in locales.size():
			var column := i + 1
			if column >= row.size():
				continue
			ck("%s / %s yer tutuculari ayni" % [key, locales[i]],
				_placeholders(row[column]) == expected,
				"%s vs %s" % [expected, _placeholders(row[column])])

	# Each language must actually resolve, and must differ from English so a
	# forgotten copy-paste does not pass as a translation.
	var original_locale := TranslationServer.get_locale()
	for locale in locales:
		TranslationServer.set_locale(locale)
		ck("%s yuklendi" % locale,
			TranslationServer.get_locale().begins_with(locale), TranslationServer.get_locale())
		var title := TranslationServer.translate("COMPLETE_01_TITLE")
		ck("%s icin baslik cozuldu" % locale,
			title != "" and title != "COMPLETE_01_TITLE", title)
		if locale != "en":
			ck("%s ingilizceden farkli" % locale,
				title != (known["COMPLETE_01_TITLE"] as PackedStringArray)[1], title)
	TranslationServer.set_locale(original_locale)

	# Prove the pipeline end to end WITHOUT inventing a translation. Godot's
	# pseudolocalization rewrites whatever passes through the TranslationServer,
	# so this shows the key -> csv -> screen path really works. It does NOT prove
	# every on-screen string uses it; run the game with
	# internationalization/pseudolocalization/use_pseudolocalization=true and
	# look for text that stayed plain to find the ones that bypass tr().
	var before := TranslationServer.translate("COMPLETE_01_TITLE")
	TranslationServer.pseudolocalization_enabled = true
	var after := TranslationServer.translate("COMPLETE_01_TITLE")
	TranslationServer.pseudolocalization_enabled = false
	ck("pseudolocalization stringi degistiriyor", after != before,
		"%s -> %s" % [before, after])
	ck("pseudolocalization kapaninca geri donuyor",
		TranslationServer.translate("COMPLETE_01_TITLE") == before, "")

	# Locale helpers, which decide mirroring and font fallback.
	ck("arapca RTL", LocaleSupport.is_rtl("ar_SA"), "")
	ck("ingilizce RTL degil", not LocaleSupport.is_rtl("en_US"), "")
	ck("cince genis glif istiyor",
		LocaleSupport.needs_extended_glyphs("zh_CN"), "")
	ck("ingilizce genis glif istemiyor",
		not LocaleSupport.needs_extended_glyphs("en"), "")

	if _fails > 0:
		push_error("%d ANLATI TESTI BASARISIZ" % _fails)
		print("--- %d ANLATI TESTI BASARISIZ ---" % _fails)
	else:
		print("--- TUM ANLATI TESTLERI GECTI ---")
	quit()


## Every line entry across every conversation and every town variant.
func _all_dialogue_entries() -> Array:
	var out: Array = []
	var conversations: Variant = Dialogue.data().get("conversations", {})
	if conversations is Dictionary:
		for id: String in conversations:
			out.append_array(Dialogue.conversation(id))
	var town: Variant = Dialogue.data().get("town", {})
	if town is Dictionary:
		for person: String in town:
			for variant: Dictionary in (town as Dictionary)[person]:
				out.append_array(variant.get("lines", []))
	return out


## The set of {name} placeholders in a string, so the same set can be required
## of every translation of it.
func _placeholders(text: String) -> Array:
	var found: Array = []
	var depth := 0
	var current := ""
	for i in text.length():
		var c := text[i]
		if c == "{":
			depth = 1
			current = ""
		elif c == "}" and depth == 1:
			depth = 0
			found.append(current)
		elif depth == 1:
			current += c
	found.sort()
	return found


func ck(label: String, passed: bool, detail: String) -> void:
	if passed:
		return
	_fails += 1
	print("  FAIL %s  %s" % [label, detail])
