class_name MowPattern
extends RefCounted
## How the yard was cut (G28, gamification sprint 1). The model already keeps
## the pass direction of every cell for the stripe tint; read at the end, those
## directions say whether the player mowed in straight rows, in rings from the
## fence inward, or in a crosshatch — or just cut. Rows/rings/cross earn a word
## on the panel and a stamp on the postcard; nothing pays more. It is a habit
## to notice, not a score to chase.

const ROWS := "rows"
const RINGS := "rings"
const CROSS := "cross"
const SECTION := "patterns"


## "" when no pattern is clear (too few cells, or a free cut).
static func classify(model: LawnModel) -> String:
	var cols := GameConfig.GRID_COLS
	var rows := GameConfig.GRID_ROWS
	var total := 0
	var ns := 0          # cells cut on the north-south axis
	var tangent := 0     # cells cut along their ring's edge
	var pairs := 0       # cut neighbours (east, south) …
	var same := 0        # … that ran on the same axis: coherence
	# Lanes: for a north-south cut the lane is the column; count how many
	# neighbouring lanes flip direction (back-and-forth is what a row IS).
	var lane_dir_ns: Array[int] = []
	var lane_dir_ew: Array[int] = []
	lane_dir_ns.resize(cols)
	lane_dir_ew.resize(rows)
	lane_dir_ns.fill(-1)
	lane_dir_ew.fill(-1)
	for row in rows:
		for col in cols:
			if not model.is_cut(col, row):
				continue
			var d := model.stripe_at(col, row)
			if d < 0 or d > 3:
				continue
			total += 1
			var on_ns := d == 0 or d == 2
			if on_ns:
				ns += 1
				if lane_dir_ns[col] < 0:
					lane_dir_ns[col] = d
			else:
				if lane_dir_ew[row] < 0:
					lane_dir_ew[row] = d
			# The ring a cell sits on is set by its nearest edge; along a left
			# or right edge the tangent is north-south, along top or bottom
			# it is east-west.
			var to_side := mini(col, cols - 1 - col)
			var to_end := mini(row, rows - 1 - row)
			var side_ring := to_side < to_end
			if (side_ring and on_ns) or (not side_ring and not on_ns):
				tangent += 1
			for next: Vector2i in [Vector2i(col + 1, row), Vector2i(col, row + 1)]:
				if not model.is_cut(next.x, next.y):
					continue
				var nd := model.stripe_at(next.x, next.y)
				if nd < 0 or nd > 3:
					continue
				pairs += 1
				if (nd == 0 or nd == 2) == on_ns:
					same += 1
	if total < GameConfig.PATTERN_MIN_CELLS:
		return ""
	var ns_share := float(ns) / float(total)
	# A random cut also lands near half and half; what tells a crosshatch
	# from it is that neighbours agree — the axes come in blocks, not specks.
	var coherence := float(same) / float(pairs) if pairs > 0 else 0.0
	if float(tangent) / float(total) >= GameConfig.PATTERN_RINGS_MATCH \
			and ns_share > 0.25 and ns_share < 0.75:
		return RINGS
	if ns_share >= GameConfig.PATTERN_ROWS_AXIS_SHARE:
		if _alternation(lane_dir_ns) >= GameConfig.PATTERN_ROWS_ALTERNATE:
			return ROWS
		return ""
	if 1.0 - ns_share >= GameConfig.PATTERN_ROWS_AXIS_SHARE:
		if _alternation(lane_dir_ew) >= GameConfig.PATTERN_ROWS_ALTERNATE:
			return ROWS
		return ""
	if ns_share >= GameConfig.PATTERN_CROSS_MIN_AXIS \
			and 1.0 - ns_share >= GameConfig.PATTERN_CROSS_MIN_AXIS \
			and coherence >= GameConfig.PATTERN_COHERENCE:
		return CROSS
	return ""


## Share of neighbouring lane pairs whose first pass ran the opposite way.
static func _alternation(lanes: Array[int]) -> float:
	var pairs := 0
	var flips := 0
	var last := -1
	for d in lanes:
		if d < 0:
			continue
		if last >= 0:
			pairs += 1
			if d != last:
				flips += 1
		last = d
	return float(flips) / float(pairs) if pairs > 0 else 0.0


static func name_key(id: String) -> String:
	return "PATTERN_" + id.to_upper() if id != "" else ""


static func stamp_key(id: String) -> String:
	return "PATTERN_STAMP_" + id.to_upper() if id != "" else "POSTCARD_STAMP"


## How many yards were cut in each pattern, for the achievements to read later.
static func record(id: String) -> void:
	if id == "":
		return
	GameState.set_setting(SECTION, id, count(id) + 1)


static func count(id: String) -> int:
	return int(GameState.get_setting(SECTION, id, 0))
