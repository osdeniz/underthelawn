class_name ChapterProgress
extends RefCounted
## Which chapters are done and how much evidence each gave up, persisted through
## GameState's ConfigFile (user://settings.cfg, section "progress").
##
## Chapters are identified by their `variant_id` from data/story.json — NOT by an
## index and NOT by a scene path. G9 builds every chapter from one game scene
## plus variant data, so the id is the only stable handle.

const SECTION := "progress"


## All chapter entries from story.json, in board order.
static func chapters() -> Array:
	return Story.list("chapters")


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
