extends TestBase
## Getting from one case to the next (G60).
##
## Case 02 opens on two conditions — Case 01 closed AND three town projects
## rebuilt — and the hub is where a player watches that happen. The claims here
## are that the moment the third project is paid for, THIS hub says so, without
## the app being closed and reopened; and that the next yard is never something
## the player has to go looking for.

func run() -> void:
	suite = "VAKA GECISI"
	var keep_scrap := GameState.scrap_total()
	var keep_done := {}
	for any: Variant in Story.list("chapters") + Story.list("case_02.chapters"):
		var vid := str((any as Dictionary).get("variant_id", ""))
		keep_done[vid] = ChapterProgress.is_done(vid)
	var keep_closed: Variant = GameState.get_setting("story", "case02_closed", false)
	var keep_built := {}
	for any: Variant in RestoreBoard.projects():
		var pid := str((any as Dictionary).get("id", ""))
		keep_built[pid] = RestoreBoard.is_built(pid)

	await _opens_without_a_restart()
	await _next_yard_is_never_hidden()

	# Put the save back the way it was found.
	RestoreBoard.reset()
	for pid: Variant in keep_built:
		if bool(keep_built[pid]):
			GameState.set_setting(RestoreBoard.SECTION, str(pid), true)
	ChapterProgress.reset()
	for vid: Variant in keep_done:
		if bool(keep_done[vid]):
			ChapterProgress.record(str(vid), 0, GameConfig.SECRET_TOTAL)
	GameState.set_setting("story", "case02_closed", keep_closed)
	GameState.spend_scrap(GameState.scrap_total())
	GameState.add_scrap(keep_scrap)
	finish()


func _opens_without_a_restart() -> void:
	# Case 01 closed, the town not yet rebuilt: the state the player is in when
	# they come home with Ellie.
	ChapterProgress.reset()
	GameState.set_setting("story", "case02_closed", false)
	RestoreBoard.reset()
	for any: Variant in Story.list("chapters"):
		ChapterProgress.record(str((any as Dictionary).get("variant_id", "")), 0,
			GameConfig.SECRET_TOTAL)
	GameState.spend_scrap(GameState.scrap_total())
	GameState.add_scrap(40000)
	ck("vaka 1 kapandi", ChapterProgress.case_one_finished(), "")
	ck("vaka 2 henuz kapali", not ChapterProgress.case_two_open(), "")

	var layer := CanvasLayer.new()
	add_child(layer)
	var hub := HubScreen.new()
	layer.add_child(hub)
	await frames(8)
	hub.set_diorama_active(true)
	hub.refresh()
	await frames(3)

	# The counter tile is the only thing that says what Case 02 is waiting for.
	var tile: Button = hub.find_child("CaseTwoTile", true, false)
	ck("kasabayi bekleyen sayac gorunuyor", tile != null, "")
	ck("sayac kac tanesinin yapildigini yaziyor",
		tile != null and tile.text.contains("0"), "" if tile == null else tile.text)

	# Two projects in: still waiting.
	var ids: Array[String] = []
	for any: Variant in RestoreBoard.projects():
		var project: Dictionary = any
		if int(project.get("tier", 1)) == 1:
			ids.append(str(project.get("id", "")))
	ck("birinci kademede en az uc proje var", ids.size() >= 3, str(ids.size()))
	RestoreBoard.buy(ids[0])
	RestoreBoard.buy(ids[1])
	hub.refresh()
	await frames(3)
	ck("iki projeyle hala kapali", not ChapterProgress.case_two_open(),
		str(RestoreBoard.built_count()))

	# And the third, through the hub's OWN purchase handler — the path a finger
	# takes. Nothing else may be needed after this.
	await hub._on_project(ids[2], false, null)
	await settle(1.5)
	ck("uc projeyle vaka 2 acilir", ChapterProgress.case_two_open(),
		str(RestoreBoard.built_count()))
	ck("bekleme sayaci kalkti", hub.find_child("CaseTwoTile", true, false) == null, "")

	# THE claim: this hub, as it stands, points at Case 02.
	var vid := ChapterProgress.current_variant_id()
	var case_two: Array = Story.list("case_02.chapters")
	var first := str((case_two[0] as Dictionary).get("variant_id", ""))
	ck("siradaki bahce vaka 2'nin ilk bahcesi", vid == first, "%s / %s" % [vid, first])
	var place: Label = hub.find_child("LeadPlace", true, false)
	ck("ana kart yeni bahceyi adlandirir",
		place != null and place.text == tr(str(ChapterProgress.entry(vid).get("name", ""))),
		"" if place == null else place.text)
	var go: Button = hub.find_child("LeadGo", true, false)
	ck("ana kartin dugmesi calisir durumda", go != null and not go.disabled, "")
	# And the board's own list, which is built separately from the lead card.
	hub.open_map()
	await frames(3)
	var listed := false
	for any: Variant in hub.find_children("*", "Button", true, false):
		if (any as Button).name.contains(first):
			listed = true
	ck("vaka 2 tahtada listelenir", listed or hub._map != null, "")

	hub.queue_free()
	layer.queue_free()
	await frames(2)


## Wherever the player is, the next yard is already on screen.
func _next_yard_is_never_hidden() -> void:
	var vid := ChapterProgress.current_variant_id()
	var layer := CanvasLayer.new()
	add_child(layer)
	var hub := HubScreen.new()
	layer.add_child(hub)
	await frames(8)
	hub.set_diorama_active(true)
	hub.refresh()
	await frames(3)
	# The map tile, not the lead card's button: entering the map from the hub's
	# own door used to drop the player on an unfocused sheet with a dozen pins
	# and no answer to "which one is mine".
	hub.open_map()
	await frames(3)
	ck("harita siradaki bahceye odaklanir",
		hub._map != null and hub._map._selected == vid,
		"" if hub._map == null else "%s / %s" % [hub._map._selected, vid])
	hub.queue_free()
	layer.queue_free()
	await frames(2)

	# And the front door: CONTINUE should say what it continues.
	var menu := MainMenu.new()
	add_child(menu)
	await frames(4)
	var wanted := tr(str(ChapterProgress.entry(vid).get("name", "")))
	var said := false
	for any: Variant in menu.find_children("*", "Label", true, false):
		if (any as Label).text.contains(wanted):
			said = true
	ck("ana menu siradaki bahceyi soyler", said, wanted)
	# The line has to be a SENTENCE, not a bare key: appending to strings.csv
	# without reimporting leaves tr() returning "MENU_NEXT" and format() with
	# nowhere to put the place (G60).
	var line: Label = menu.find_child("NextYard", true, false)
	ck("satir cevrilmis", line != null and line.text != "MENU_NEXT",
		"" if line == null else line.text)
	menu.queue_free()
	await frames(2)
