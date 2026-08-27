extends Node
## G13: Case 02's data is complete and its text actually exists.
##
## The failure this catches is the quiet one. A chapter whose brief key has no
## row in strings.csv still PLAYS — the TranslationServer hands back the key
## unchanged, so the briefing reads "DLG_BRIEF_CH09_1" and nothing errors. Every
## key referenced by a Case 02 chapter is resolved here instead, so an unwritten
## line is a failed test rather than a shipped one.

var _fails := 0


func _ready() -> void:
	var chapters := Story.list("case_02.chapters")
	ck("vaka 02 bolumleri var", not chapters.is_empty(), str(chapters.size()))

	for chapter: Dictionary in chapters:
		var vid := str(chapter.get("variant_id", ""))
		_check_chapter(vid, chapter)

	_check_gate()
	_check_case_shell()

	if _fails > 0:
		push_error("%d VAKA 02 TESTI BASARISIZ" % _fails)
		print("--- %d VAKA 02 TESTI BASARISIZ ---" % _fails)
	else:
		print("--- TUM VAKA 02 TESTLERI GECTI (%d bolum) ---" % chapters.size())
	get_tree().quit()


func _check_chapter(vid: String, chapter: Dictionary) -> void:
	# ARCHITECTURE: a chapter is an id, never a scene. Same rule as Case 01.
	ck("bolum sahne yolu tasimiyor: %s" % vid,
		not chapter.has("scene") and not chapter.has("path"), str(chapter))
	ck("varyant tanimli: %s" % vid, LevelVariant.ids().has(vid), vid)
	_key("bolum adi: %s" % vid, str(chapter.get("name", "")))

	var variant := LevelVariant.of(vid)
	ck("paleti taniniyor: %s" % vid,
		GameConfig.GRASS_PALETTES.has(variant.palette_id), variant.palette_id)
	ck("gunun saati taniniyor: %s" % vid,
		GameConfig.TIME_OF_DAY.has(variant.time_of_day), variant.time_of_day)
	ck("izgara boyu taniniyor: %s" % vid,
		GameConfig.GRID_SIZES.has(variant.grid_size), variant.grid_size)
	ck("hurda butcesi makul: %s" % vid,
		variant.scrap_budget >= 6 and variant.scrap_budget <= 24,
		str(variant.scrap_budget))
	_key("acilis basligi: %s" % vid, variant.opening_headline)
	_key("acilis alt satiri: %s" % vid, variant.opening_subline)
	_key("geri alim satiri: %s" % vid, variant.reclaim_line)

	ck("iki kanit var: %s" % vid, variant.evidence_defs.size() == 2,
		str(variant.evidence_defs.size()))
	for i in variant.evidence_defs.size():
		var info := variant.evidence_info(i)
		var tag := "%s#%d" % [vid, i]
		_key("kanit adi: %s" % tag, str(variant.evidence_defs[i].get("name", "")))
		_key("kanit satiri: %s" % tag,
			str(variant.evidence_defs[i].get("flavor_text", "")))
		_key("kanit yeri: %s" % tag,
			str(variant.evidence_defs[i].get("location_tag", "")))
		_key("cole notu: %s" % tag, str(info.get("cole_note", "")))
		_key("marshal notu: %s" % tag, str(info.get("marshal_note", "")))
		# The reveal card renders the object, so the id must have a mesh — an
		# unknown id silently falls back to the radio, in every chapter.
		ck("kanit modeli var: %s" % tag,
			SecretItem.has_mesh_for(str(info.get("id", ""))), str(info.get("id", "")))

	var echo := variant.echo_info()
	ck("yanki tanimli: %s" % vid, not echo.is_empty(), "")
	if not echo.is_empty():
		_key("yanki adi: %s" % vid, str(variant.echo_def.get("name", "")))
		_key("yanki satiri: %s" % vid, str(variant.echo_def.get("flavor_text", "")))

	# Briefing and both debriefs, with every line resolved.
	_check_conversation("brifing: %s" % vid, str(chapter.get("brief", "")))
	_check_conversation("tam bilgi: %s" % vid, str(chapter.get("debrief_full", "")))
	_check_conversation("kismi bilgi: %s" % vid,
		str(chapter.get("debrief_partial", "")))


func _check_conversation(label: String, key: String) -> void:
	var lines := Dialogue.conversation(key)
	ck("%s dolu" % label, not lines.is_empty(), key)
	for entry: Dictionary in lines:
		if entry.has("choice"):
			var options: Array = (entry["choice"] as Dictionary).get("options", [])
			ck("%s secim 2 secenek" % label, options.size() == 2,
				str(options.size()))
			for option: Dictionary in options:
				_key("%s secenek" % label, str(option.get("text", "")))
				var reply: Dictionary = option.get("reply", {})
				_key("%s tepki" % label, str(reply.get("text", "")))
				_speaker("%s tepki" % label, str(reply.get("speaker", "")))
			continue
		_key("%s satir" % label, str(entry.get("text", "")))
		_speaker("%s satir" % label, str(entry.get("speaker", "")))


## Case 02 must stay shut until the town is ready — that is Ellie's closing line
## turned into a rule, and the whole reason the restore board earns anything.
func _check_gate() -> void:
	var was_closed: Variant = GameState.get_setting("story", "case01_closed", false)
	GameState.set_setting("story", "case01_closed", false)
	ck("vaka 01 kapanmadan vaka 02 kapali",
		not ChapterProgress.case_two_open(), "")
	GameState.set_setting("story", "case01_closed", true)
	var ready := RestoreBoard.town_ready()
	ck("kilit onarim sayisina bagli",
		ChapterProgress.case_two_open() == ready,
		"kasaba hazir=%s" % str(ready))
	GameState.set_setting("story", "case01_closed", was_closed)
	ck("esik uc proje", GameConfig.TOWN_READY_PROJECTS == 3,
		str(GameConfig.TOWN_READY_PROJECTS))


func _check_case_shell() -> void:
	for key in ["id", "title", "objective", "hud_line"]:
		_key("vaka 02 %s" % key, str(Story.get_value("case_02." + key, "")))
	# Case 01's ending must still belong to Case 01 now that the board carries
	# both: the cellar is the last chapter of its CASE, not of the list.
	var case_one := Story.list("chapters")
	var last := str((case_one.back() as Dictionary).get("variant_id", ""))
	ck("vaka 01 sonu hala bodrum", last == "ch08_cellar", last)
	ck("case_of dogru vakayi buluyor",
		ChapterProgress.case_of("ch09_radio_room").size()
			== Story.list("case_02.chapters").size(), "")


## A key that has no row in strings.csv comes back from the TranslationServer
## unchanged. That is the whole bug this test exists for.
func _key(label: String, key: String) -> void:
	if key == "":
		_fails += 1
		print("  FAIL %s  (anahtar bos)" % label)
		return
	var value := TranslationServer.translate(key)
	ck("%s -> %s" % [label, key], value != key, "cevirisi yok")


func _speaker(label: String, id: String) -> void:
	ck("%s konusmacisi taniniyor" % label, Dialogue.speakers().has(id), id)


func ck(what: String, passed: bool, detail: String) -> void:
	if passed:
		return
	_fails += 1
	print("  FAIL %s  %s" % [what, detail])
