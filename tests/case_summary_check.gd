extends Node
## UI/UX redesign, Phase 2: the Case screen (hub_screen.gd's summary page).
##
## Three real bugs were caught building this and are fenced here so they
## cannot come back silently:
##   1. The page was never added to _pages(), so _show_page() never made it
##      visible — it built correctly and simply never appeared.
##   2. "Is the case fully closed" compared against
##      current_variant_id()'s REPLAY fallback (the first chapter, once
##      everything is done) instead of counting the case's own list, so a
##      finished case never reported itself as finished.
##   3. Evidence found/total summed per chapter without a floor against a
##      total re-authored smaller than a save's recorded found count, so the
##      discoveries line could print more found than existed.

var _fails := 0


func settle(frames: int) -> void:
	for _i in frames:
		await get_tree().process_frame


func _ready() -> void:
	await _check_summary()
	if _fails > 0:
		push_error("%d VAKA OZETI TESTI BASARISIZ" % _fails)
		print("--- %d VAKA OZETI TESTI BASARISIZ ---" % _fails)
	else:
		print("--- TUM VAKA OZETI TESTLERI GECTI ---")
	get_tree().quit()


func _check_summary() -> void:
	# PRECONDITION, stated rather than assumed. The screen shows the ACTIVE
	# case, and on a save where Case 01 is closed and the town is rebuilt that
	# is Case 02 — so a test that drives Case 01's chapters would be watching a
	# screen showing a different list entirely. Case 02 is held shut here by
	# emptying the restore board, and everything touched is put back at the end.
	var restore_was: Dictionary = {}
	for project: Dictionary in RestoreBoard.projects():
		var pid := str(project.get("id", ""))
		restore_was[pid] = RestoreBoard.is_built(pid)
		GameState.set_setting("restore", pid, false)
	ck("on kosul: aktif vaka birinci",
		not ChapterProgress.active_case_is_two(), "")

	var was: Dictionary = {}
	for chapter: Dictionary in Story.list("chapters"):
		var vid := str(chapter.get("variant_id", ""))
		was[vid] = [ChapterProgress.is_done(vid), ChapterProgress.evidence_found(vid),
			ChapterProgress.evidence_total(vid)]
		GameState.set_setting("progress", vid + "_done", false)

	var hub := HubScreen.new()
	add_child(hub)
	await settle(20)

	# 1. The page must actually be reachable.
	hub._on_tile("case_board", false)
	await settle(15)
	var page: Control = hub.get("_case_summary_page")
	ck("ozet sayfasi kuruldu", page != null, "")
	ck("ozet sayfasi _pages() listesinde", hub.call("_pages").has(page), "")
	ck("ozet sayfasi acildiginda gorunur", page != null and page.visible, "")

	# 2. Nothing done: not reported as closed.
	ck("hicbir sey bitmemisken kapali degil",
		not str((hub.get("_case_lead_label") as Label).text).contains(
			tr("CASE_LEAD_CLOSED")), "")

	# 3. Every chapter done: the case reports itself closed and the count
	# never exceeds its own total, even with a deliberately inconsistent save
	# (found recorded against a larger total than the level currently has).
	for chapter: Dictionary in Story.list("chapters"):
		var vid := str(chapter.get("variant_id", ""))
		GameState.set_setting("progress", vid + "_done", true)
		GameState.set_setting("progress", vid + "_evidence", 99)
		GameState.set_setting("progress", vid + "_total", 2)
	hub.call("_refresh_case_summary")
	await settle(5)
	var lead := (hub.get("_case_lead_label") as Label).text
	ck("her bolum bitince vaka kapali bildiriliyor",
		lead.contains(tr("CASE_LEAD_CLOSED")), lead)
	var discoveries := (hub.get("_case_discoveries_label") as Label).text
	var total_chapters := Story.list("chapters").size()
	var expected := tr("CASE_DISCOVERIES_COUNT").format(
		{"found": total_chapters * 2, "total": total_chapters * 2})
	ck("bulunan sayisi toplami asmiyor", discoveries == expected,
		"%s (beklenen %s)" % [discoveries, expected])
	var next_btn: Button = hub.get("_case_next_button")
	ck("hepsi arandi dugmesi kapali", next_btn.disabled, "")

	# 4. CONTINUE routes into the map, focused, not straight into the full file.
	for chapter: Dictionary in Story.list("chapters"):
		var vid := str(chapter.get("variant_id", ""))
		GameState.set_setting("progress", vid + "_done", false)
	hub.call("_refresh_case_summary")
	await settle(5)
	next_btn = hub.get("_case_next_button")
	next_btn.emit_signal("pressed")
	await settle(10)
	ck("devam et haritayi acar",
		not (hub.get("_board_scroll") as Control).visible, "")

	# restore whatever this machine's save actually held
	for chapter: Dictionary in Story.list("chapters"):
		var vid := str(chapter.get("variant_id", ""))
		var prev: Array = was[vid]
		GameState.set_setting("progress", vid + "_done", prev[0])
		GameState.set_setting("progress", vid + "_evidence", prev[1])
		GameState.set_setting("progress", vid + "_total", prev[2])
	for pid_any: Variant in restore_was:
		GameState.set_setting("restore", str(pid_any), restore_was[pid_any])
	hub.queue_free()
	await settle(5)


func ck(what: String, passed: bool, detail: String) -> void:
	if passed:
		return
	_fails += 1
	print("  FAIL %s  %s" % [what, detail])
