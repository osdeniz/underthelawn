class_name ThoroughStreak
extends RefCounted
## Yards in a row searched with nothing missed (G30). Counted only on search
## chapters — a field has nothing to miss — and said on the panel from two up.

const SECTION := "story"
const KEY := "thorough_streak"


static func current() -> int:
	return int(GameState.get_setting(SECTION, KEY, 0))


## Returns the streak after this yard.
static func bump(thorough: bool) -> int:
	var next := current() + 1 if thorough else 0
	GameState.set_setting(SECTION, KEY, next)
	return next


static func reset() -> void:
	GameState.set_setting(SECTION, KEY, 0)
