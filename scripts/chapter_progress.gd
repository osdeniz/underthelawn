class_name ChapterProgress
extends RefCounted
## Which chapters are done and how much evidence each gave up, persisted through
## GameState's ConfigFile (user://settings.cfg, section "progress").
##
## Chapters are identified by their `variant_id` from data/story.json — NOT by an
## index and NOT by a scene path. G9 builds every chapter from one game scene
## plus variant data, so the id is the only stable handle.

const SECTION := "progress"


## Case 02 opens on Ellie's closing line, not on a counter: the stranger said he
## would come back when the town was ready, so the case waits for Case 01 to be
## closed AND for the town to be rebuilt (G13).
static func case_two_open() -> bool:
	return case_one_finished() and RestoreBoard.town_ready()


## Case 01 is over when its chapters are ACTUALLY done, not when a flag says so.
##
## The flag alone was brittle: it is written by the ending card, and any state
## that sets it without the chapters behind it — a reset, a dev run, a test
## writing to the same save file — left the game announcing Case 02 over a board
## reading 0/8. Asking the chapters is self-correcting; the flag stays as the
## record of having SEEN the ending (G13).
static func case_one_finished() -> bool:
	var chapters := Story.list("chapters")
	if chapters.is_empty():
		return false
	for chapter: Dictionary in chapters:
		if not is_done(str(chapter.get("variant_id", ""))):
			return false
	return true


## All chapter entries the game currently knows, in board order — Case 01, plus
## Case 02 once it has opened.
##
## Deliberately ONE list rather than two. Everything that asks "how far along is
## this player" — the harvest cadence, the objectives, the town's dialogue
## phases, the diorama's reclaim — means it across the whole game, and every one
## of those readers keeps working unchanged as the list grows. The only question
## that is per-case is the hub's own "CASE 01 · 3/8" line, and that asks
## active_case_chapters() instead.
static func chapters() -> Array:
	var list: Array = Story.list("chapters")
	# A closed Case 02 stays listed whatever town_ready() says today: you cannot
	# have closed it without it having been open, and Case 03 building on top
	# of a list that had dropped Case 02 counted 16 chapters where there are 26.
	if case_two_open() or case_three_open():
		list = list + Story.list("case_02.chapters")
	if case_three_open():
		list = list + Story.list("case_03.chapters")
	return list


## Case 03 opens on Case 02's ending card — the headlights on the road are the
## visitors, and the case is what the town does in the twelve days before they
## arrive (G17).
static func case_three_open() -> bool:
	return bool(GameState.get_setting("story", "case02_closed", false))


## 1, 2 or 3: which case the hub is showing.
static func active_case_index() -> int:
	var active := active_case_chapters()
	if active == Story.list("case_03.chapters"):
		return 3
	if active == Story.list("case_02.chapters"):
		return 2
	return 1


## The story.json path of the active case: "case", "case_02" or "case_03".
static func active_case_path() -> String:
	match active_case_index():
		3: return "case_03"
		2: return "case_02"
	return "case"


## The chapters of the case `variant_id` belongs to. A chapter is the last one
## of ITS case, not of the game, which is what decides whether finishing it ends
## a case or simply moves to the next chapter.
static func case_of(variant_id: String) -> Array:
	for path: String in ["case_03.chapters", "case_02.chapters"]:
		for chapter: Dictionary in Story.list(path):
			if str(chapter.get("variant_id", "")) == variant_id:
				return Story.list(path)
	return Story.list("chapters")


## The case the hub should be showing: Case 02 once it is open and Case 01 has
## nothing left in it, otherwise Case 01.
static func active_case_chapters() -> Array:
	if not case_two_open():
		return Story.list("chapters")
	for chapter: Dictionary in Story.list("chapters"):
		if not is_done(str(chapter.get("variant_id", ""))):
			return Story.list("chapters")
	if not case_three_open():
		return Story.list("case_02.chapters")
	for chapter: Dictionary in Story.list("case_02.chapters"):
		if not is_done(str(chapter.get("variant_id", ""))):
			return Story.list("case_02.chapters")
	return Story.list("case_03.chapters")


## Whether the active case is the second one, for the title the hub prints.
static func active_case_is_two() -> bool:
	return active_case_chapters() == Story.list("case_02.chapters")


## Finished chapters within one case list, for that case's own progress line.
static func done_in(list: Array) -> int:
	var total := 0
	for chapter: Dictionary in list:
		if is_done(str(chapter.get("variant_id", ""))):
			total += 1
	return total


static func count() -> int:
	return chapters().size()


static func entry(variant_id: String) -> Dictionary:
	for chapter: Dictionary in chapters():
		if str(chapter.get("variant_id", "")) == variant_id:
			return chapter
	return {}


static func is_playable(variant_id: String) -> bool:
	return bool(entry(variant_id).get("playable", false))


static func is_done(variant_id: String) -> bool:
	return bool(GameState.get_setting(SECTION, variant_id + "_done", false))


static func evidence_found(variant_id: String) -> int:
	return int(GameState.get_setting(SECTION, variant_id + "_evidence", 0))


## Records a finished search. Evidence only ever goes UP: replaying a chapter and
## finding less must not erase what the case already knows.
static func record(variant_id: String, evidence: int, total: int) -> void:
	GameState.set_setting(SECTION, variant_id + "_done", true)
	var best := maxi(evidence_found(variant_id), evidence)
	GameState.set_setting(SECTION, variant_id + "_evidence", best)
	GameState.set_setting(SECTION, variant_id + "_total", total)


static func evidence_total(variant_id: String) -> int:
	return int(GameState.get_setting(SECTION, variant_id + "_total",
		GameConfig.SECRET_TOTAL))


static func done_count() -> int:
	var total := 0
	for chapter: Dictionary in chapters():
		if is_done(str(chapter.get("variant_id", ""))):
			total += 1
	return total


## The chapter the board should point at: the first playable one that is not
## finished, else the first playable one at all (so a replay is always offered).
static func current_variant_id() -> String:
	var first_playable := ""
	for chapter: Dictionary in chapters():
		var id := str(chapter.get("variant_id", ""))
		if not bool(chapter.get("playable", false)):
			continue
		if first_playable == "":
			first_playable = id
		if not is_done(id):
			return id
	return first_playable


## Clears EVERY chapter, in both cases, whether or not Case 02 is currently
## open.
##
## It used to iterate chapters(), which hides Case 02 until Case 01 closes. So
## resetting while Case 02 was shut left its records standing, and they came
## back as "done" the moment the case opened — three Case 02 objectives paying
## out to a player who had not played them. It surfaced as one test in the
## suite failing only when another test ran before it, which is exactly how a
## bug like this stays hidden: reset() looked like it worked because the caller
## usually happened to be looking at Case 01.
##
## Reset means no chapter is done. It should not depend on what is on screen.
static func reset() -> void:
	for chapter: Dictionary in Story.list("chapters") \
			+ Story.list("case_02.chapters"):
		var id := str(chapter.get("variant_id", ""))
		GameState.set_setting(SECTION, id + "_done", false)
		GameState.set_setting(SECTION, id + "_evidence", 0)
