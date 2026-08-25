class_name EchoLog
extends RefCounted
## Which world-history echoes the player has found, persisted in settings.cfg.
## Separate from ChapterProgress on purpose: echoes are collectibles, not case
## progress, and nothing in the case may ever depend on them.

const SECTION := "echoes"


static func is_found(chapter_id: String) -> bool:
	return bool(GameState.get_setting(SECTION, chapter_id, false))


static func mark_found(chapter_id: String) -> void:
	GameState.set_setting(SECTION, chapter_id, true)


static func found_count() -> int:
	var total := 0
	for chapter: Dictionary in ChapterProgress.chapters():
		if is_found(str(chapter.get("variant_id", ""))):
			total += 1
	return total


static func total() -> int:
	var count := 0
	for chapter: Dictionary in ChapterProgress.chapters():
		if not LevelVariant.of(str(chapter.get("variant_id", ""))).echo_def.is_empty():
			count += 1
	return count


static func reset() -> void:
	for chapter: Dictionary in ChapterProgress.chapters():
		GameState.set_setting(SECTION, str(chapter.get("variant_id", "")), false)
