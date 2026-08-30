extends Node
## UI/UX redesign, Phase 3: the Journal, and the hub's new hierarchy.
##
## "Yankılar" was a hub tile whose name said nothing about its contents and
## which held one flat list. The Journal names its three kinds of thing, and
## the hub leads with ONE action instead of five equal cards.

var _fails := 0


func settle(frames: int) -> void:
	for _i in frames:
		await get_tree().process_frame


func _ready() -> void:
	await _check_journal()
	await _check_hub_hierarchy()
	if _fails > 0:
		push_error("%d GUNLUK TESTI BASARISIZ" % _fails)
		print("--- %d GUNLUK TESTI BASARISIZ ---" % _fails)
	else:
		print("--- TUM GUNLUK TESTLERI GECTI ---")
	get_tree().quit()


func _check_journal() -> void:
	var journal := JournalScreen.new()
	add_child(journal)
	await settle(10)

	# Three named sections, and each one switches.
	var tabs: Control = journal.get("_tabs")
	ck("uc bolum var", tabs.get_child_count() == 3,
		str(tabs.get_child_count()))
	for section in [JournalScreen.Section.NOTES,
			JournalScreen.Section.DISCOVERIES, JournalScreen.Section.ECHOES]:
		journal.set("_section", section)
		journal.call("_refresh")
		await settle(3)
		ck("bolum %d icerik veya bos-not uretiyor" % int(section),
			(journal.get("_list") as Control).get_child_count() > 0,
			str(section))
		# Every section states its own count; a journal that does not say how
		# much is left is a list, not a journal.
		ck("bolum %d sayac yaziyor" % int(section),
			str((journal.get("_counter") as Label).text) != "", str(section))
	journal.queue_free()
	await settle(3)


## The hub's whole point after the redesign: one primary action, and the rest
## as navigation. A regression here would be five equal cards coming back.
func _check_hub_hierarchy() -> void:
	var hub := HubScreen.new()
	add_child(hub)
	await settle(25)
	hub.refresh()
	await settle(10)

	var lead := hub.find_children("LeadCard", "", true, false)
	ck("tek bir birincil kart var", lead.size() == 1, "%d" % lead.size())
	var go := hub.find_children("LeadGo", "", true, false)
	ck("birincil kartin eylemi var", go.size() == 1, "%d" % go.size())
	if go.size() == 1:
		ck("birincil eylem metinli", str((go[0] as Button).text) != "", "")

	# The navigation rows must be SHORTER than the lead card, or the hierarchy
	# is a claim rather than a fact.
	var rows_taller := 0
	var lead_h := (lead[0] as Control).size.y if lead.size() == 1 else 0.0
	for child in hub.find_children("*", "Button", true, false):
		var button := child as Button
		if button == null or button.get_parent() == null:
			continue
		if str(button.name).begins_with("Lead"):
			continue
		if button.size.y > lead_h and lead_h > 0.0:
			rows_taller += 1
	ck("hicbir gezinme satiri birincil karttan uzun degil",
		rows_taller == 0, "%d satir" % rows_taller)
	hub.queue_free()
	await settle(3)


func ck(what: String, passed: bool, detail: String) -> void:
	if passed:
		return
	_fails += 1
	print("  FAIL %s  %s" % [what, detail])
