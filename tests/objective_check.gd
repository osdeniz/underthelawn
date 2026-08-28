extends Node
## G14.2: the mission compass shows what is already true, and pays once.

var _fails := 0


func _ready() -> void:
	GameState.set_setting("meta", "orientation_done", true)
	ChapterProgress.reset()
	RestoreBoard.reset()
	Objectives.reset()
	GameState.set_setting("harvest", "runs", 0)
	GameState.set_setting("harvest", "since_chapter", 0)

	# --- the file itself
	ck("gorevler tanimli", Objectives.all().size() >= 3,
		"%d gorev" % Objectives.all().size())
	for any: Variant in Objectives.all():
		var spec: Dictionary = any
		var id := str(spec.get("id", ""))
		ck("%s basligi var" % id, str(spec.get("title", "")) != "", "")
		ck("%s turu tanimli" % id,
			str(spec.get("type", "")) in ["case", "town", "harvest"],
			str(spec.get("type", "")))
		ck("%s kosulu var" % id, (spec.get("conditions", []) as Array).size() > 0, "")
		# Every check must resolve to something this build understands, or the
		# screen would quietly show a condition that can never tick.
		for cond_any: Variant in spec.get("conditions", []):
			var check := str((cond_any as Dictionary).get("check", ""))
			ck("%s kontrolu cozumleniyor: %s" % [id, check],
				check.split(":")[0] in ["chapter", "chapters", "restore",
					"garage", "projects", "harvest"], check)
	# V2 lands in the same list, so the skeleton has to exist and be empty.
	ck("vaka 2 iskeleti var", Objectives.data().has("case_02"), "")

	# --- nothing invented: the case objective mirrors the chapter list
	var ellie := Objectives.of("find_ellie")
	ck("ellie gorevi 8 adim",
		(ellie.get("conditions", []) as Array).size() == 8,
		str((ellie.get("conditions", []) as Array).size()))
	var state := Objectives.state("find_ellie")
	ck("basta hicbir adim tamam degil", _done_count(state) == 0,
		"%d tamam" % _done_count(state))
	var chapters: Array = Story.list("chapters")
	ChapterProgress.record(str((chapters[0] as Dictionary).get("variant_id", "")), 2, 2)
	state = Objectives.state("find_ellie")
	ck("bir bolum bir tik", _done_count(state) == 1, "%d tamam" % _done_count(state))

	# --- the harvest objective agrees with the invitation itself
	var winter := Objectives.state("winter_store")
	ck("kis stogu 3 kosul", (winter["steps"] as Array).size() == 3,
		str((winter["steps"] as Array).size()))
	ck("sayac gosteriliyor",
		str(((winter["steps"] as Array)[2] as Dictionary)["progress"]) == "1/3",
		str(((winter["steps"] as Array)[2] as Dictionary)["progress"]))
	GameState.set_setting("restore", "farm", true)
	GameState.set_setting("garage", "tractor_unlocked", true)
	for i in range(1, 3):
		ChapterProgress.record(str((chapters[i] as Dictionary).get("variant_id", "")), 2, 2)
	winter = Objectives.state("winter_store")
	ck("kosullar dolunca dorduncu adim cikar",
		(winter["steps"] as Array).size() == 4,
		str((winter["steps"] as Array).size()))
	ck("hazir ama bitmis degil", winter["ready"] and not winter["met"], "")
	ck("gorev ile davet ayni fikirde",
		HarvestLog.is_offered() == winter["ready"], "")

	# --- paid exactly once
	var before := GameState.scrap_total()
	HarvestLog.record()
	var earned := Objectives.collect()
	ck("hasat gorevi tamamlandi", earned.size() == 1,
		"%d gorev" % earned.size())
	var reward := int(Objectives.of("winter_store").get("reward_scrap", 0))
	ck("odul odendi", GameState.scrap_total() == before + reward,
		"%d -> %d" % [before, GameState.scrap_total()])
	var again := Objectives.collect()
	ck("odul iki kez odenmez", again.is_empty(), "%d" % again.size())
	ck("tamamlanan sayilmiyor",
		Objectives.active_count() == Objectives.all().size() - 1,
		str(Objectives.active_count()))

	# --- the screen actually fills
	var hub := HubScreen.new()
	add_child(hub)
	for _i in 20:
		await get_tree().process_frame
	hub.refresh()
	for _i in 10:
		await get_tree().process_frame
	var cards := hub.find_children("Objective_*", "", true, false)
	ck("ekranda gorev karti var", cards.size() == Objectives.all().size(),
		"%d kart" % cards.size())
	ck("rozet butonu var",
		hub.find_children("ObjectivesButton", "", true, false).size() == 1, "")
	hub.queue_free()

	ChapterProgress.reset()
	RestoreBoard.reset()
	Objectives.reset()
	GameState.set_setting("harvest", "runs", 0)
	if _fails > 0:
		push_error("%d GOREV TESTI BASARISIZ" % _fails)
		print("--- %d GOREV TESTI BASARISIZ ---" % _fails)
	else:
		print("--- TUM GOREV TESTLERI GECTI ---")
	get_tree().quit()


func _done_count(state: Dictionary) -> int:
	var n := 0
	for any: Variant in state["steps"]:
		if bool((any as Dictionary)["done"]):
			n += 1
	return n


func ck(label: String, passed: bool, detail: String) -> void:
	if passed:
		return
	_fails += 1
	print("  FAIL %s  %s" % [label, detail])
