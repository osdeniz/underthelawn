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
	if project.is_empty() or is_built(project_id):
		return false
	var cost := int(project.get("cost", 0))
	if GameState.scrap_total() < cost:
		return false
	GameState.set_setting("economy", "scrap", GameState.scrap_total() - cost)
	GameState.set_setting(SECTION, project_id, true)
	Analytics.track("restore_bought", {"id": project_id, "cost": cost})
	return true


static func reset() -> void:
	for project: Dictionary in projects():
		GameState.set_setting(SECTION, str(project.get("id", "")), false)
