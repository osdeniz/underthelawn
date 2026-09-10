class_name Drawings
extends RefCounted
## Ellie's drawings (G34, landed in G67): four sheets of paper, one after each
## of Case 02's first four chapters.
##
## The pictures are the reward for the case's slow half. Case 02 is ten
## chapters of radio masts and river crossings with the girl herself offstage,
## and the drawings are the only thing in it that speaks in her own hand — so
## they arrive the moment the chapter that earns one is finished, and they stay
## in the journal afterwards.
##
## Nothing here is stored that could be derived: what unlocks a drawing is
## `ChapterProgress.is_done` of its chapter, which the save already knows. The
## one new fact is whether the player has been SHOWN it once, which is not
## derivable from progress — a drawing must not play again every time the
## player replays that chapter.

const SECTION := "drawings"


static func total() -> int:
	return GameConfig.DRAWINGS.size()


static func entry(index: int) -> Dictionary:
	if index < 0 or index >= total():
		return {}
	return GameConfig.DRAWINGS[index]


static func id_of(index: int) -> String:
	return str(entry(index).get("id", ""))


static func chapter_of(index: int) -> String:
	return str(entry(index).get("chapter", ""))


## The drawing a chapter earns, or -1 for a chapter that earns none — which is
## most of them.
static func for_chapter(variant_id: String) -> int:
	for i in total():
		if chapter_of(i) == variant_id:
			return i
	return -1


static func is_unlocked(index: int) -> bool:
	var chapter := chapter_of(index)
	return chapter != "" and ChapterProgress.is_done(chapter)


static func found_count() -> int:
	var found := 0
	for i in total():
		if is_unlocked(i):
			found += 1
	return found


## Shown-once bookkeeping. Keyed by the drawing's own id rather than by index,
## so reordering the table cannot hand the player a picture twice.
static func is_seen(index: int) -> bool:
	var id := id_of(index)
	return id != "" and bool(GameState.get_setting(SECTION, id + "_seen", false))


static func mark_seen(index: int) -> void:
	var id := id_of(index)
	if id != "":
		GameState.set_setting(SECTION, id + "_seen", true)


## The drawing this chapter should play right now: unlocked, present on disk,
## and not yet shown. -1 for "carry on", which is the answer for every chapter
## outside Case 02's first four and for every replay of those.
static func pending_for(variant_id: String) -> int:
	var index := for_chapter(variant_id)
	if index < 0 or not is_unlocked(index) or is_seen(index):
		return -1
	if texture(index) == null:
		return -1
	return index


static func texture(index: int) -> Texture2D:
	var id := id_of(index)
	if id == "":
		return null
	return TextureLibrary.find("story/" + id)


## "DRAWING_01_TITLE" / "_LINE" — the name she would give it, and the line the
## Marshal wrote under it when he filed it.
static func title(index: int) -> String:
	var id := id_of(index)
	return "" if id == "" else TranslationServer.translate(id.to_upper() + "_TITLE")


static func line(index: int) -> String:
	var id := id_of(index)
	return "" if id == "" else TranslationServer.translate(id.to_upper() + "_LINE")
