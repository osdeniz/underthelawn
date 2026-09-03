class_name LawnModel
extends RefCounted
## Pure data model for the lawn — REFERENCE.md §3. No rendering, no nodes.
##
## Grid is 16 x 24 = 384 cells, origin centred. Cell centre is
## x = col + 0.5 - 8, z = row + 0.5 - 12; row 0 is north (-Z), row 23 south.

signal cell_tint_changed(col: int, row: int)
signal secret_revealed(col: int, row: int)
## A fragile piece was driven over instead of uncovered (G15.5). Emitted right
## after secret_revealed for the same cell: the piece is still found, it is just
## not whole any more.
signal secret_crushed(col: int, row: int)
signal completed()

enum CellState { TALL, MOWED, OBSTACLE, SECRET, SECRET_REVEALED }
enum MowResult { NONE, MOWED, SECRET_REVEALED }

## One entry per obstacle: grid rect (col, row, cols, rows). Multi-cell
## obstacles get ONE collision rect so the mower slides along the edge
## instead of rattling cell to cell (§3, §18 trap 3).
## Four hand-built layouts a LevelVariant picks from by id (G9). Positions are
## FRACTIONS of the grid, not cells, so one layout works at 10x14 and at 20x30
## without a second table; sizes stay in cells so a pool is always pool-sized.
## Every layout keeps the south-centre spawn strip and the north approach clear.
const OBSTACLE_LAYOUTS := {
	# B1's original yard, expressed in the new form: flowerbed + stone, no pool.
	"beds": [
		{ "name": "flowerbed", "fx": 0.25, "fz": 0.58, "cols": 2, "rows": 1 },
		{ "name": "flowerbed", "fx": 0.62, "fz": 0.30, "cols": 2, "rows": 1 },
		{ "name": "stone", "fx": 0.70, "fz": 0.40, "cols": 1, "rows": 1 },
	],
	# A pool dominates the south-east and forces a long way round.
	"pool": [
		{ "name": "pool", "fx": 0.64, "fz": 0.72, "cols": 4, "rows": 3 },
		{ "name": "sunbed", "fx": 0.90, "fz": 0.76, "cols": 1, "rows": 1 },
		{ "name": "flowerbed", "fx": 0.22, "fz": 0.55, "cols": 2, "rows": 1 },
	],
	# Scattered stones pinch the middle into narrow lanes.
	"stones": [
		{ "name": "stone", "fx": 0.30, "fz": 0.28, "cols": 1, "rows": 1 },
		{ "name": "stone", "fx": 0.55, "fz": 0.40, "cols": 1, "rows": 1 },
		{ "name": "stone", "fx": 0.34, "fz": 0.52, "cols": 1, "rows": 1 },
		{ "name": "stone", "fx": 0.68, "fz": 0.60, "cols": 1, "rows": 1 },
		{ "name": "stone", "fx": 0.46, "fz": 0.72, "cols": 1, "rows": 1 },
	],
	# Nothing in the way: for the big field and the playground.
	"open": [],
	# The prologue's road (G15.1): fallen timber and rubble alternating from
	# each side, so the clear line weaves across the lane instead of running
	# straight up the middle.
	#
	# Both props FILL their rect. That matters: the "stone" prop draws a single
	# 0.42 ball wherever the rect's centre is, so a seven-cell stone rect would
	# be an invisible wall six cells wide. "log" and "rubble" are built to the
	# rect they were given.
	#
	# resolve_layout keeps a one-cell border clear on every side, so there is
	# always a thin lane past each block and the road can never dead-end. That
	# is a feature here, not a limitation: a tutorial must not be able to trap
	# anybody.
	"road": [
		# Where the dog and the basket are (G15.2). A non-mowable rect with no
		# grass on it, so they stand on bare short ground and can be SEEN — in
		# the tall grass a 0.56 dog vanished, the same way the rabbit did.
		# Being an obstacle also keeps the mower off the baby.
		{ "name": "patch", "fx": 0.36, "fz": 0.02, "cols": 3, "rows": 2 },
		# Two rows of grass between the patch and the first log. At fz 0.09 the
		# log landed ON the patch's second row and lay across the basket: from
		# the road the child was a wicker handle sticking up behind a trunk.
		{ "name": "log", "fx": 0.00, "fz": 0.15, "cols": 5, "rows": 1 },
		{ "name": "rubble", "fx": 0.40, "fz": 0.19, "cols": 5, "rows": 1 },
		{ "name": "log", "fx": 0.00, "fz": 0.29, "cols": 5, "rows": 1 },
		{ "name": "rubble", "fx": 0.40, "fz": 0.39, "cols": 5, "rows": 2 },
		{ "name": "log", "fx": 0.00, "fz": 0.51, "cols": 5, "rows": 1 },
		{ "name": "rubble", "fx": 0.40, "fz": 0.61, "cols": 5, "rows": 1 },
		{ "name": "log", "fx": 0.00, "fz": 0.71, "cols": 5, "rows": 2 },
		{ "name": "rubble", "fx": 0.40, "fz": 0.83, "cols": 5, "rows": 1 },
	],
}

## Filled by _build_obstacles from the active layout. Kept under the old name so
## everything that read OBSTACLES keeps working.
var obstacles: Array[Dictionary] = []
## Which OBSTACLE_LAYOUTS entry to build. Set before _init by LevelVariant.
static var layout_id := "beds"

var states: PackedByteArray = PackedByteArray()
## Direction bucket of the last pass over each cell; -1 = never mown.
var stripes: PackedByteArray = PackedByteArray()
var mowed_count: int = 0
var mowable_cells: int = 0
## World-space XZ collision rectangles, one per obstacle.
var collision_rects: Array[Rect2] = []
var secret_cells: Array[Vector2i] = []
## The one piece that can only be reached on foot, or (-1, -1) (G15.5). Its
## eight neighbours are reeds: OBSTACLE cells with a collision rect, so the
## machine stops at the ring and the walker steps through it.
var walk_only_cell := Vector2i(-1, -1)

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
	# Against ITS OWN array, not just against the global grid. in_bounds() asks
	# GameConfig, and the grid is global mutable state that outlives no
	# particular model: a scene torn down while another chapter's grid is
	# already set indexes a model built for a different shape and crashes on a
	# read. The model is the thing that knows how big the model is (G13).
	if i < 0 or i >= states.size():
		return MowResult.NONE
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
		# Driven straight over. A fragile piece is meant to be UNCOVERED — the
		# grass around it cut so it lies there in the open — and a wheel across
		# it is what "gently" was warning about (G15.5).
		if _is_fragile_cell(col, row):
			secret_crushed.emit(col, row)
	else:
		states[i] = CellState.MOWED
		# Cutting BESIDE a fragile piece is how it is found intact: the blades
		# open the grass and there it is, in the next cell, untouched.
		for step: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1),
				Vector2i(0, -1)]:
			var n := Vector2i(col + step.x, row + step.y)
			if in_bounds(n.x, n.y) and states[index_of(n.x, n.y)] == CellState.SECRET \
					and _is_fragile_cell(n.x, n.y):
				reveal(n.x, n.y)

	cell_tint_changed.emit(col, row)

	if not _completed and is_complete():
		_completed = true
		completed.emit()
	return result


# ---------------------------------------------------------------- setup

## Uncovers a buried cell WITHOUT a pass over it: the fragile piece seen from
## the next cell, or the walk-only piece reached on foot (G15.5). Counts as cut
## for completion, like every SECRET_REVEALED cell does.
func reveal(col: int, row: int) -> void:
	if not in_bounds(col, row):
		return
	var i := index_of(col, row)
	if i < 0 or i >= states.size() or states[i] != CellState.SECRET:
		return
	states[i] = CellState.SECRET_REVEALED
	mowed_count += 1
	secret_revealed.emit(col, row)
	cell_tint_changed.emit(col, row)
	if not _completed and is_complete():
		_completed = true
		completed.emit()


func _is_fragile_cell(col: int, row: int) -> bool:
	if LevelVariant.current == null:
		return false
	return LevelVariant.current.is_fragile(secret_cells.find(Vector2i(col, row)))


## Rings the first secret with reeds so only a walker can reach it (G15.5).
## Called after the secrets are placed. The ring cells become OBSTACLE — they
## come off the cuttable count — and one 3x3 collision rect keeps the machine
## out; the walker clamps only to the lawn, so it steps straight in.
func _place_walk_only() -> void:
	walk_only_cell = Vector2i(-1, -1)
	if LevelVariant.current == null or not LevelVariant.current.walk_only_evidence:
		return
	if secret_cells.is_empty():
		return
	var cell: Vector2i = secret_cells[0]
	for dr in range(-1, 2):
		for dc in range(-1, 2):
			if dr == 0 and dc == 0:
				continue
			var c := cell.x + dc
			var r := cell.y + dr
			if in_bounds(c, r) and states[index_of(c, r)] == CellState.TALL:
				states[index_of(c, r)] = CellState.OBSTACLE
	collision_rects.append(grid_rect_to_world(Rect2i(cell.x - 1, cell.y - 1, 3, 3)))
	walk_only_cell = cell
	_recount_mowable()


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
	_place_walk_only()
	_recount_mowable()


## Resolves a layout's fractions into grid rects against the CURRENT grid.
## Static and side-effect free, because EnvironmentBuilder needs the same answer
## in its own _ready — which runs before any LawnModel exists — to decide which
## props and which pool to build. One resolver, so geometry and collision can
## never disagree.
static func resolve_layout(id: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var layout: Array = OBSTACLE_LAYOUTS.get(id, OBSTACLE_LAYOUTS["beds"])
	for spec: Dictionary in layout:
		var cols := int(spec.get("cols", 1))
		var rows := int(spec.get("rows", 1))
		# Clamped, so a layout authored for a medium yard cannot hang off the
		# edge of a small one.
		var col := clampi(int(round(float(spec["fx"]) * GameConfig.GRID_COLS)),
			1, maxi(GameConfig.GRID_COLS - cols - 1, 1))
		var row := clampi(int(round(float(spec["fz"]) * GameConfig.GRID_ROWS)),
			2, maxi(GameConfig.GRID_ROWS - rows - 2, 2))
		out.append({ "name": spec["name"], "grid": Rect2i(col, row, cols, rows) })
	return out


func _build_obstacles() -> void:
	collision_rects.clear()
	obstacles = resolve_layout(layout_id)
	for ob: Dictionary in obstacles:
		var grid: Rect2i = ob["grid"]
		for r in range(grid.position.y, grid.end.y):
			for c in range(grid.position.x, grid.end.x):
				if in_bounds(c, r):
					states[index_of(c, r)] = CellState.OBSTACLE
		collision_rects.append(grid_rect_to_world(grid))


func _recount_mowable() -> void:
	mowable_cells = 0
	for i in GameConfig.CELL_COUNT:
		if states[i] != CellState.OBSTACLE:
			mowable_cells += 1


## Two secrets per run: at least SECRET_EDGE_MARGIN cells in from every edge,
## on a TALL cell, at least SECRET_MIN_SEPARATION cells apart. Redistributed on
## The row band this chapter's evidence may land in. Row 0 is north, the far
## edge; the mower starts at the south. A chapter that wants its evidence past
## a crossing says evidence_zone "far" and gets the northern half (G13).
func _row_floor(margin: int) -> int:
	var zone := LevelVariant.current.evidence_zone if LevelVariant.current != null \
		else "any"
	if zone == "far":
		return margin
	if zone == "near":
		return int(GameConfig.GRID_ROWS * 0.55)
	return margin


func _row_ceil(margin: int) -> int:
	var zone := LevelVariant.current.evidence_zone if LevelVariant.current != null \
		else "any"
	var last := GameConfig.GRID_ROWS - 1 - margin
	if zone == "far":
		return maxi(int(GameConfig.GRID_ROWS * 0.45), margin + 1)
	return last


## every reset (§3, §18 trap 4).
func _place_secrets() -> void:
	secret_cells.clear()
	# A harvest buries nothing: the field is work, not a search (G13.6). Nor
	# does the prologue's road (G15.2): it shipped with two default secrets
	# in it, so the first thing a new player dug up on the long walk was a
	# radio that belonged to a case nine years away.
	if LevelVariant.current != null \
			and (LevelVariant.current.is_harvest() or LevelVariant.current.is_road()):
		return
	var margin := GameConfig.SECRET_EDGE_MARGIN
	var tries := 0
	while secret_cells.size() < GameConfig.SECRET_COUNT \
			and tries < GameConfig.SECRET_PLACEMENT_TRIES:
		tries += 1
		var col := _rng.randi_range(margin, GameConfig.GRID_COLS - 1 - margin)
		var row := _rng.randi_range(_row_floor(margin), _row_ceil(margin))
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
			return GameConfig.stripe_tint(s) if s >= 0 else GameConfig.ground_tall_tint()
		_:
			return GameConfig.ground_tall_tint()


func _is_pool(col: int, row: int) -> bool:
	for ob in obstacles:
		if ob["name"] == "pool":
			var g: Rect2i = ob["grid"]
			return col >= g.position.x and col < g.position.x + g.size.x \
				and row >= g.position.y and row < g.position.y + g.size.y
	return false
