class_name Garage
extends RefCounted
## G10 workshop state: which mowers are unlocked and how far each is upgraded,
## persisted through GameState ([garage] in settings.cfg) and keyed by the
## mower's string id, never its index.

const SECTION := "garage"


static func mower_id(type_index: int) -> String:
	return str(GameConfig.MOWER_TYPES[clampi(type_index, 0,
		GameConfig.MOWER_TYPES.size() - 1)]["id"])


static func is_unlocked(type_index: int) -> bool:
	if GameConfig.DEV_UNLOCK_ALL:
		return true
	var id := mower_id(type_index)
	if int(GameConfig.UNLOCK_COSTS.get(id, 0)) == 0:
		return true
	return bool(GameState.get_setting(SECTION, id + "_unlocked", false))


static func unlock_cost(type_index: int) -> int:
	return int(GameConfig.UNLOCK_COSTS.get(mower_id(type_index), 0))


static func tier(type_index: int) -> int:
	return int(GameState.get_setting(SECTION, mower_id(type_index) + "_tier", 0))


static func next_upgrade_cost(type_index: int) -> int:
	var costs: Array = GameConfig.UPGRADE_COSTS.get(mower_id(type_index), [])
	var current := tier(type_index)
	if current >= costs.size() or current >= GameConfig.UPGRADE_MAX_TIER:
		return -1
	return int(costs[current])


## Speed multiplier this mower earns from its tier (blade upgrades size, not
## speed, so it reports 1.0 here).
static func speed_multiplier(type_index: int) -> float:
	var bonus := float(GameConfig.UPGRADE_SPEED_BONUS.get(
		mower_id(type_index), 0.0))
	return 1.0 + bonus * float(tier(type_index))


## Called before a chapter builds, so the blade's disk is born at its size.
static func apply_blade_scale() -> void:
	var blade_index := GameConfig.MOWER_BLADE
	GameConfig.BLADE_SCALE = 1.0 \
		+ GameConfig.UPGRADE_BLADE_SCALE_STEP * float(tier(blade_index))


## Attempts the purchase; returns true and deducts on success.
static func buy_unlock(type_index: int) -> bool:
	if is_unlocked(type_index):
		return false
	var cost := unlock_cost(type_index)
	if GameState.scrap_total() < cost:
		return false
	GameState.set_setting("economy", "scrap", GameState.scrap_total() - cost)
	GameState.set_setting(SECTION, mower_id(type_index) + "_unlocked", true)
	return true


static func buy_upgrade(type_index: int) -> bool:
	var cost := next_upgrade_cost(type_index)
	if cost < 0 or GameState.scrap_total() < cost:
		return false
	GameState.set_setting("economy", "scrap", GameState.scrap_total() - cost)
	GameState.set_setting(SECTION, mower_id(type_index) + "_tier",
		tier(type_index) + 1)
	return true


static func reset() -> void:
	for entry: Dictionary in GameConfig.MOWER_TYPES:
		GameState.set_setting(SECTION, str(entry["id"]) + "_unlocked", false)
		GameState.set_setting(SECTION, str(entry["id"]) + "_tier", 0)
