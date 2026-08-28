class_name HarvestLog
extends RefCounted
## How many harvests the player has brought in (G13.6).
##
## Stored rather than counted from anything else: harvests are repeatable and
## carry no chapter progress, so nothing else in the save knows they happened.
## The number drives the hay bales outside the barn in the diorama, and the
## rotating crumb line on the completion panel.

const SECTION := "harvest"
const KEY := "runs"
## How many chapters were finished when the last harvest came in. The next
## invitation is measured from there, not from the harvest count, so a harvest
## played out of order does not push the following one out of reach.
const KEY_SINCE := "since_chapter"


static func count() -> int:
	return int(GameState.get_setting(SECTION, KEY, 0))


static func record() -> void:
	GameState.set_setting(SECTION, KEY, count() + 1)
	GameState.set_setting(SECTION, KEY_SINCE, ChapterProgress.done_count())


## Bales stacked outside the barn: one per harvest, up to the cap.
static func bales() -> int:
	return mini(count(), GameConfig.HARVEST_BALES_MAX)


## The crumb Gus leaves after this one. Rotates, so a fourth harvest does not
## repeat the first one's line.
static func crumb_key() -> String:
	var runs := maxi(1, count())
	return "HARVEST_CRUMB_%d" % (((runs - 1) % 4) + 1)


## Whether the town is asking for a harvest: the farm rebuilt, the tractor
## owned, and enough searches finished since the last one. It then waits
## indefinitely — an invitation, never a timer.
## Whether the field can be worked AT ALL: the farm is standing and there is a
## tractor to work it with. This is the DOOR, and it never closes again once it
## opens — the harvest is the game's repeatable job, and a job you can only take
## when the game offers it is not a job (G13).
static func is_available() -> bool:
	return RestoreBoard.is_built("farm") \
		and Garage.is_unlocked(GameConfig.MOWER_TRACTOR)


## Whether the field is ASKING right now. This is the INVITATION — Gus's radio
## call and the gold badge — and it still runs on the old cadence, so being
## invited stays an event even though the door is always open.
static func is_offered() -> bool:
	if not is_available():
		return false
	var since := int(GameState.get_setting(SECTION, KEY_SINCE, 0))
	return ChapterProgress.done_count() - since >= GameConfig.HARVEST_EVERY
