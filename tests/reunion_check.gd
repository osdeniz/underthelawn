extends Node
## G14.10: the closing card must not open a door and shut it in one breath.

var _fails := 0


func _ready() -> void:
	ChapterProgress.reset()
	RestoreBoard.reset()

	# --- locked: Case 1 is closed but the town is not rebuilt yet.
	var chapters: Array = Story.list("chapters")
	for chapter_any: Variant in chapters:
		ChapterProgress.record(
			str((chapter_any as Dictionary).get("variant_id", "")), 2, 2)
	ck("vaka 2 henuz kapali", not ChapterProgress.case_two_open(), "")
	var locked := _read_case_page()
	ck("kilitliyken sart yaziyor",
		locked["line"] == tr("CASE_02_WAITING").format(
			{"done": RestoreBoard.town_ready_progress().x,
			"total": RestoreBoard.town_ready_progress().y}),
		locked["line"])

	# --- unlocked: rebuild enough of the town.
	for project_any: Variant in RestoreBoard.projects():
		GameState.set_setting("restore",
			str((project_any as Dictionary).get("id", "")), true)
	ck("vaka 2 acildi", ChapterProgress.case_two_open(), "")
	var open_page := _read_case_page()
	ck("acikken ACILDI diyor",
		open_page["title"].contains(tr("CASE_02_UNLOCKED")), open_page["title"])
	# The bug: the unlocked branch printed the LOCKED line under the word
	# UNLOCKED, so the card announced Case 2 and withdrew it in the same breath.
	ck("acikken 'devam edecek' DEMIYOR",
		open_page["line"] != tr("CASE_02_LOCKED"), open_page["line"])
	ck("acikken hedefi soyluyor",
		open_page["line"] == tr("CASE_02_OBJECTIVE"), open_page["line"])

	ChapterProgress.reset()
	RestoreBoard.reset()
	if _fails > 0:
		push_error("%d KAVUSMA TESTI BASARISIZ" % _fails)
		print("--- %d KAVUSMA TESTI BASARISIZ ---" % _fails)
	else:
		print("--- TUM KAVUSMA TESTLERI GECTI ---")
	get_tree().quit()


## The card's last page, as the player would read it.
func _read_case_page() -> Dictionary:
	var card := ReunionCard.new()
	add_child(card)
	card._page = 2
	card._apply()
	var out := {"title": card._title.text, "line": card._line.text}
	card.queue_free()
	return out


func ck(label: String, passed: bool, detail: String) -> void:
	if passed:
		return
	_fails += 1
	print("  FAIL %s  %s" % [label, detail])
