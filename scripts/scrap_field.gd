class_name ScrapField
extends Node3D
## G9 scrap: a handful of salvage points buried in the grass. Mowing a cell that
## holds one pops the icon out of the lawn and flies it to the HUD counter.
##
## Placement is seeded from the variant's decor_seed, so a yard's scrap sits in
## the same spots on every visit — a replay should feel like the same place, not
## a reroll.

signal collected(amount: int)

var _model: LawnModel
var _points := {}          # cell index -> value
var _rng := RandomNumberGenerator.new()
var _ground_total := 0
var _props := {}          # cell index -> MoneyProp


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
		_points[LawnModel.index_of(col, row)] = _rng.randi_range(
			GameConfig.SCRAP_PICKUP_MIN, GameConfig.SCRAP_PICKUP_MAX)
	if placed.size() < budget:
		print("[Scrap] %d/%d nokta yerlestirildi (%d deneme)"
			% [placed.size(), budget, tries])
	# Visible cash bundles (G9.4): the money is a goal on the lawn, not a
	# surprise under it. Only when the field lives in a scene — the placement
	# tests run it detached.
	if is_inside_tree():
		for cell in placed:
			_props[LawnModel.index_of(cell.x, cell.y)] = MoneyProp.spawn(
				self, LawnModel.cell_center(cell.x, cell.y))


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
