extends TestBase
## G68: the first visit home names the hub's own furniture.
##
## Everything the hub can do already existed — the objectives door, the restore
## board, the workshop, the journal, and three live numbers including the town's
## population. Nothing ever said so, and the surest proof of that is that the
## population counter was reported missing while it was on screen. These claims
## are about the tour existing, pointing at real controls, advancing, and
## running once.

func run() -> void:
	suite = "TUR"
	min_checks = 18
	GameState.set_setting(Guide.SECTION, Guide.TOUR_KEY, false)

	var steps := Guide.tour()
	ck("tur uc adim", steps.size() == 3, str(steps.size()))
	ck("basta gosterilmemis", not Guide.tour_done())

	# The hub's fourth tile is the Journal now, under its own name and with the
	# icon the echoes page was already drawing (G68).
	ck("gunluk kutucugunun ikonu var", UiIcons.for_tile("journal") != null)
	ck("yankilar kutucugu kalmadi", UiIcons.for_tile("echoes") == null)

	var hub := HubScreen.new()
	add_child(hub)
	await frames(8)
	ck("hubda gunluk kutucugu var",
		hub.find_child("Tile_journal", true, false) != null)
	ck("hubda yankilar kutucugu yok",
		hub.find_child("Tile_echoes", true, false) == null)

	# Every step must name a control that actually exists, or the tour rings
	# empty air — the one failure mode a sentence cannot show.
	for any: Variant in steps:
		var step: Dictionary = any
		var point := str(step.get("point", ""))
		ck("adim bir kontrole isaret ediyor: %s" % point,
			hub.find_child(point, true, false) != null, point)
		ck("adimin cumlesi cevrildi: %s" % point,
			tr(str(step.get("line", ""))) != str(step.get("line", "")))

	# Running it: a note, a ring, and the ring around the RIGHT control.
	hub.run_tour_if_new()
	await frames(6)
	var note := hub.find_child("GuideNote", true, false) as Control
	ck("ilk adim notu acildi", note != null)
	var ring := hub.find_child("TourRing", true, false) as Control
	ck("halka cizildi", ring != null)
	var lead := hub.find_child("LeadCard", true, false) as Control
	if ring != null and lead != null:
		var box := lead.get_global_rect()
		ck("halka dogru kontrolun etrafinda",
			ring.get_global_rect().encloses(box),
			"%s vs %s" % [ring.get_global_rect(), box])

	# Advancing: the button carries the tour on, and the last one ends it.
	for i in steps.size():
		var go := hub.find_child("GuideGo", true, false) as Button
		ck("adim %d dugmesi var" % i, go != null)
		if go == null:
			break
		go.pressed.emit()
		await frames(6)
	ck("tur bitince isaretlendi", Guide.tour_done())
	ck("tur bitince not kalmadi", hub.find_child("GuideNote", true, false) == null)
	ck("tur bitince halka kalmadi", hub.find_child("TourRing", true, false) == null)

	# And it does not come back.
	hub.run_tour_if_new()
	await frames(4)
	ck("ikinci kez acilmiyor", hub.find_child("GuideNote", true, false) == null)
	hub.queue_free()
	await frames(2)
