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
	_check_plants()
	_check_quiet_scenes()
	_check_east_road()

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

	# A chapter may carry mid-chapter conversations; if it names one it has to
	# exist, or the beat silently never fires (G13).
	for i in variant.mid_chat_marks().size():
		var key := variant.mid_chat_key(i)
		ck("mola sohbeti anahtari dolu: %s#%d" % [vid, i], key != "", "")
		if key != "":
			_check_conversation("mola sohbeti: %s#%d" % [vid, i], key)
		var mark := float(variant.mid_chat_marks()[i])
		ck("mola sohbeti orani makul: %s#%d" % [vid, i],
			mark > 0.05 and mark < 0.95, "%.2f" % mark)

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


## Every plant a chapter asks for has to be a profile the builder knows, and a
## stalk profile has to say how wide its stalk is — a missing field silently
## falls back to grass numbers and grows two-metre blades of lawn.
func _check_plants() -> void:
	for chapter: Dictionary in Story.list("case_02.chapters"):
		var vid := str(chapter.get("variant_id", ""))
		var id := LevelVariant.of(vid).plant_profile_id
		ck("bitki profili taniniyor: %s" % vid,
			GameConfig.PLANT_PROFILES.has(id), id)
	for id: String in GameConfig.PLANT_PROFILES:
		var was := GameConfig.active_plant_profile
		GameConfig.active_plant_profile = id
		var form := str(GameConfig.plant("form", ""))
		ck("profil formu gecerli: %s" % id, form in ["blade", "stalk"], form)
		ck("profil yogunlugu var: %s" % id,
			int(GameConfig.plant("per_cell", 0)) > 0, id)
		ck("profil boyu artan: %s" % id,
			float(GameConfig.plant("height_max", 0.0))
				> float(GameConfig.plant("height_min", 0.0)), id)
		if form == "stalk":
			ck("govde genisligi var: %s" % id,
				float(GameConfig.plant("stalk_width", 0.0)) > 0.0, id)
			# The whole point of corn is that it is taller than the machine.
			ck("govde makineden yuksek: %s" % id,
				float(GameConfig.plant("height_min", 0.0)) > 1.2, id)
		GameConfig.active_plant_profile = was


## A quiet scene is data: if a chapter names one, the scene, its conversation
## and its consequence all have to be there.
func _check_quiet_scenes() -> void:
	for chapter: Dictionary in Story.list("case_02.chapters"):
		var scene_id := str(chapter.get("quiet_scene", ""))
		if scene_id == "":
			continue
		var spec: Variant = Story.get_value("quiet_scenes." + scene_id, {})
		ck("sessiz sahne tanimli: %s" % scene_id, spec is Dictionary
			and not (spec as Dictionary).is_empty(), scene_id)
		if not (spec is Dictionary):
			continue
		var dict := spec as Dictionary
		_check_conversation("sessiz sahne: %s" % scene_id,
			str(dict.get("dialogue", "")))
		if str(dict.get("after_dialogue", "")) != "":
			_check_conversation("sahne sonrasi: %s" % scene_id,
				str(dict.get("after_dialogue", "")))
		ck("sahne bedeli taniniyor: %s" % scene_id,
			str(dict.get("consequence", "")) in ["", "scrap_toll"],
			str(dict.get("consequence", "")))
	# The toll must be able to cost something without ever costing everything.
	ck("gecis bedeli tabani makul", GameConfig.TOLL_SCRAP_MIN > 0
		and GameConfig.TOLL_SCRAP_MIN < GameConfig.TOLL_SCRAP_MAX,
		"%d..%d" % [GameConfig.TOLL_SCRAP_MIN, GameConfig.TOLL_SCRAP_MAX])
	# spend_scrap must never write a negative wallet — three call sites used to
	# subtract by hand and none of them clamped.
	var before := GameState.scrap_total()
	GameState.set_setting("economy", "scrap", 40)
	var taken := GameState.spend_scrap(999)
	ck("harcama cuzdani eksiye dusurmez",
		GameState.scrap_total() == 0 and taken == 40,
		"%d kaldi, %d alindi" % [GameState.scrap_total(), taken])
	GameState.set_setting("economy", "scrap", before)


## The road east: every stop is a real chapter, and the stops run eastward.
func _check_east_road() -> void:
	var pins := Story.list("east_road.pins")
	ck("dogu yolu duraklari var", pins.size() >= 4, str(pins.size()))
	_key("dogu yolu basligi", str(Story.get_value("east_road.title", "")))
	_key("dogu yolu alt basligi", str(Story.get_value("east_road.sub", "")))
	var last_x := float(GameConfig.MAP_TOWN_AT.x)
	for pin: Dictionary in pins:
		var vid := str(pin.get("chapter", ""))
		ck("durak bir bolum: %s" % vid, LevelVariant.ids().has(vid), vid)
		var x := float(pin.get("x", 0.0))
		var y := float(pin.get("y", 0.0))
		ck("durak sayfada: %s" % vid, x > 0.0 and x < 1.0 and y > 0.0 and y < 1.0,
			"%.2f,%.2f" % [x, y])
		ck("yol doguya gidiyor: %s" % vid, x > last_x, "%.3f <= %.3f" % [x, last_x])
		last_x = x


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
