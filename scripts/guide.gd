class_name Guide
extends RefCounted
## The short walkthrough the game never had (G56).
##
## Everything this game asks the player to do exists on a screen behind a tile:
## the scrap goes into repairs on the Restore page, the better machines are in
## the Workshop, two finds are put together in the Journal. Nothing ever took
## the player there. They came back from a yard, the board opened on the
## evidence tab, and the four things they had just earned sat unspent behind
## doors they had no reason to open.
##
## So: at the moment a screen first becomes worth opening, the game opens it
## once, says one sentence, and never mentions it again. Not a tutorial layer
## with its own art and its own rules — the game's own screens, in the order
## the player earns them.
##
## Order matters and only one step runs per trip home. Two coach notes on one
## return is the thing this was meant to fix.

const SECTION := "guide"


## Every step, in the order they are offered. `page` is the hub page to open
## ("restore", "workshop" or "tiles"); `action` is what the note's button does
## beyond dismissing itself ("journal", or "" for a plain acknowledgement).
static func steps() -> Array:
	return [
		# First, because it is the only step that answers "what now?" rather
		# than "what next?": a case has opened and the player is holding a
		# closed one (G60).
		{"id": "case_open", "page": "map", "line": "GUIDE_CASE_OPEN",
			"button": "GUIDE_GO_MAP", "action": "map"},
		{"id": "restore", "page": "restore", "line": "GUIDE_RESTORE",
			"button": "GUIDE_OK", "action": ""},
		{"id": "workshop", "page": "workshop", "line": "GUIDE_WORKSHOP",
			"button": "GUIDE_OK", "action": ""},
		{"id": "link", "page": "tiles", "line": "GUIDE_LINK",
			"button": "GUIDE_OPEN_JOURNAL", "action": "journal"},
	]


static func is_shown(id: String) -> bool:
	return bool(GameState.get_setting(SECTION, id, false))


static func mark(id: String) -> void:
	GameState.set_setting(SECTION, id, true)


## The step to run on this trip home, or {} for none. Each is offered once and
## only when the screen behind it would actually pay: no point sending anybody
## to the Restore page with four scrap in hand.
static func next() -> Dictionary:
	if ChapterProgress.done_count() < 1:
		return {}
	for any: Variant in steps():
		var step: Dictionary = any
		var id := str(step.get("id", ""))
		if is_shown(id):
			continue
		if _ready_for(id):
			return step
	return {}


## One step by name, for a caller that knows exactly which moment it is in —
## the purchase that opens Case 02 announces itself on the spot rather than
## waiting for the next trip home.
static func step(id: String) -> Dictionary:
	for any: Variant in steps():
		var one: Dictionary = any
		if str(one.get("id", "")) == id:
			return one
	return {}


static func _ready_for(id: String) -> bool:
	match id:
		# The hub is showing a case whose first yard has not been mown, and the
		# player has never been pointed at it.
		"case_open": return ChapterProgress.active_case_index() >= 2 \
			and not ChapterProgress.is_done(ChapterProgress.current_variant_id())
		"restore": return can_afford_project()
		"workshop": return affordable_mower() >= 0
		"link": return DeductionLog.made_count() == 0 and pair_in_hand()
	return false


## Something on the Restore page is buildable right now.
static func can_afford_project() -> bool:
	var scrap := GameState.scrap_total()
	for any: Variant in RestoreBoard.projects():
		var project: Dictionary = any
		var pid := str(project.get("id", ""))
		if RestoreBoard.is_built(pid) or RestoreBoard.is_locked(pid):
			continue
		if scrap >= RestoreBoard.price(pid):
			return true
	return false


## The first locked machine the player could walk out with, or -1.
static func affordable_mower() -> int:
	var scrap := GameState.scrap_total()
	for index in GameConfig.MOWER_TYPES.size():
		if Garage.is_unlocked(index):
			continue
		var cost := Garage.unlock_cost(index)
		if cost > 0 and scrap >= cost:
			return index
	return -1


## Two finds that are known to say something together are both in hand — the
## G48 mechanic is live for this player and they have never used it.
static func pair_in_hand() -> bool:
	for any: Variant in DeductionLog.links():
		var link: Dictionary = any
		if holds(str(link.get("a", ""))) and holds(str(link.get("b", ""))):
			return true
	return false


## Is this piece of evidence in the Journal? Discoveries are counted, not
## listed, so a piece is held when its slot falls under its chapter's count —
## the same arithmetic the Journal itself lists by.
static func holds(side: String) -> bool:
	var vid := DeductionLog.chapter_of(side)
	var wanted := DeductionLog.evidence_of(side)
	var variant := LevelVariant.of(vid)
	var have := ChapterProgress.evidence_found(vid)
	for slot in mini(have, variant.evidence_count()):
		if str(variant.evidence_info(slot).get("id", "")) == wanted:
			return true
	return false


static func reset() -> void:
	for any: Variant in steps():
		GameState.set_setting(SECTION, str((any as Dictionary).get("id", "")), false)
