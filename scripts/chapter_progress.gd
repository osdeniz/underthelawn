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
	return bool(GameState.get_setting("story", "case01_closed", false)) \
		and RestoreBoard.town_ready()


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
	if case_two_open():
		return list + Story.list("case_02.chapters")
	return list


## The chapters of the case `variant_id` belongs to. A chapter is the last one
## of ITS case, not of the game, which is what decides whether finishing it ends
## a case or simply moves to the next chapter.
static func case_of(variant_id: String) -> Array:
	for chapter: Dictionary in Story.list("case_02.chapters"):
		if str(chapter.get("variant_id", "")) == variant_id:
			return Story.list("case_02.chapters")
	return Story.list("chapters")


## The case the hub should be showing: Case 02 once it is open and Case 01 has
## nothing left in it, otherwise Case 01.
static func active_case_chapters() -> Array:
	if not case_two_open():
		return Story.list("chapters")
	for chapter: Dictionary in Story.list("chapters"):
		if not is_done(str(chapter.get("variant_id", ""))):
			return Story.list("chapters")
	return Story.list("case_02.chapters")


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


static func reset() -> void:
	for chapter: Dictionary in chapters():
		var id := str(chapter.get("variant_id", ""))
		GameState.set_setting(SECTION, id + "_done", false)
		GameState.set_setting(SECTION, id + "_evidence", 0)
