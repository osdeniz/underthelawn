class_name ScrapField
extends Node3D
## G9 scrap: a handful of salvage points buried in the grass. Mowing a cell that
## holds one pops the icon out of the lawn and flies it to the HUD counter.
##
## Placement is seeded from the variant's decor_seed, so a yard's scrap sits in
## the same spots on every visit — a replay should feel like the same place, not
## a reroll.

signal collected(amount: int)
## A crate of produce, uncovered the same way (G14.12). Kept in this field
## rather than a second one: the placement rules, the spacing and the "which
## cells are still hiding something" question are all identical, and two fields
## would have had to agree with each other forever.
signal food_collected(amount: int)

var _model: LawnModel
var _points := {}          # cell index -> value
var _rng := RandomNumberGenerator.new()
var _ground_total := 0
var _props := {}          # cell index -> MoneyProp
var _food := {}           # cell index -> value
var _food_props := {}     # cell index -> FoodProp
var _food_total := 0


## `budget` is how many pickups to bury; scaled by nothing else, since the
## variant already sizes it against the yard.
func setup(model: LawnModel, budget: int, seed_value: int) -> void:
	_model = model
	_points.clear()
	_ground_total = 0
	_rng.seed = seed_value if seed_value != 0 else 20260909
	if model == null or budget <= 0:
		return
	var placed: Array[Vector2i] = []
	var tries := 0
	while placed.size() < budget and tries < GameConfig.SCRAP_PLACEMENT_TRIES:
		tries += 1
		var col := _rng.randi_range(1, GameConfig.GRID_COLS - 2)
		var row := _rng.randi_range(1, GameConfig.GRID_ROWS - 2)
		if not model.is_mowable(col, row):
			continue
		var cell := Vector2i(col, row)
		var too_close := false
		for other in placed:
			if absi(other.x - col) + absi(other.y - row) \
					< GameConfig.SCRAP_MIN_SEPARATION:
				too_close = true
				break
		if too_close:
			continue
		placed.append(cell)
		_points[LawnModel.index_of(col, row)] = int(round(
			float(_rng.randi_range(GameConfig.SCRAP_PICKUP_MIN,
				GameConfig.SCRAP_PICKUP_MAX)) * Settlers.scrap_yield()))
	if placed.size() < budget:
		print("[Scrap] %d/%d nokta yerlestirildi (%d deneme)"
			% [placed.size(), budget, tries])

	# Food, on cells of its own, chosen after the scrap so the two never share
	# one cell — a cut that paid twice would read as a bug even though it is
	# not.
	var crates := _rng.randi_range(GameConfig.FOOD_PICKUPS.x,
		GameConfig.FOOD_PICKUPS.y)
	var food_cells: Array[Vector2i] = []
	tries = 0
	while food_cells.size() < crates and tries < GameConfig.SCRAP_PLACEMENT_TRIES:
		tries += 1
		var fcol := _rng.randi_range(1, GameConfig.GRID_COLS - 2)
		var frow := _rng.randi_range(1, GameConfig.GRID_ROWS - 2)
		if not model.is_mowable(fcol, frow):
			continue
		var fkey := LawnModel.index_of(fcol, frow)
		if _points.has(fkey) or _food.has(fkey):
			continue
		var fcell := Vector2i(fcol, frow)
		var crowded := false
		for other2 in placed + food_cells:
			if absi(other2.x - fcol) + absi(other2.y - frow) \
					< GameConfig.SCRAP_MIN_SEPARATION:
				crowded = true
				break
		if crowded:
			continue
		food_cells.append(fcell)
		# A forager in the town finds more in the same yard (G14.13).
		_food[fkey] = int(round(float(_rng.randi_range(GameConfig.FOOD_VALUE.x,
			GameConfig.FOOD_VALUE.y)) * Settlers.food_yield()))
	# Visible cash bundles (G9.4): the money is a goal on the lawn, not a
	# surprise under it. Only when the field lives in a scene — the placement
	# tests run it detached.
	if is_inside_tree():
		for cell in placed:
			_props[LawnModel.index_of(cell.x, cell.y)] = MoneyProp.spawn(
				self, LawnModel.cell_center(cell.x, cell.y))
		for fcell2 in food_cells:
			_food_props[LawnModel.index_of(fcell2.x, fcell2.y)] = FoodProp.spawn(
				self, LawnModel.cell_center(fcell2.x, fcell2.y))


## Called for every cell the deck cuts. Returns the value if this cell held
## scrap, 0 otherwise.
func take(col: int, row: int) -> int:
	var key := LawnModel.index_of(col, row)
	if not _points.has(key):
		return 0
	var value: int = _points[key]
	_points.erase(key)
	if _props.has(key):
		(_props[key] as MoneyProp).collect()
		_props.erase(key)
	_ground_total += value
	collected.emit(value)
	return value


## The same question for food. Separate from take() because the two are banked
## into different pockets and shown by different counters.
func take_food(col: int, row: int) -> int:
	var key := LawnModel.index_of(col, row)
	if not _food.has(key):
		return 0
	var value: int = _food[key]
	_food.erase(key)
	if _food_props.has(key):
		(_food_props[key] as FoodProp).collect()
		_food_props.erase(key)
	_food_total += value
	food_collected.emit(value)
	return value


func food_total() -> int:
	return _food_total


func food_remaining() -> int:
	return _food.size()


func remaining() -> int:
	return _points.size()


func ground_total() -> int:
	return _ground_total


## Cells that still hold scrap, for the pop effect and for tests.
func cells() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for key: int in _points:
		out.append(Vector2i(key % GameConfig.GRID_COLS,
			key / GameConfig.GRID_COLS))
	return out


# ---------------------------------------------------------------- payout

## The end-of-chapter breakdown. Ground scrap is already banked; the bonus is
## computed from how much of the lawn was cut, floored so an early exit with the
## evidence still pays most of it.
static func payout(ground: int, mown_ratio: float, budget: int) -> Dictionary:
	# The bonus pool is sized so ground + bonus lands near the intended split at
	# full completion, whatever the budget was.
	var expected_ground := float(budget) * float(
		GameConfig.SCRAP_PICKUP_MIN + GameConfig.SCRAP_PICKUP_MAX) * 0.5
	var pool := expected_ground / maxf(GameConfig.SCRAP_GROUND_SHARE, 0.01)
	var bonus_pool := pool * GameConfig.SCRAP_BONUS_SHARE
	var ratio := clampf(mown_ratio, 0.0, 1.0)
	var scaled := lerpf(GameConfig.SCRAP_BONUS_FLOOR, 1.0, ratio)
	var bonus := int(round(bonus_pool * scaled))
	# G12.7: a working farm lifts every payout a little.
	bonus = int(round(float(bonus) * (1.0 + GameConfig.restore_payout_bonus())))
	var thorough := 0
	if ratio >= 0.999:
		thorough = int(round(bonus_pool * GameConfig.SCRAP_THOROUGH_BONUS))
	return {
		"ground": ground,
		"bonus": bonus,
		"thorough": thorough,
		"total": ground + bonus + thorough,
		"ratio": ratio,
	}
