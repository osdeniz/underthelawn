class_name TownStats
extends RefCounted
## The two numbers on the hub's top bar (G14.12).
##
## They used to be the constants 42 and 11 — nothing produced them and nothing
## spent them, so they were state the player could watch never move. Population
## is DERIVED from what is actually standing in the town; food is a real
## resource that yards give and searching costs.

const SECTION := "economy"
const FOOD_KEY := "food"


# ---------------------------------------------------------------- people

## Named townsfolk who are actually here, plus one returning resident for every
## rebuilt project. Both halves are checkable against the diorama, which is the
## point: a number nobody can verify is decoration.
static func people() -> int:
	var total := GameConfig.TOWN_BASE_PEOPLE
	if ChapterProgress.case_one_finished():
		total += 1   # Ellie, home
	for any: Variant in RestoreBoard.projects():
		if RestoreBoard.is_built(str((any as Dictionary).get("id", ""))):
			total += 1
	return total


# ---------------------------------------------------------------- food

static func food() -> int:
	if not GameState.has_setting(SECTION, FOOD_KEY):
		GameState.set_setting(SECTION, FOOD_KEY, GameConfig.FOOD_START)
		return GameConfig.FOOD_START
	return int(GameState.get_setting(SECTION, FOOD_KEY, GameConfig.FOOD_START))


static func add_food(amount: int) -> int:
	var total := maxi(food() + amount, 0)
	GameState.set_setting(SECTION, FOOD_KEY, total)
	return total


## The town eats while you are out. Called once when a chapter is finished —
## never on a timer, so putting the game down costs nothing.
static func eat() -> int:
	return add_food(-GameConfig.FOOD_PER_CHAPTER)


static func is_low() -> bool:
	return food() <= GameConfig.FOOD_LOW


static func is_critical() -> bool:
	return food() <= GameConfig.FOOD_CRITICAL


## Which warning line to show, or "" for none.
static func warning_key() -> String:
	if is_critical():
		return "FOOD_CRITICAL_LINE"
	if is_low():
		return "FOOD_LOW_LINE"
	return ""


static func reset() -> void:
	GameState.set_setting(SECTION, FOOD_KEY, GameConfig.FOOD_START)
