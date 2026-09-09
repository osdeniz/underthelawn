class_name DogNose
extends RefCounted
## The dog gets better at its job (G46).
##
## It has pointed at buried things since G14.25, always from the same
## distance. A companion that visibly improves is worth more than any badge:
## the player did not level up, the dog did, and they can see it happening
## from the fence line.
##
## Every find widens its range one step at a time, and the step is announced
## once, in the dog's own name, so the improvement is legible rather than a
## number nobody sees.

const SECTION := "story"
const KEY := "finds"
## Finds at which the nose gets better, and how much each step adds.
const STEPS: Array[int] = [3, 8, 15]
const STEP_RANGE := 0.8


static func finds() -> int:
	return int(GameState.get_setting(SECTION, KEY, 0))


## Counts a find. Returns true when this one crossed a step, which is the
## moment worth saying out loud.
static func record() -> bool:
	var before := finds()
	GameState.set_setting(SECTION, KEY, before + 1)
	return STEPS.has(before + 1)


## How far it can smell now.
static func scent_range() -> float:
	var earned := 0
	for step in STEPS:
		if finds() >= step:
			earned += 1
	return GameConfig.DOG_SCENT_RANGE + float(earned) * STEP_RANGE


static func reset() -> void:
	GameState.set_setting(SECTION, KEY, 0)
