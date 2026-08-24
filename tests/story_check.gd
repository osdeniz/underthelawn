extends SceneTree
## G7: every narrative string the UI asks for must exist in data/story.json.
##
## The UI falls back to placeholder text for a missing key rather than crashing,
## which is the right runtime behaviour but hides typos completely — so the
## contract is checked here instead.

var _fails := 0


func _initialize() -> void:
	# A path that must resolve to a non-empty string.
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

	# The English narrative must not carry leftover Turkish placeholder names.
	for stale in ["Paslı Anahtar", "Eski Radyo"]:
		ck("eski metin yok: %s" % stale,
			not FileAccess.get_file_as_string(Story.PATH).contains(stale), "")

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
