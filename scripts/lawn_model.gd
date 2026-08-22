class_name LawnModel
extends RefCounted
## Pure data model for the lawn — REFERENCE.md §3. No rendering, no nodes.
##
## Grid is 16 x 24 = 384 cells, origin centred. Cell centre is
## x = col + 0.5 - 8, z = row + 0.5 - 12; row 0 is north (-Z), row 23 south.

signal cell_tint_changed(col: int, row: int)
signal secret_revealed(col: int, row: int)
signal completed()

enum CellState { TALL, MOWED, OBSTACLE, SECRET, SECRET_REVEALED }
enum MowResult { NONE, MOWED, SECRET_REVEALED }

## One entry per obstacle: grid rect (col, row, cols, rows). Multi-cell
## obstacles get ONE collision rect so the mower slides along the edge
## instead of rattling cell to cell (§3, §18 trap 3).
const OBSTACLES: Array[Dictionary] = [
	{ "name": "flowerbed", "grid": Rect2i(4, 14, 2, 1) },
	{ "name": "stone", "grid": Rect2i(11, 9, 1, 1) },
	{ "name": "pool", "grid": Rect2i(10, 17, 4, 3) },
	{ "name": "sunbed", "grid": Rect2i(14, 18, 1, 1) },
]

var states: PackedByteArray = PackedByteArray()
## Direction bucket of the last pass over each cell; -1 = never mown.
var stripes: PackedByteArray = PackedByteArray()
var mowed_count: int = 0
var mowable_cells: int = 0
## World-space XZ collision rectangles, one per obstacle.
var collision_rects: Array[Rect2] = []
var secret_cells: Array[Vector2i] = []

var _rng := RandomNumberGenerator.new()
var _completed := false


func _init(seed_value: int = 0) -> void:
	if seed_value != 0:
		_rng.seed = seed_value
	else:
		_rng.randomize()
	states.resize(GameConfig.CELL_COUNT)
	stripes.resize(GameConfig.CELL_COUNT)
	_build_obstacles()
	reset()


# ---------------------------------------------------------------- geometry

static func index_of(col: int, row: int) -> int:
	return row * GameConfig.GRID_COLS + col


static func in_bounds(col: int, row: int) -> bool:
	return col >= 0 and row >= 0 and col < GameConfig.GRID_COLS and row < GameConfig.GRID_ROWS


static func cell_center(col: int, row: int) -> Vector3:
	return Vector3(
		float(col) + 0.5 - GameConfig.HALF_X,
		0.0,
		float(row) + 0.5 - GameConfig.HALF_Z
	)


static func cell_at(world: Vector3) -> Vector2i:
	return Vector2i(
		int(floor(world.x + GameConfig.HALF_X)),
		int(floor(world.z + GameConfig.HALF_Z))
	)


static func grid_rect_to_world(grid: Rect2i) -> Rect2:
	return Rect2(
		float(grid.position.x) - GameConfig.HALF_X,
		float(grid.position.y) - GameConfig.HALF_Z,
		float(grid.size.x),
		float(grid.size.y)
	)


# ---------------------------------------------------------------- state

func state_at(col: int, row: int) -> CellState:
	if not in_bounds(col, row):
		return CellState.OBSTACLE
	return states[index_of(col, row)] as CellState


func stripe_at(col: int, row: int) -> int:
	var s := stripes[index_of(col, row)]
	return -1 if s == 255 else int(s)


func is_mowable(col: int, row: int) -> bool:
	return in_bounds(col, row) and states[index_of(col, row)] != CellState.OBSTACLE


func is_cut(col: int, row: int) -> bool:
	if not in_bounds(col, row):
		return false
	var s := states[index_of(col, row)]
	return s == CellState.MOWED or s == CellState.SECRET_REVEALED


func completion_ratio() -> float:
	if mowable_cells == 0:
		return 0.0
	return float(mowed_count) / float(mowable_cells)


func is_complete() -> bool:
	return mowed_count >= mowable_cells


## Mows one cell from a pass travelling in `stripe_dir` (0=N 1=E 2=S 3=W).
## TALL -> MOWED, SECRET -> SECRET_REVEALED. An already mown cell returns NONE
## but still updates its stripe tone if the pass direction differs (§4).
func mow(col: int, row: int, stripe_dir: int) -> MowResult:
	if not in_bounds(col, row):
		return MowResult.NONE
	var i := index_of(col, row)
	var state := states[i]

	if state == CellState.OBSTACLE:
		return MowResult.NONE

	if state == CellState.MOWED or state == CellState.SECRET_REVEALED:
		# Re-striping: tone follows the newest pass, counters do not move.
		if stripe_at(col, row) != stripe_dir:
			stripes[i] = stripe_dir
			cell_tint_changed.emit(col, row)
		return MowResult.NONE

	stripes[i] = stripe_dir
	mowed_count += 1

	var result := MowResult.MOWED
	if state == CellState.SECRET:
		states[i] = CellState.SECRET_REVEALED
		result = MowResult.SECRET_REVEALED
		secret_revealed.emit(col, row)
	else:
		states[i] = CellState.MOWED

	cell_tint_changed.emit(col, row)

	if not _completed and is_complete():
		_completed = true
		completed.emit()
	return result


# ---------------------------------------------------------------- setup

func reset() -> void:
	_completed = false
	mowed_count = 0
	for row in GameConfig.GRID_ROWS:
		for col in GameConfig.GRID_COLS:
			var i := index_of(col, row)
			stripes[i] = 255                      # -1, never mown
			if states[i] != CellState.OBSTACLE:
				states[i] = CellState.TALL
	_place_secrets()
	_recount_mowable()


func _build_obstacles() -> void:
	collision_rects.clear()
	for ob in OBSTACLES:
		var grid: Rect2i = ob["grid"]
		for row in range(grid.position.y, grid.position.y + grid.size.y):
			for col in range(grid.position.x, grid.position.x + grid.size.x):
				if in_bounds(col, row):
					states[index_of(col, row)] = CellState.OBSTACLE
		collision_rects.append(grid_rect_to_world(grid))


func _recount_mowable() -> void:
	mowable_cells = 0
	for i in GameConfig.CELL_COUNT:
		if states[i] != CellState.OBSTACLE:
			mowable_cells += 1


## Two secrets per run: at least SECRET_EDGE_MARGIN cells in from every edge,
## on a TALL cell, at least SECRET_MIN_SEPARATION cells apart. Redistributed on
## every reset (§3, §18 trap 4).
func _place_secrets() -> void:
	secret_cells.clear()
	var margin := GameConfig.SECRET_EDGE_MARGIN
	var tries := 0
	while secret_cells.size() < GameConfig.SECRET_COUNT \
			and tries < GameConfig.SECRET_PLACEMENT_TRIES:
		tries += 1
		var col := _rng.randi_range(margin, GameConfig.GRID_COLS - 1 - margin)
		var row := _rng.randi_range(margin, GameConfig.GRID_ROWS - 1 - margin)
		if states[index_of(col, row)] != CellState.TALL:
			continue
		var candidate := Vector2i(col, row)
		var too_close := false
		for existing in secret_cells:
			if Vector2(candidate - existing).length() < float(GameConfig.SECRET_MIN_SEPARATION):
				too_close = true
				break
		if too_close:
			continue
		secret_cells.append(candidate)
		states[index_of(col, row)] = CellState.SECRET

	if secret_cells.size() < GameConfig.SECRET_COUNT:
		push_warning("LawnModel: only placed %d/%d secrets in %d tries"
			% [secret_cells.size(), GameConfig.SECRET_COUNT, tries])


# ---------------------------------------------------------------- helpers

## Direction bucket for a heading: |fx| >= |fz| picks east/west, else
## north/south. North is -Z (§2, §4).
static func stripe_bucket(forward: Vector3) -> int:
	if absf(forward.x) >= absf(forward.z):
		return GameConfig.STRIPE_EAST if forward.x > 0.0 else GameConfig.STRIPE_WEST
	return GameConfig.STRIPE_NORTH if forward.z < 0.0 else GameConfig.STRIPE_SOUTH


## Tint colour a cell should paint into the 16x24 tint texture (§4, §5).
func tint_for(col: int, row: int) -> Color:
	var i := index_of(col, row)
	match states[i]:
		CellState.OBSTACLE:
			return GameConfig.TINT_POOL_FLOOR if _is_pool(col, row) else GameConfig.TINT_SOIL
		CellState.SECRET_REVEALED:
			return GameConfig.TINT_SOIL
		CellState.MOWED:
			var s := stripe_at(col, row)
			return GameConfig.TINT_STRIPE[s] if s >= 0 else GameConfig.TINT_TALL
		_:
			return GameConfig.TINT_TALL


func _is_pool(col: int, row: int) -> bool:
	for ob in OBSTACLES:
		if ob["name"] == "pool":
			var g: Rect2i = ob["grid"]
			return col >= g.position.x and col < g.position.x + g.size.x \
				and row >= g.position.y and row < g.position.y + g.size.y
	return false
