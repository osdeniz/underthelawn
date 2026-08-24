extends SceneTree
## G7: every narrative string the UI asks for must exist in data/story.json.
##
## The UI falls back to placeholder text for a missing key rather than crashing,
## which is the right runtime behaviour but hides typos completely — so the
## contract is checked here instead.

## Every story.json field that must hold a translation key.
const STORY_KEY_PATHS: Array[String] = [
	"case.id", "case.title", "case.objective", "case.hud_line",
	"briefing.speaker", "briefing.body", "briefing.accept",
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
		"briefing.speaker", "briefing.portrait", "briefing.body", "briefing.accept",
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
	var csv := FileAccess.get_file_as_string("res://i18n/strings.csv")
	var known := {}
	for line in csv.split("\n"):
		var key := line.split(",")[0].strip_edges()
		if key != "" and key != "keys":
			known[key] = true
	ck("csv anahtar sayisi", known.size() > 30, str(known.size()))

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

	# Mower labels are keys too (they show in the picker).
	for entry: Dictionary in GameConfig.MOWER_TYPES:
		var key := str(entry["label"])
		ck("mower etiketi csv'de: %s" % key, known.has(key), key)

	# The UI's own strings.
	for key in ["UI_PERCENT_MOWED", "UI_EVIDENCE_COUNTER", "UI_STATS",
			"UI_RESTART", "UI_STORY", "UI_EMPTY_SLOT", "UI_NOTHING_RECOVERED"]:
		ck("UI anahtari csv'de: %s" % key, known.has(key), key)

	# Placeholders must be NAMED, so a translator can reorder them. A positional
	# %d cannot move; {pct} can.
	for pair in [["UI_PERCENT_MOWED", "{pct}"], ["UI_STATS", "{cells}"],
			["UI_STATS", "{time}"], ["UI_EVIDENCE_COUNTER", "{found}"]]:
		var raw_text := TranslationServer.translate(pair[0])
		ck("%s icinde %s" % [pair[0], pair[1]], raw_text.contains(pair[1]), raw_text)

	# No Turkish left in anything the player reads.
	for stale in ["biçildi", "süre", "Paslı", "Eski Radyo", "Traktör"]:
		ck("eski Turkce metin yok: %s" % stale,
			not csv.contains(stale), "")

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


func ck(label: String, passed: bool, detail: String) -> void:
	if passed:
		return
	_fails += 1
	print("  FAIL %s  %s" % [label, detail])
