class_name Objectives
extends RefCounted
## The mission compass (G14.2): what the town is asking of you, in one place.
##
## This system INVENTS NOTHING. Every objective in data/objectives.json is a
## goal the game already had — the eight chapters of Case 1, the harvest the
## farm and the tractor unlock, the first three restorations — written down with
## its conditions ticked off so the player can see what is missing instead of
## inferring it. If a goal is not already reachable in the game, it does not
## belong in that file.
##
## Rewards are paid ONCE, on the transition from unmet to met, and the fact that
## they were paid lives in the save. Everything else is derived on read: there
## is no objective state to keep in sync, which is what makes this safe to poll
## from anywhere.

const PATH := "res://data/objectives.json"
const SECTION := "objectives"

static var _data: Dictionary = {}
static var _warned := false


static func data() -> Dictionary:
	if not _data.is_empty():
		return _data
	if not FileAccess.file_exists(PATH):
		_warn("data/objectives.json yok - gorev ekrani bos kalacak")
		return _data
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if parsed is Dictionary:
		_data = parsed
	else:
		_warn("data/objectives.json cozumlenemedi")
	return _data


static func all() -> Array:
	var list: Variant = data().get("objectives", [])
	return list if list is Array else []


static func of(id: String) -> Dictionary:
	for any: Variant in all():
		var spec: Dictionary = any
		if str(spec.get("id", "")) == id:
			return spec
	return {}


# ---------------------------------------------------------------- state

## One objective's live state:
##   steps: [{text, done}] in display order, the ready step last when it applies
##   met:   every step done
##   paid:  the reward has already been handed over
##   ready: the conditions are met but the deed itself is not done yet — the
##          harvest's "now go and do it" moment, which is a different thing from
##          "finished" and has to look different on screen.
static func state(id: String) -> Dictionary:
	var spec := of(id)
	if spec.is_empty():
		return {"steps": [], "met": false, "paid": false, "ready": false}
	var steps: Array = []
	var conditions_met := true
	for any: Variant in spec.get("conditions", []):
		var cond: Dictionary = any
		var done := _passes(str(cond.get("check", "")))
		conditions_met = conditions_met and done
		steps.append({
			"text": tr_key(str(cond.get("text", ""))),
			"done": done,
			"progress": _progress(str(cond.get("check", ""))),
		})
	var ready := false
	var met := conditions_met
	var ready_step: Variant = spec.get("ready_step", {})
	if ready_step is Dictionary and not (ready_step as Dictionary).is_empty():
		var deed := _passes(str((ready_step as Dictionary).get("check", "")))
		# The final step only appears once it can actually be acted on: a "go
		# and harvest" line under three unmet conditions is noise.
		if conditions_met or deed:
			steps.append({
				"text": tr_key(str((ready_step as Dictionary).get("text", ""))),
				"done": deed,
				"progress": "",
			})
			ready = not deed
		# The deed alone finishes it. The conditions are the GATE to reach the
		# deed, and the harvest's gate resets the moment it is used (the chapter
		# counter restarts at every harvest, G13.6) — so requiring both would
		# mean this objective could never complete.
		met = deed
	return {
		"steps": steps,
		"met": met,
		"paid": is_paid(id),
		"ready": ready,
	}


static func is_paid(id: String) -> bool:
	return bool(GameState.get_setting(SECTION, id, false))


## Every objective that has just been completed, marking each paid and adding
## its reward. Returns the specs so the caller can say so on screen.
##
## Safe to call from anywhere and as often as you like: an objective can only
## cross from unpaid to paid once.
static func collect() -> Array:
	var earned: Array = []
	for any: Variant in all():
		var spec: Dictionary = any
		var id := str(spec.get("id", ""))
		if id == "" or is_paid(id):
			continue
		if not (state(id)["met"] as bool):
			continue
		GameState.set_setting(SECTION, id, true)
		var reward := int(spec.get("reward_scrap", 0))
		if reward > 0:
			GameState.add_scrap(reward)
		Analytics.track("objective_completed", {"id": id, "scrap": reward})
		earned.append(spec)
	return earned


## How many objectives are open — the number on the hub's badge.
static func active_count() -> int:
	var open := 0
	for any: Variant in all():
		var spec: Dictionary = any
		if not is_paid(str(spec.get("id", ""))):
			open += 1
	return open


static func reset() -> void:
	for any: Variant in all():
		GameState.set_setting(SECTION, str((any as Dictionary).get("id", "")), false)


# ---------------------------------------------------------------- checks

## Resolves a condition string. The forms are deliberately few:
##   chapter:<variant_id>  that chapter is finished
##   chapters:<n>          n chapters finished since the last harvest
##   restore:<project_id>  that building is rebuilt
##   garage:<mower>        that machine is owned
##   projects:<n>          n restoration projects finished
##   harvest:<n>           n harvests brought in
static func _passes(check: String) -> bool:
	var parts := check.split(":", true, 1)
	if parts.size() < 2:
		return false
	var kind := parts[0]
	var arg := parts[1]
	match kind:
		"chapter":
			return ChapterProgress.is_done(arg)
		"chapters":
			return _chapters_since() >= int(arg)
		"restore":
			return RestoreBoard.is_built(arg)
		"garage":
			return Garage.is_unlocked(_mower_index(arg))
		"projects":
			return _projects_built() >= int(arg)
		"harvest":
			return HarvestLog.count() >= int(arg)
	return false


## "1/3" style text for the counted conditions, and "" for the yes/no ones.
static func _progress(check: String) -> String:
	var parts := check.split(":", true, 1)
	if parts.size() < 2:
		return ""
	match parts[0]:
		"chapters":
			return "%d/%s" % [mini(_chapters_since(), int(parts[1])), parts[1]]
		"projects":
			return "%d/%s" % [mini(_projects_built(), int(parts[1])), parts[1]]
		"harvest":
			return "%d/%s" % [mini(HarvestLog.count(), int(parts[1])), parts[1]]
	return ""


## Chapters finished since the last harvest — the same clock the invitation
## itself runs on (G13.6), so the objective and the map pin can never disagree.
static func _chapters_since() -> int:
	var since := int(GameState.get_setting(HarvestLog.SECTION,
		HarvestLog.KEY_SINCE, 0))
	return maxi(ChapterProgress.done_count() - since, 0)


static func _projects_built() -> int:
	var built := 0
	for any: Variant in RestoreBoard.projects():
		if RestoreBoard.is_built(str((any as Dictionary).get("id", ""))):
			built += 1
	return built


static func _mower_index(name: String) -> int:
	match name:
		"tractor": return GameConfig.MOWER_TRACTOR
		"robot": return GameConfig.MOWER_ROBOT
		"blade": return GameConfig.MOWER_BLADE
	return GameConfig.MOWER_PUSH


static func tr_key(key: String) -> String:
	return TranslationServer.translate(key) if key != "" else ""


static func _warn(message: String) -> void:
	if _warned:
		return
	_warned = true
	push_warning("[Objectives] " + message)
	print("[Objectives] " + message)
