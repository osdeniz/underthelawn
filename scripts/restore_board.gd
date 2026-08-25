class_name RestoreBoard
extends RefCounted
## Town restoration state (G12.6): which projects are built, persisted in
## settings.cfg. Kept separate from Garage because these two economies answer
## different questions — the workshop is what you NEED, the town is what the
## money is FOR once you have it.

const PATH := "res://data/projects.json"
const SECTION := "restore"

static var _data: Dictionary = {}


static func projects() -> Array:
	if _data.is_empty():
		if not FileAccess.file_exists(PATH):
			push_warning("[Restore] data/projects.json yok")
			return []
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		if parsed is Dictionary:
			_data = parsed
	return _data.get("projects", [])


static func of(project_id: String) -> Dictionary:
	for project: Dictionary in projects():
		if str(project.get("id", "")) == project_id:
			return project
	return {}


## Tier 2 needs enough tier-1 work done first; a project with `requires` also
## needs that specific one. Locked projects stay VISIBLE — a priced door the
## player cannot open yet is a goal; a hidden one is nothing.
static func is_locked(project_id: String) -> bool:
	var project := of(project_id)
	if project.is_empty():
		return true
	if int(project.get("tier", 1)) >= 2 \
			and tier1_built() < GameConfig.TIER2_REQUIRES_TIER1:
		return true
	var needs := str(project.get("requires", ""))
	return needs != "" and not is_built(needs)


## Why a project is locked, as a ready-to-show line ("" if it is not).
static func lock_reason(project_id: String) -> String:
	var project := of(project_id)
	var needs := str(project.get("requires", ""))
	if needs != "" and not is_built(needs):
		return TranslationServer.translate("RESTORE_NEEDS").format(
			{"name": TranslationServer.translate(str(of(needs).get("name", "")))})
	if int(project.get("tier", 1)) >= 2 \
			and tier1_built() < GameConfig.TIER2_REQUIRES_TIER1:
		return TranslationServer.translate("RESTORE_LOCKED")
	return ""


static func tier1_built() -> int:
	var total := 0
	for project: Dictionary in projects():
		if int(project.get("tier", 1)) == 1 and is_built(str(project.get("id", ""))):
			total += 1
	return total


## True the first time tier 2 becomes reachable, for the analytics event.
static func tier2_open() -> bool:
	return tier1_built() >= GameConfig.TIER2_REQUIRES_TIER1


## The station regroups the case screens under one hub card.
static func station_built() -> bool:
	return is_built("station")


## Percentage added to a chapter's payout by completed projects.
static func payout_bonus() -> float:
	var bonus := 0.0
	for project: Dictionary in projects():
		if str(project.get("bonus", "")) == "payout_percent" \
				and is_built(str(project.get("id", ""))):
			bonus += float(project.get("bonus_value", 0)) * 0.01
	return bonus


## Every project this NPC has finished, for the town card's badges.
static func projects_for(npc_id: String) -> Array:
	var out: Array = []
	for project: Dictionary in projects():
		if str(project.get("npc_id", "")) == npc_id \
				and is_built(str(project.get("id", ""))):
			out.append(project)
	return out


static func is_built(project_id: String) -> bool:
	return bool(GameState.get_setting(SECTION, project_id, false))


static func built_count() -> int:
	var total := 0
	for project: Dictionary in projects():
		if is_built(str(project.get("id", ""))):
			total += 1
	return total


## True if this NPC has a finished project — their town dialogue gains a
## permanent thank-you phase.
static func thanks_for(npc_id: String) -> Dictionary:
	for project: Dictionary in projects():
		if str(project.get("npc_id", "")) == npc_id \
				and is_built(str(project.get("id", ""))):
			return project
	return {}


## Extra salvage points this chapter, from projects that grant them.
static func scrap_bonus() -> int:
	var bonus := 0
	for project: Dictionary in projects():
		if str(project.get("bonus", "")) == "scrap_point" \
				and is_built(str(project.get("id", ""))):
			bonus += GameConfig.RESTORE_SCRAP_BONUS
	return bonus


static func buy(project_id: String) -> bool:
	var project := of(project_id)
	if project.is_empty() or is_built(project_id) or is_locked(project_id):
		return false
	var cost := int(project.get("cost", 0))
	if GameState.scrap_total() < cost:
		return false
	GameState.set_setting("economy", "scrap", GameState.scrap_total() - cost)
	GameState.set_setting(SECTION, project_id, true)
	Analytics.track("restore_bought",
		{"id": project_id, "cost": cost, "tier": int(project.get("tier", 1))})
	if project_id == "station":
		Analytics.track("station_completed", {})
	return true


static func reset() -> void:
	for project: Dictionary in projects():
		GameState.set_setting(SECTION, str(project.get("id", "")), false)
