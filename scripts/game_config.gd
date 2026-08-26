class_name GameConfig
extends RefCounted
## Every tunable number, per REFERENCE.md §17 (plus the sections it points at).
## Nothing here is invented; each block cites its source section.

# ---------------------------------------------------------------- platform
const VIEWPORT_WIDTH := 1170
const VIEWPORT_HEIGHT := 2532

# ---------------------------------------------------------------- world (§2)
## G9: the grid is DATA now. These keep their old names, so all fifty existing
## call sites are untouched, but they are static vars a LevelVariant rewrites
## through set_grid() before the model is built. Cell size stays 1.0 world unit,
## so half-extents are always half the cell counts.
static var GRID_COLS := 16
static var GRID_ROWS := 24
static var CELL_COUNT := 16 * 24
## The three standard yard sizes a variant can ask for, plus B8's cellar.
const GRID_SIZES := {
	"small": Vector2i(12, 18),
	"medium": Vector2i(16, 24),
	"large": Vector2i(20, 30),
	"cellar": Vector2i(10, 14),
}


## Called once per chapter, BEFORE LawnModel is constructed: everything that
## reads the grid (model, view, tuft field, camera bounds, robot route planner,
## completion percentage) derives from these four numbers.
static func set_grid(cols: int, rows: int) -> void:
	GRID_COLS = maxi(cols, 4)
	GRID_ROWS = maxi(rows, 4)
	CELL_COUNT = GRID_COLS * GRID_ROWS
	HALF_X = float(GRID_COLS) * 0.5
	HALF_Z = float(GRID_ROWS) * 0.5


static func set_grid_named(size_id: String) -> void:
	var size: Vector2i = GRID_SIZES.get(size_id, GRID_SIZES["medium"])
	set_grid(size.x, size.y)
## Cell centre: x = col + 0.5 - 8, z = row + 0.5 - 12. Row 0 = north (-Z).
static var HALF_X := 8.0
static var HALF_Z := 12.0
## South-centre spawn, facing north. A function of the grid (G9.1): 1.5 cells in
## from the south edge, whatever the yard size.
static func mower_start() -> Vector2:
	return Vector2(0.0, HALF_Z - 1.5)

# ---------------------------------------------------------------- striping (§4)
## Direction buckets: 0 = N, 1 = E, 2 = S, 3 = W.
const STRIPE_NORTH := 0
const STRIPE_EAST := 1
const STRIPE_SOUTH := 2
const STRIPE_WEST := 3
## G6.6: stripe and tall tints now live in GRASS_PALETTES above — use
## stripe_tint(), ground_tall_tint().
const TINT_SOIL := Color(0.52, 0.38, 0.26)
const TINT_POOL_FLOOR := Color(0.70, 0.92, 0.95)

# ---------------------------------------------------------------- grass (§5)
const GROUND_UV_REPEAT_X := 7.0
const GROUND_UV_REPEAT_Z := 10.5
const GROUND_NORMAL_STRENGTH := 0.6
const GROUND_ROUGHNESS := 0.95

## G6.6 grass palette system: every grass colour in the game reads from the
## ACTIVE palette below. Levels can later swap palettes with ONE line. The
## ground albedo texture is NEUTRAL luminance detail; all hue lives in tints,
## so any palette family renders correctly.
## Set per chapter by LevelVariant. grass_palette() is the only reader, so every
## grass colour in the game follows from this one string (G6.6 infrastructure).
static var active_grass_palette := "GREEN"

const GRASS_PALETTES := {
	"GREEN": {
		"cluster_base": Color(0.075, 0.26, 0.055),
		"cluster_tip": Color(0.33, 0.70, 0.20),
		# Accent clumps: colour pair, spawn weight, and whether they flower.
		"accents": [
			{ "base": Color(0.16, 0.26, 0.06), "tip": Color(0.62, 0.63, 0.24),
				"weight": 0.15, "flowers": false },
			{ "base": Color(0.11, 0.32, 0.08), "tip": Color(0.48, 0.80, 0.32),
				"weight": 0.05, "flowers": true },
		],
		# Mowed stripe ladder N/E/S/W, calibrated against the neutral albedo.
		"ground_mowed": [
			Color(0.27, 0.68, 0.16), Color(0.24, 0.63, 0.135),
			Color(0.16, 0.48, 0.09), Color(0.20, 0.56, 0.11),
		],
		"clipping": Color(0.40, 0.72, 0.22),
	},
	# Proof-of-infrastructure palette; NOT active. Switching is one line above.
	"PURPLE": {
		"cluster_base": Color(0.13, 0.055, 0.24),
		"cluster_tip": Color(0.60, 0.36, 0.92),
		"accents": [
			{ "base": Color(0.26, 0.07, 0.20), "tip": Color(0.92, 0.44, 0.74),
				"weight": 0.15, "flowers": false },
			{ "base": Color(0.20, 0.12, 0.34), "tip": Color(0.80, 0.64, 0.98),
				"weight": 0.05, "flowers": true },
		],
		"ground_mowed": [
			Color(0.58, 0.38, 0.84), Color(0.52, 0.33, 0.78),
			Color(0.36, 0.21, 0.58), Color(0.44, 0.27, 0.68),
		],
		"clipping": Color(0.62, 0.40, 0.90),
	},

	# --- G9 chapter palettes. The ground albedo is NEUTRAL luminance detail, so
	# a palette only has to state hue and value and every surface follows: tall
	# clumps, the mowed stripe ladder, clippings and the derived ground tint.
	# A soft green stripe ladder against dry blades is what makes a yard read as
	# "cut" no matter how odd the grass colour is.

	# B2: dew-grey teal, unmistakably a different morning from B1's warm green —
	# the first two chapters sit side by side on the board, so THESE two have to
	# differ the most (G9.2 tuning after they read as siblings).
	"GREEN_COOL": {
		"cluster_base": Color(0.04, 0.19, 0.16),
		"cluster_tip": Color(0.24, 0.60, 0.52),
		"accents": [
			{ "base": Color(0.10, 0.20, 0.19), "tip": Color(0.48, 0.62, 0.58),
				"weight": 0.18, "flowers": false },
			{ "base": Color(0.07, 0.24, 0.24), "tip": Color(0.38, 0.74, 0.70),
				"weight": 0.05, "flowers": true },
		],
		"ground_mowed": [
			Color(0.20, 0.55, 0.44), Color(0.17, 0.50, 0.39),
			Color(0.12, 0.38, 0.28), Color(0.15, 0.44, 0.33),
		],
		"clipping": Color(0.30, 0.62, 0.52),
	},

	# B3: unwatered for a long time. Straw over a green undertone, so the cut
	# stripes still read as grass rather than sand.
	"DRY_GOLD": {
		"cluster_base": Color(0.24, 0.19, 0.06),
		"cluster_tip": Color(0.80, 0.70, 0.30),
		"accents": [
			{ "base": Color(0.28, 0.21, 0.07), "tip": Color(0.88, 0.78, 0.42),
				"weight": 0.20, "flowers": false },
			{ "base": Color(0.20, 0.22, 0.08), "tip": Color(0.62, 0.68, 0.30),
				"weight": 0.06, "flowers": true },
		],
		"ground_mowed": [
			Color(0.62, 0.56, 0.22), Color(0.56, 0.50, 0.19),
			Color(0.40, 0.35, 0.13), Color(0.48, 0.43, 0.16),
		],
		"clipping": Color(0.74, 0.66, 0.30),
	},

	# B4: standing water. Dark, brown-shifted, low contrast.
	"MARSH": {
		"cluster_base": Color(0.07, 0.13, 0.06),
		"cluster_tip": Color(0.30, 0.42, 0.18),
		"accents": [
			{ "base": Color(0.14, 0.12, 0.06), "tip": Color(0.44, 0.38, 0.18),
				"weight": 0.24, "flowers": false },
			{ "base": Color(0.06, 0.16, 0.10), "tip": Color(0.26, 0.50, 0.30),
				"weight": 0.05, "flowers": true },
		],
		"ground_mowed": [
			Color(0.24, 0.36, 0.16), Color(0.21, 0.32, 0.14),
			Color(0.14, 0.23, 0.10), Color(0.18, 0.28, 0.12),
		],
		"clipping": Color(0.32, 0.44, 0.20),
	},

	# B5: watered, fed, flowering. The heaviest accent weight of any palette.
	"LUSH": {
		"cluster_base": Color(0.06, 0.28, 0.07),
		"cluster_tip": Color(0.38, 0.82, 0.26),
		"accents": [
			{ "base": Color(0.10, 0.30, 0.10), "tip": Color(0.56, 0.86, 0.34),
				"weight": 0.18, "flowers": true },
			{ "base": Color(0.14, 0.26, 0.12), "tip": Color(0.74, 0.82, 0.40),
				"weight": 0.14, "flowers": true },
		],
		"ground_mowed": [
			Color(0.30, 0.76, 0.20), Color(0.26, 0.70, 0.17),
			Color(0.18, 0.54, 0.12), Color(0.22, 0.62, 0.14),
		],
		"clipping": Color(0.46, 0.80, 0.26),
	},

	# B6: the big field at the end of the day. Warm gold, still clearly grass.
	"AMBER": {
		"cluster_base": Color(0.26, 0.17, 0.05),
		"cluster_tip": Color(0.88, 0.64, 0.22),
		"accents": [
			{ "base": Color(0.30, 0.20, 0.06), "tip": Color(0.94, 0.74, 0.34),
				"weight": 0.18, "flowers": false },
			{ "base": Color(0.24, 0.20, 0.06), "tip": Color(0.76, 0.66, 0.26),
				"weight": 0.06, "flowers": true },
		],
		"ground_mowed": [
			Color(0.70, 0.52, 0.18), Color(0.63, 0.46, 0.16),
			Color(0.45, 0.32, 0.11), Color(0.54, 0.39, 0.13),
		],
		"clipping": Color(0.82, 0.60, 0.22),
	},

	# B7: last light. Desaturated violet-grey; the one palette where the stripe
	# ladder carries almost all of the "this is cut" reading.
	"DUSK_VIOLET": {
		"cluster_base": Color(0.13, 0.11, 0.18),
		"cluster_tip": Color(0.46, 0.42, 0.58),
		"accents": [
			{ "base": Color(0.17, 0.13, 0.20), "tip": Color(0.58, 0.50, 0.66),
				"weight": 0.18, "flowers": false },
			{ "base": Color(0.12, 0.13, 0.22), "tip": Color(0.40, 0.44, 0.68),
				"weight": 0.06, "flowers": true },
		],
		"ground_mowed": [
			Color(0.40, 0.36, 0.52), Color(0.35, 0.32, 0.47),
			Color(0.24, 0.22, 0.34), Color(0.30, 0.27, 0.40),
		],
		"clipping": Color(0.50, 0.45, 0.62),
	},

	# B8: the cellar garden. Deep saturated green that reads as lit from above.
	"EMERALD": {
		"cluster_base": Color(0.03, 0.20, 0.10),
		"cluster_tip": Color(0.18, 0.78, 0.40),
		"accents": [
			{ "base": Color(0.05, 0.22, 0.14), "tip": Color(0.28, 0.86, 0.52),
				"weight": 0.16, "flowers": false },
			{ "base": Color(0.06, 0.18, 0.16), "tip": Color(0.34, 0.82, 0.66),
				"weight": 0.06, "flowers": true },
		],
		"ground_mowed": [
			Color(0.14, 0.66, 0.32), Color(0.12, 0.60, 0.29),
			Color(0.07, 0.44, 0.20), Color(0.10, 0.52, 0.24),
		],
		"clipping": Color(0.22, 0.72, 0.38),
	},
}


static func grass_palette() -> Dictionary:
	if not GRASS_PALETTES.has(active_grass_palette):
		push_warning("[GameConfig] bilinmeyen palet '%s' - GREEN kullanildi"
			% active_grass_palette)
		return GRASS_PALETTES["GREEN"]
	return GRASS_PALETTES[active_grass_palette]


## RULE: the uncut ground tint is ALWAYS derived from the cluster family — the
## ground must read as the base of the grass, never a foreign colour. New
## palettes get a correct ground automatically.
static func ground_tall_tint() -> Color:
	var pal := grass_palette()
	var base: Color = pal["cluster_base"]
	var tip: Color = pal["cluster_tip"]
	return base.lerp(tip, 0.5) * 1.05


static func stripe_tint(direction: int) -> Color:
	var tones: Array = grass_palette()["ground_mowed"]
	return tones[clampi(direction, 0, tones.size() - 1)]


static func clipping_color() -> Color:
	return grass_palette()["clipping"]


## Clump variant list built from the palette: 5 main variants (slight
## deterministic brightness spread) plus the palette's accents.
## Entries: { base, tip, flowers, weight }.
static func clump_variants() -> Array:
	var pal := grass_palette()
	var base: Color = pal["cluster_base"]
	var tip: Color = pal["cluster_tip"]
	var accents: Array = pal["accents"]
	var accent_weight := 0.0
	for a in accents:
		accent_weight += a["weight"]
	var main_weight := (1.0 - accent_weight) / 5.0
	var out: Array = []
	for spread: float in [1.0, 0.88, 1.12, 0.94, 1.06]:
		out.append({ "base": base * spread, "tip": tip * spread,
			"flowers": false, "weight": main_weight })
	for a in accents:
		out.append({ "base": a["base"], "tip": a["tip"],
			"flowers": a["flowers"], "weight": a["weight"] })
	return out


## G6.6 density: carpet, not islands — the ground should barely show through
## uncut grass. Knob ladder for phone calibration: 9 -> 7 -> 5.
const TUFTS_PER_CLUSTER := 9
const CLUMP_BLADES := 6
const CLUMP_HEIGHT_MIN := 0.4
const CLUMP_HEIGHT_MAX := 0.9
## 70% short filler, 30% tall spikes out of the band above.
const CLUMP_TALL_CHANCE := 0.3
const CLUMP_BASE_MIN := 0.45
const CLUMP_BASE_MAX := 0.62
const TUFT_CLUSTER_SPREAD := 0.44
## In-cell jitter: clumps cross cell borders, killing any grid feel.
const CLUMP_JITTER := 0.45
const TUFT_CELL_SCALE_MIN := 0.9
const TUFT_CELL_SCALE_MAX := 1.1
## Brief 0.4 s bright wash on a freshly cut cell before the stripe tone lands.
const FRESH_FLASH_TIME := 0.4
const WIND_AMPLITUDE := 0.06
const WIND_SPEED := 2.0
## Cut tuft topples forward this far, over MOW_ANIM_TIME, then hides.
const MOW_ANIM_TIME := 0.1
const MOW_ANIM_PITCH := -1.35                 # ~77 degrees
const MOW_ANIM_END_SCALE := 0.25

# ---------------------------------------------------------------- push mower (§6)
const PUSH_SPEED := 3.0
const PUSH_DECK_RADIUS := 0.7
const PUSH_MAX_TURN := 1.7                    # rad/s
const PUSH_BODY_RADIUS := 0.55
const PUSH_PAINT_METALLIC := 0.65
const PUSH_PAINT_ROUGHNESS := 0.28
const IDLE_SHAKE := Vector2(0.004, 0.007)
const IDLE_SHAKE_PERIOD := 0.045

# ---------------------------------------------------------------- mower types (§6)
const MOWER_PUSH := 0
const MOWER_TRACTOR := 1
const MOWER_ROBOT := 2

## §6 table, verbatim. `reverse` is the reverse-gear speed factor (0 = none).
## "label" is a TRANSLATION KEY (G7.1), resolved with tr() at display time.
const MOWER_TYPES: Array[Dictionary] = [
	{
		"id": "push", "emoji": "🔴", "label": "MOWER_PUSH",
		"speed": 3.0, "deck": 0.75, "max_turn": 2.6, "body": 0.55, "reverse": 0.45,
		# G6.12: §7's 1.7 rad/s + 0.45 drag turned like a bus. 2.6 and 0.26
		# let it pivot in about a cell and a half.
		"steer_gain": 5.0, "turn_drag": 0.26,
	},
	{
		"id": "tractor", "emoji": "🚜", "label": "MOWER_TRACTOR",
		"speed": 4.8, "deck": 1.1, "max_turn": 1.5, "body": 0.85, "reverse": 0.5,
		# G6.7: at 4.8 u/s the §7 0.45 drag gave a ~5.8 unit turning radius —
		# wider than a third of the lawn. 0.28 keeps it heavy but steerable.
		"steer_gain": 5.0, "turn_drag": 0.28,
	},
	{
		"id": "robot", "emoji": "🤖", "label": "MOWER_ROBOT",
		"speed": 3.2, "deck": 0.75, "max_turn": 2.6, "body": 0.45, "reverse": 0.45,
		# G6.7: the robot chases waypoints, so it needs to snap onto a heading
		# quickly; its own 2.6 rad/s ceiling still bounds the rate.
		"steer_gain": 7.0, "turn_drag": 0.30,
	},
	{
		# G6 Blade: yaw-free, follows the finger. max_turn is a dummy (never
		# steers) kept non-zero so speed/turn ratios stay divide-safe.
		"id": "blade", "emoji": "⚙️", "label": "MOWER_BLADE",
		"speed": 5.0, "deck": 0.95, "max_turn": 1.0, "body": 0.40, "reverse": 0.0,
		# Yaw-free: it never steers, so these are inert.
		"steer_gain": 0.0, "turn_drag": 0.0,
	},
]

## Chase camera per type: back, height, lookAhead (§10 presets).
const MOWER_CAMERA: Array[Vector3] = [
	Vector3(5.0, 4.2, 2.2),   # push  -> mid
	Vector3(5.0, 4.2, 2.2),   # tractor -> mid, lookAhead grows with speed
	Vector3(6.0, 5.0, 2.4),   # robot -> near the far preset, spectator view
	Vector3(6.0, 4.6, 1.2),   # blade -> wide finger-roaming view, low lookAhead
]
## Tractor only: lookAhead += this * speedFraction so the road shows up at speed.
const TRACTOR_LOOKAHEAD_GAIN := 0.6

## Engine mix per type: idle gain, moving gain, idle pitch, moving pitch, turn boost.
## Push and robot are §14 verbatim. For the tractor §14 gives no profile; the
## sprint brief says "pitch slightly lower, 0.9 base, fuller feel" — read here as
## a range shifted below push's, with 0.9 as the ceiling. One-line change if the
## intent was 0.9 as the floor instead.
const ENGINE_PROFILES: Array[Dictionary] = [
	{ "idle_gain": 0.28, "move_gain": 0.45, "idle_pitch": 0.82, "move_pitch": 1.00, "turn": 0.12 },
	{ "idle_gain": 0.28, "move_gain": 0.45, "idle_pitch": 0.78, "move_pitch": 0.90, "turn": 0.12 },
	{ "idle_gain": 0.08, "move_gain": 0.13, "idle_pitch": 1.90, "move_pitch": 1.90, "turn": 0.10 },
	{ "idle_gain": 0.20, "move_gain": 0.30, "idle_pitch": 2.60, "move_pitch": 2.60, "turn": 0.00 },
]

# ---------------------------------------------------------------- units
## The spec measures touch distances in SwiftUI points on a 390 pt wide screen;
## the viewport is 1170 px wide, so one point is three pixels.
const POINT_SCALE := 3.0

# ---------------------------------------------------------------- tractor joystick (§7)
const JOYSTICK_BASE_RADIUS_PT := 55.0
const JOYSTICK_KNOB_RADIUS_PT := 24.0
const JOYSTICK_DEADZONE := 0.25
## NOT in §7 — spring return duration for the knob.
const JOYSTICK_RETURN_TIME := 0.18

# ---------------------------------------------------------------- robot (§7)
## G6.7: 0.35 was tight enough that the robot orbited its target; 0.5 lets it
## pass through cleanly at 2.1 u/s.
const ROBOT_ARRIVE_DISTANCE := 0.5
const ROBOT_NUDGE_DISTANCE := 3.5
const ROBOT_SWIPE_THRESHOLD_PT := 60.0
## Detour search range when a serpentine cell is blocked: +/-1..4 rows.
const ROBOT_DETOUR_RANGE := 4
const ROBOT_LED_COLOR := Color(0.2, 0.85, 0.9)
const ROBOT_LED_PERIOD := 0.9

# ---------------------------------------------------------------- tractor model (§6)
const TRACTOR_BODY_COLOR := Color(0.22, 0.45, 0.16)
const TRACTOR_ACCENT_COLOR := Color(0.95, 0.78, 0.15)
## G12.9: the tractor gets a bed behind the seat, so the haul rides IN the
## machine instead of on a driver who is sitting down, and a pair of spinning
## cutter discs up front where the deck actually meets the grass.
const TRACTOR_BED_SIZE := Vector3(0.80, 0.06, 0.62)
const TRACTOR_BED_POS := Vector3(0.0, 0.60, 0.95)
const TRACTOR_BED_WALL := 0.16
const TRACTOR_DISC_RADIUS := 0.46
## In FRONT of the existing cutting deck (which spans z -1.25..-0.35 at y 0.11),
## not inside it: the first pass buried both discs in the deck box.
const TRACTOR_DISC_OFFSET := Vector3(0.54, 0.20, -1.50)
const TRACTOR_DISC_SPIN_DEG := 900.0
## Saw teeth around the rim. They are what reads as "this cuts" at phone size —
## a plain plate just looks like a wheel (G12.10).
const TRACTOR_DISC_TEETH := 14
const TRACTOR_DISC_TOOTH_SIZE := Vector3(0.09, 0.022, 0.13)

# ---------------------------------------------------------------- movement (§7)
const ACCEL_TIME := 0.4
const DECEL_TIME := 0.55
const STEER_SMOOTHING := 9.0
const STEER_SPEED_RADIUS_FACTOR := 0.45
const STEER_ERROR_GAIN := 5.0                 # shortestAngle * 5 -> desiredOmega
# ---------------------------------------------------------------- G9 cellar (B8)
## The cellar garden is the one chapter that is INDOORS. It reuses the existing
## light rig rather than adding one: the sun is dimmed and cooled to read as a
## single shaft from above, ambient drops, and a dark ring closes the edges in.
const CELLAR_SUN_ENERGY := 0.55
const CELLAR_SUN_COLOR := Color(0.92, 0.95, 0.80)
const CELLAR_SUN_EULER := Vector3(-1.35, -0.15, 0.0)
const CELLAR_AMBIENT_ENERGY := 0.16
const CELLAR_AMBIENT_COLOR := Color(0.20, 0.30, 0.24)
## How far past the lawn edge the darkness closes in, and how black it gets.
const CELLAR_VIGNETTE_MARGIN := 5.0
const CELLAR_VIGNETTE_ALPHA := 0.92

# ---------------------------------------------------------------- G10 workshop
## Unlock prices, keyed by mower id. Push is the starter.
const UNLOCK_COSTS := { "push": 0, "robot": 300, "tractor": 800, "blade": 1500 }
## One three-tier upgrade line per mower; cost per tier, escalating.
const UPGRADE_COSTS := {
	"push": [120, 280, 550],
	"robot": [150, 340, 650],
	"tractor": [220, 480, 900],
	"blade": [260, 560, 1050],
}
## Per-tier effect: speed multiplier bonus for the drivers, disk growth for the
## blade (BLADE_SCALE +0.15/tier feeds mesh, cut radius and collision at once).
const UPGRADE_SPEED_BONUS := { "push": 0.10, "tractor": 0.10, "robot": 0.12 }
const UPGRADE_BLADE_SCALE_STEP := 0.15
const UPGRADE_MAX_TIER := 3
## Every mower selectable regardless of unlocks — for tests and dev runs.
const DEV_UNLOCK_ALL := false

# ---------------------------------------------------------------- G12.6 finds
## The mark a find leaves behind: a ring, a beam, and the icon at its foot. It
## flares, then settles to a faint shaft for the rest of the chapter, so a mown
## lawn becomes a map of the player's own search.
const FIND_MARK_COLOR := Color(0.45, 1.0, 0.55)
const FIND_MARK_RADIUS := 0.55
const FIND_MARK_BEAM_HEIGHT := 5.0
const FIND_MARK_FLARE_ALPHA := 0.80
const FIND_MARK_IDLE_ALPHA := 0.18
## Short camera glance at the find. OFF since G12.8: it ran after the evidence
## card closed, so the camera lurched to a spot the player had stopped thinking
## about 3.6 s earlier. The permanent light beam left on the ground already does
## the spatial-memory job the pan was there for.
const FIND_PAN_ENABLED := false
const FIND_PAN_TIME := 0.6
## Extra salvage points granted by a completed restoration project.
const RESTORE_SCRAP_BONUS := 1
## Tier 2 (buildings) stays locked until this many tier-1 repairs are done, so
## the spend curve steps instead of presenting a wall of four-figure prices.
const TIER2_REQUIRES_TIER1 := 2
## Debug only: grants money from the pause menu for balance testing. Ships false.
const DEV_GRANT_SCRAP := true
## Debug only: the wallet a fresh save starts with, so systems downstream of the
## economy can be exercised without grinding to them. Ships 0.
const DEV_STARTING_SCRAP := 50000
const DEV_GRANT_AMOUNT := 2000

## Payout multiplier from completed restoration projects. Routed through here so
## ScrapField (pure math, unit tested) never has to know about the town.
static func restore_payout_bonus() -> float:
	return RestoreBoard.payout_bonus()

# ---------------------------------------------------------------- G9.2 assists
## The last-5% finder (PowerWash lesson): past this completion ratio the
## remaining uncut cells get a soft pulsing marker, because hunting the final
## few patches by eye is the known frustration of every completion game.
const HINT_RATIO := 0.90
## Never mark more than this many cells; above it the field is still obvious.
const HINT_MAX_CELLS := 40
const HINT_COLOR := Color(1.0, 0.92, 0.55, 0.55)
const HINT_PULSE_HZ := 1.2
## First-run control hint: shown once until the player performs a real drag.
const HINT_DRIVE_KEY := "hint_drive_done"

# ---------------------------------------------------------------- G9 economy
## Scrap (the currency; nowhere to spend it until G10's Workshop).
## Per-pickup value range, so a run's ground haul varies a little.
## Town-theme music level; the mix keeps it under the ambience.
const THEME_GAIN := 0.30
## G12.8 recalibration. The measured problem: all eight chapters at 100% paid
## 1 548 against a workshop of 8 160 and a town of 6 250, so a player who bought
## the Robot and the Tractor could not reach the 1 200 station across two whole
## cases. Play confirmed it — "we earn money far too slowly".
##
## Earnings are roughly tripled, split across the three levers so no single one
## carries it: more per pickup, more pickups per yard (see levels.json), and a
## larger completion bonus pool.
const SCRAP_PICKUP_MIN := 9
const SCRAP_PICKUP_MAX := 16
## Share of a chapter's payout that comes off the ground vs the completion bonus.
## The ground share is deliberately the smaller one: picking scrap up should feel
## like a bonus for looking around, not the main job.
## The bonus pool is derived from the expected ground haul, so raising the
## pickup values lifts the completion bonus with them. The split itself is
## unchanged: picking things up stays the smaller half.
const SCRAP_GROUND_SHARE := 0.30
const SCRAP_BONUS_SHARE := 0.70
## Completion bonus curve. Leaving early with the evidence still pays most of it,
## because the early exit must not read as a punishment: the bonus scales from
## SCRAP_BONUS_FLOOR at 0% mown to 1.0 at 100%.
const SCRAP_BONUS_FLOOR := 0.55
## Extra on top for a full mow, shown as its own line so the reward is legible.
const SCRAP_THOROUGH_BONUS := 0.15
## Money bundle prop: the genre-classic green cash stack, VISIBLE above the
## grass before it is collected — hidden pickups read as luck, visible ones as
## goals to steer toward.
const MONEY_BILL := Color(0.07, 0.45, 0.16)
const MONEY_BILL_TOP := Color(0.16, 0.62, 0.26)
const MONEY_BAND := Color(0.96, 0.86, 0.42)
const MONEY_SIZE := Vector3(0.56, 0.20, 0.38)
## Soft self-glow so the stack pops against sunlit grass, ad-game style.
const MONEY_GLOW := 0.35
const MONEY_HOVER := 0.55
const MONEY_BOB := 0.08
const MONEY_SPIN := 1.4
## G10.1 carry stack: where the haul rides. On foot it sits between the
## driver's shoulders; on the tractor and the blade there is no walking back, so
## it rides the machine's rear deck.
const CARRY_BACK_OFFSET := Vector3(0.0, 0.62, 0.16)
const CARRY_DECK_OFFSET := Vector3(0.0, 0.62, 0.55)
## Contact pickup radius, on top of the deck: driving near an object takes it.
const PICKUP_REACH := 0.55
## Scrap pickup visuals.
const SCRAP_ICON := "💵"
const SCRAP_RISE := 1.1
const SCRAP_FLY_TIME := 0.55
## Minimum cells between two pickups, so they are spread rather than clustered.
const SCRAP_MIN_SEPARATION := 3
const SCRAP_PLACEMENT_TRIES := 400

# ---------------------------------------------------------------- G8 portraits
## The character art is 9:16 full-figure illustration, so the dialogue box shows
## it LARGE (a thumbnail wastes it) and the town list uses a square face crop
## generated from the same file by tools/crop_faces.gd.
##
## Face centre and crop size as FRACTIONS of the source image, per character.
## Fractions, not pixels, because the sources are not all the same resolution.
## Tuned by looking at the generated sheet, not guessed once.
const PORTRAIT_FACES: Dictionary = {
	"marshal":  { "x": 0.37, "y": 0.27, "size": 0.54 },
	"sarah":    { "x": 0.42, "y": 0.28, "size": 0.54 },
	"gus":      { "x": 0.47, "y": 0.30, "size": 0.58 },
	"cole":     { "x": 0.47, "y": 0.32, "size": 0.56 },
	"ellie":    { "x": 0.48, "y": 0.29, "size": 0.60 },
	"stranger": { "x": 0.62, "y": 0.34, "size": 0.32 },
}
## Square face thumbnail size in pixels.
const PORTRAIT_FACE_PX := 320
## Dialogue portrait card, in viewport pixels (9:16).
const DIALOGUE_PORTRAIT_SIZE := Vector2(430, 764)


# ---------------------------------------------------------------- G7 story
## Warm dark ground behind an intro card whose illustration is missing, and the
## letterbox behind one that does not match the screen aspect.
## Ken Burns end scale for the intro cards; tools/shrink_art.gd sizes the
## source art from it, so the two can never drift apart.
const INTRO_KEN_BURNS_TO := 1.06
const INTRO_GROUND := Color(0.13, 0.10, 0.08)
## Briefing box and case-note panel ground.
const CASE_PANEL := Color(0.09, 0.09, 0.08, 0.94)
## Case title / objective text.
const CASE_ACCENT := Color(0.95, 0.82, 0.45)
## The town-page MISSING poster for Ellie (G12.10).
const POSTER_BG := Color(0.13, 0.12, 0.10)
const CASE_MUTED := Color(0.72, 0.70, 0.64)
## Chapters that must be finished before Ellie stops being a poster and becomes
## someone you can talk to. Matches her requires_done in data/story.json.
const ELLIE_FOUND_AFTER := 8
## Seconds the "LAST MOWED" opening title holds before it fades.
const OPENING_TITLE_HOLD := 2.6
const OPENING_TITLE_FADE := 1.0
## Seconds the case line stays after the search starts before it fades out.
const CASE_LINE_HOLD := 6.0
## Set true to watch the opening again on the next launch regardless of the
## saved flag; the STORY button in the HUD does the same thing at runtime.
const STORY_ALWAYS_REPLAY_INTRO := false


## §7's threshold is 8 POINTS, not pixels; multiply by POINT_SCALE.
const DRAG_THRESHOLD_PT := 8.0
## G9.2 heading steering: past this error the mower reverses instead of turning.
const PAD_REVERSE_ANGLE := 2.35
## Minimum throttle while still turning toward the finger.
const PAD_TURN_THROTTLE_FLOOR := 0.30
## Drag distance (in points) for full stick deflection on the shared drag pad.
const DRAG_FULL_PT := 34.0
const WALL_INSET_FACTOR := 0.6                # inset = bodyRadius * 0.6

# ---------------------------------------------------------------- camera (§10)
const CAMERA_FOV := 55.0
## mid preset: back, height, lookAhead
const CAMERA_BACK := 5.0
const CAMERA_HEIGHT := 4.2
const CAMERA_LOOK_AHEAD := 2.2
const CAMERA_LOOK_UP := 0.3
const CAMERA_FOCUS_LERP := 4.0
const CAMERA_YAW_LERP := 2.6
const CAMERA_WIN_POS := Vector3(0.0, 30.0, 4.0)
const CAMERA_WIN_LERP := 1.8

# ---------------------------------------------------------------- light (§13)
const SUN_EULER := Vector3(-0.9, -0.6, 0.0)
const SUN_COLOR := Color(1.0, 0.96, 0.88)
## SceneKit intensity 1000 lumens maps to Godot energy 1.0; ambient 420 -> 0.42.
const SUN_ENERGY := 1.0
const AMBIENT_COLOR := Color(0.55, 0.62, 0.70)
const AMBIENT_ENERGY := 0.42
const SKY_TOP := Color(0.45, 0.70, 0.95)
const SKY_HORIZON := Color(0.80, 0.90, 0.98)
const FOG_NEAR := 26.0
const FOG_FAR := 70.0
const FOG_COLOR := Color(0.80, 0.88, 0.95)
const FOG_CURVE := 1.5
## SSAO is never enabled: it does not work in the Mobile renderer. Fake AO only.
const USE_SSAO := false
const FAKE_AO_MOWER_SIZE := 1.5

# ---------------------------------------------------------------- audio (§14)
## Linear gains from the spec, converted to dB where Godot needs dB.
const ENGINE_GAIN_IDLE := 0.28
const ENGINE_GAIN_MOVING := 0.45
const ENGINE_PITCH_IDLE := 0.82
const ENGINE_PITCH_MOVING := 1.0
const ENGINE_PITCH_TURN_BOOST := 0.12
const ENGINE_MIX_LERP := 4.0
const CUT_GAIN := 0.6
const CUT_PITCH_VARIANTS: Array[float] = [1.0, 1.15, 0.88]
const CUT_VOICES := 3
const AMBIENT_GAIN := 0.18

# ---------------------------------------------------------------- haptics (§15)
const HAPTIC_ENABLED := true
## iOS drives these through CoreHaptics, which does not do anything useful with
## a pulse this short; 10/25 ms came from the desktop-era brief. Raised to
## durations the phone can actually render (G13.3).
const HAPTIC_LIGHT_MS := 20        # cell mown, mower commands
const HAPTIC_MEDIUM_MS := 40       # secret uncovered
## Secret collected and 100% complete: two medium pulses.
const HAPTIC_SUCCESS_GAP := 0.08

# ---------------------------------------------------------------- G6 quality switches
## Every G6 visual feature has a switch, for FPS calibration on the phone.
## G12.5: nothing drives here. This neighbourhood emptied out during the
## outbreak — a car cruising past told the player the world was fine, which is
## the opposite of what every other surface in the scene says.
const TRAFFIC_ENABLED := false
const WATER_FANCY_ENABLED := true        # two-layer waves, fresnel, glints
const SKY_HIGH_CLOUDS_ENABLED := true    # thin static cirrus layer at y~40
const GLOW_ENABLED := true               # subtle bloom on bright spots only
const SHADOW_MAP_2048 := true            # false drops back to 1024
const MICRO_MOTION_ENABLED := true       # canopy sway, mailbox flag, single bird
const BLADE_FX_ENABLED := true           # trail, blur ring, sparks

# ---------------------------------------------------------------- G6 traffic
const TRAFFIC_POOL_SIZE := 5
const TRAFFIC_INTERVAL_MIN := 8.0
const TRAFFIC_INTERVAL_MAX := 20.0
const TRAFFIC_SPEED_MIN := 6.0
const TRAFFIC_SPEED_MAX := 8.0
const TRAFFIC_SPAWN_X := 34.0            # off-scene on both sides
## Right-hand traffic: heading east uses the south lane, west the north lane.
## Lanes ride the road, which rides the grid (G9.1).
static func traffic_lane_east_z() -> float:
	return road_z() + 1.6
static func traffic_lane_west_z() -> float:
	return road_z() - 1.6
const TRAFFIC_DRIVEWAY_MIN := 90.0       # rare pull-in event interval
const TRAFFIC_DRIVEWAY_MAX := 120.0
const TRAFFIC_DRIVEWAY_WAIT := 10.0
## Vehicle variants: body style + colour options, assigned at random.
const TRAFFIC_COLORS: Array = [
	[Color(0.25, 0.42, 0.62), Color(0.72, 0.73, 0.75), Color(0.20, 0.35, 0.22)],  # sedan
	[Color(0.62, 0.28, 0.22), Color(0.30, 0.30, 0.32), Color(0.75, 0.55, 0.20)],  # pickup
	[Color(0.24, 0.26, 0.30), Color(0.55, 0.12, 0.14), Color(0.82, 0.80, 0.76)],  # suv
	[Color(0.86, 0.86, 0.84), Color(0.32, 0.44, 0.58), Color(0.62, 0.58, 0.30)],  # van
]

# ---------------------------------------------------------------- G6 water
const WATER_WAVE2_SPEED := 4.2
const WATER_WAVE2_FREQ := 7.0
const WATER_WAVE2_AMP := 0.008
const WATER_FRESNEL_POWER := 3.0
const WATER_ALPHA_FACING := 0.55         # transparent looking straight down
const WATER_ALPHA_GRAZING := 0.92        # near-opaque at grazing angles

# ---------------------------------------------------------------- G6 sky/light
const SHADOW_BLUR := 3.0
const GLOW_INTENSITY := 0.35
const GLOW_HDR_THRESHOLD := 1.25
const HIGH_CLOUD_COUNT := 3
const HIGH_CLOUD_Y := 40.0

# ---------------------------------------------------------------- G6 micro-motion
const CANOPY_SWAY_AMP := 0.02
const CANOPY_SWAY_PERIOD := 3.5
const BIRD_INTERVAL_MIN := 20.0
const BIRD_INTERVAL_MAX := 40.0
const FLAG_INTERVAL_MIN := 60.0
const FLAG_INTERVAL_MAX := 90.0

# ---------------------------------------------------------------- G6 blade (4th mower)
const MOWER_BLADE := 3
## G6.8: the follow is PROPORTIONAL — desired speed = distance * gain, capped.
## A small finger move drifts, a big sweep accelerates. The old flat 9 u/s felt
## like a teleport.
const BLADE_MAX_SPEED := 5.0             # u/s ceiling
const BLADE_GLIDE_TIME := 0.35           # coast after the finger lifts
## Spin idles lazily and revs up with motion (G6.8).
const BLADE_SPIN_IDLE_DEG := 70.0
const BLADE_SPIN_FAST_DEG := 1000.0
const BLADE_SPIN_LERP := 3.0             # how quickly the spin rate responds

## Ceremonial chakram proportions (G6.8 reference art).
const BLADE_ARM_REACH := 1.02            # horn tip radius; overall span ~2.0
const BLADE_HUB_OUTER := 0.24
const BLADE_HUB_INNER := 0.13
const BLADE_PLATE_THICK := 0.035
# >1 pushes the horns out and pulls the waist in, so corners read sharp.
const BLADE_PLATE_SHARPEN := 1.62
# <1 pulls each outline point toward its arm axis, narrowing the arms to spikes.
const BLADE_ARM_TAPER := 0.68
# Purple shimmer thrown off the spinning plate.
const BLADE_SHIMMER := Color(0.66, 0.30, 0.95)
const BLADE_GOLD := Color(0.62, 0.44, 0.09)
const BLADE_CREAM := Color(0.78, 0.66, 0.34)
const BLADE_SILVER := Color(0.80, 0.80, 0.76)
const BLADE_GEM := Color(0.42, 0.10, 0.72)
const BLADE_SPARK_COOLDOWN := 0.5
## Uniform grow factor: chakram mesh, deck radius and body radius all scale
## from this one number (future Size upgrades hook in here). 1.0 for now.
## G10: grown by the workshop upgrade (1.0 + tier * UPGRADE_BLADE_SCALE_STEP);
## set from the garage before each chapter. Mesh, cut radius and collision all
## derive from it (G6.6), which is why the upgrade is this one number.
static var BLADE_SCALE := 1.0

# ---------------------------------------------------------------- neighborhood (§2, §12)
## G9 house variants: the SAME house parts in different combinations, so a
## chapter can look like a different property without new geometry. house_none
## builds nothing, which is what the landmark chapters use.
const HOUSE_VARIANTS := {
	"house_v1": { "body": Color(0.78, 0.77, 0.72), "roof": Color(0.42, 0.26, 0.20),
		"porch": true, "chimney": true },
	"house_v2": { "body": Color(0.62, 0.70, 0.68), "roof": Color(0.30, 0.31, 0.34),
		"porch": false, "chimney": true },
	"house_v3": { "body": Color(0.80, 0.72, 0.55), "roof": Color(0.46, 0.34, 0.22),
		"porch": true, "chimney": false },
	"house_v4": { "body": Color(0.55, 0.48, 0.44), "roof": Color(0.24, 0.22, 0.24),
		"porch": false, "chimney": false },
	"house_v5": { "body": Color(0.70, 0.55, 0.50), "roof": Color(0.38, 0.28, 0.26),
		"porch": true, "chimney": true },
	"house_none": {},
}

## Landmark structures that stand where the house would. One low-detail
## composition each, built from the same primitives and textures as the house,
## and each one casts shadow so it anchors to the ground.
const LANDMARK_IDS: Array[String] = [
	"playground", "greenhouse", "water_tower", "mill",
]

const HOUSE_MARGIN_Z := 4.8
static func house_pos_z() -> float:
	return -(HALF_Z + HOUSE_MARGIN_Z)
const HOUSE_BODY := Vector3(13.0, 3.2, 4.2)
const HOUSE_ROOF := Vector3(14.2, 2.4, 5.4)
## G9.1: everything around the lawn is an OFFSET from the lawn edge, not a world
## coordinate, so a small yard's fence hugs the small yard. The offsets are the
## original medium-yard tuning (side 9.6 = 8 + 1.6, etc.) expressed as deltas.
const FENCE_SIDE_MARGIN := 1.6
const FENCE_SOUTH_MARGIN := 1.6
const FENCE_NORTH_MARGIN := 1.0
static func fence_side_x() -> float:
	return HALF_X + FENCE_SIDE_MARGIN
static func fence_south_z() -> float:
	return HALF_Z + FENCE_SOUTH_MARGIN
static func fence_north_z() -> float:
	return -(HALF_Z + FENCE_NORTH_MARGIN)
const FENCE_POST := Vector3(0.14, 0.85, 0.06)
const FENCE_SPACING := 0.62
const FENCE_HEIGHT_JITTER := 0.05
const FENCE_ANGLE_JITTER := 0.025
const SIDEWALK_DEPTH := 2.2
const SIDEWALK_MARGIN := 3.2
static func sidewalk_z() -> float:
	return HALF_Z + SIDEWALK_MARGIN
const ROAD_MARGIN := 7.4
static func road_z() -> float:
	return HALF_Z + ROAD_MARGIN
const ROAD_DEPTH := 6.5
const ROAD_WIDTH := 60.0
const ROAD_DASH := Vector2(1.6, 0.14)          # size; 4 units apart
const ROAD_DASH_GAP := 4.0
const NEIGHBOR_MARGIN := 16.4
static func neighbor_z() -> float:
	return HALF_Z + NEIGHBOR_MARGIN
## Derelict houses ringing EVERY yard (G12.5): a lawn floating in empty dirt
## read as a test level, not a street. Positions are offsets from the lawn edge
## so they follow the grid like the fence and the road do.
const NEIGHBOR_X: Array[float] = [-11.0, 0.5, 11.5]
## Side-street houses: how far past the fence they stand, and their spacing
## along the yard's depth.
## Just past the fence. Measured, not guessed: in portrait the camera shows
## roughly five units either side of the mower, so at the lawn edge the player
## can see to about one house-depth beyond the fence and no further. Anything
## further out is a house nobody ever sees.
const SIDE_HOUSE_MARGIN := 2.6
const SIDE_HOUSE_SPACING := 11.0
## Muted, weathered palette — these are survivors of a bad decade, not a
## postcard row.
const DERELICT_BODIES: Array[Color] = [
	Color(0.62, 0.60, 0.53), Color(0.52, 0.56, 0.52), Color(0.66, 0.58, 0.50),
	Color(0.48, 0.50, 0.54), Color(0.60, 0.52, 0.46),
]
## Roofs are the ONLY part of a side house the top-down camera really sees, so
## they carry the read: dark ones turned into featureless slabs at the frame
## edge. These are weathered but light enough to show their pitch.
const DERELICT_ROOFS: Array[Color] = [
	Color(0.55, 0.44, 0.36), Color(0.48, 0.46, 0.44), Color(0.58, 0.46, 0.38),
]
## §12 tree placements: (x, z) and scale.
## Trees as edge FRACTIONS (x: -1..1 of fence_side_x, y: -1..1 of half depth)
## plus scale, so they stay just outside whichever fence the chapter has.
const TREES: Array[Vector3] = [
	Vector3(-0.97, -0.90, 1.0),
	Vector3(0.95, -0.17, 0.85),
	Vector3(-0.96, 0.67, 0.9),
]
static func tree_pos(spec: Vector3) -> Vector3:
	return Vector3(spec.x * fence_side_x(), 0.0, spec.y * HALF_Z)
const TREE_LEAF_DARK := Color(0.20, 0.42, 0.16)
const TREE_LEAF_LIGHT := Color(0.33, 0.57, 0.25)
const CAR_SEDAN_COLOR := Color(0.25, 0.42, 0.62)
const CAR_PICKUP_COLOR := Color(0.62, 0.28, 0.22)
const CAR_PAINT_METALLIC := 0.55
const CAR_PAINT_ROUGHNESS := 0.3

# ---------------------------------------------------------------- pool visuals (§11)
const POOL_WATER_COLOR := Color(0.30, 0.75, 0.82, 0.72)
const POOL_WATER_ROUGHNESS := 0.12
const POOL_BORDER_COLOR := Color(0.90, 0.88, 0.82)
const POOL_BORDER_SIZE := Vector2(0.35, 0.12)  # thickness, height
## Water wave, verbatim: y += sin(TIME*1.8 + x*3.0 + z*2.2) * 0.02
const POOL_WAVE_SPEED := 1.8
const POOL_WAVE_AMP := 0.02

# ---------------------------------------------------------------- flowers (§12)
const FLOWER_SWAY_AMP := 0.06
const FLOWER_SWAY_PERIOD := 1.9

# ---------------------------------------------------------------- clouds (§12)
const CLOUD_COUNT := 4
const CLOUD_SIZE_MIN := 13.0
const CLOUD_SIZE_MAX := 20.0
const CLOUD_Y_MIN := 24.0
const CLOUD_Y_MAX := 30.0
const CLOUD_DRIFT := 2.5
const CLOUD_PERIOD := 30.0

# ---------------------------------------------------------------- character (§8)
## No skeleton: joints are separate Node3D pivots, animation is sine/lerp.
## Height ~1.55, head/height ~1/7. Root pivot sits at the waist.
const CHAR_SHIRT := Color(0.92, 0.50, 0.18)
const CHAR_SKIN := Color(0.87, 0.67, 0.52)
const CHAR_JEANS := Color(0.28, 0.36, 0.52)
## "Haki" hat and the dark brow band have no numeric colours in §8.
const CHAR_HAT := Color(0.55, 0.52, 0.34)
const CHAR_BAND := Color(0.13, 0.11, 0.09)
const CHAR_BOOT := Color(0.20, 0.15, 0.11)

const CHAR_TORSO_SIZE := Vector3(0.34, 0.44, 0.20)
const CHAR_HEAD_RADIUS := 0.115
const CHAR_BAND_SIZE := Vector2(0.16, 0.035)
const CHAR_HAT_BRIM_RADIUS := 0.175
const CHAR_HAT_TOP_RADIUS := 0.10
const CHAR_SHOULDER := Vector2(0.21, 0.42)     # +/-x, y — on the torso
const CHAR_UPPER_ARM := 0.24
const CHAR_LOWER_ARM := 0.22
const CHAR_HIP_X := 0.09
const CHAR_UPPER_LEG := 0.36
const CHAR_LOWER_LEG := 0.34
const CHAR_BOOT_SIZE := Vector3(0.11, 0.09, 0.22)
const CHAR_AO_SIZE := 0.7                      # NOT in §8 — small contact shadow

# Push mode (§8): walks behind the mower.
const CHAR_PUSH_SEAT := Vector3(0.0, 0.79, 1.45)
const CHAR_PUSH_LEAN := 0.12                   # torso forward lean
const CHAR_PUSH_ARM_X := 0.85                  # arms forward-down to the handle
const CHAR_PUSH_ARM_INWARD := 0.12             # "hafif içe" — no number in §8
const WALK_MIN_SPEED := 0.06
const WALK_PHASE_BASE := 5.0
const WALK_PHASE_GAIN := 3.5
const WALK_LEG_SWING := 0.48
const WALK_KNEE_BEND := 0.55
const WALK_TORSO_ROLL := 0.045
const WALK_BOB := 0.022
const IDLE_RECOVER_RATE := 8.0
const BREATH_FREQ := 2.2
const BREATH_AMP := 0.008

# Tractor mode (§8): sits on the seat.
const CHAR_TRACTOR_SEAT := Vector3(0.0, 0.80, 0.42)
const CHAR_SIT_THIGH := 1.35                   # thighs horizontal
const CHAR_SIT_SHIN := 1.15                    # shins down
const CHAR_WHEEL_ARM_X := 1.35                 # arms to the wheel
const CHAR_WHEEL_ARM_INWARD := 0.28
const STEER_TORSO_YAW := 0.18                  # torso yaw target = -steer * this
const STEER_TORSO_LERP := 6.0
const STEER_HEAD_FACTOR := 0.6
const STEER_ARM_Z_BASE := 0.10
const STEER_ARM_Z_GAIN := 0.12
const ENGINE_VIB_FREQ := 40.0
const ENGINE_VIB_AMP := 0.004

# Robot mode: the character sits on the porch watching the lawn (moved from the
# lawn edge when the G5 house landed). x avoids the door path and the posts.
const CHAR_BENCH_POS := Vector3(1.5, 0.0, -13.9)
const CHAR_BENCH_YAW := PI                     # spec yaw: facing south, at the lawn
## Waist height: porch platform (0.28) plus a seated shin (0.42).
const CHAR_BENCH_WAIST_Y := 0.70

# ---------------------------------------------------------------- clippings (§9)
## Sprayed from the mower's RIGHT side: right = (cos yaw, 0, sin yaw).
const CLIP_SIDE_OFFSET := 0.45
const CLIP_DIR_UP := 0.8
const CLIP_SPREAD_DEG := 55.0
const CLIP_SPEED := 2.4
const CLIP_SPEED_SPREAD := 1.2
const CLIP_GRAVITY := -9.8
const CLIP_LIFETIME := 0.6
const CLIP_LIFETIME_SPREAD := 0.25
const CLIP_SIZE := 0.045
const CLIP_SPIN_DEG := 300.0
const CLIP_SPIN_SPREAD_DEG := 180.0
const CLIP_BIRTH_RATE := 90.0
const CLIP_EMIT_TIME := 0.06
## Never spray more often than this, however fast cells fall.
const CLIP_MIN_INTERVAL := 0.12

# ---------------------------------------------------------------- secret glow (§9)
const GLOW_RADIUS := 0.15
const GLOW_COLOR := Color(1.0, 0.82, 0.25)
const GLOW_FLOAT_AMPLITUDE := 0.16
const GLOW_FLOAT_PERIOD := 0.8
const GLOW_PULSE_MIN := 1.0
const GLOW_PULSE_MAX := 1.3
const GLOW_PULSE_PERIOD := 0.5
const SPARK_BIRTH_RATE := 10.0
const SPARK_SIZE := 0.035
## NOT in §9 — needed to place and tap the orb. Tune freely.
const GLOW_HOVER_HEIGHT := 0.38
const GLOW_SPIN_RATE := 1.3
const GLOW_TAP_RADIUS := 0.65

# ---------------------------------------------------------------- dig burst (§9)
const DIG_BIRTH_RATE := 160.0
const DIG_EMIT_TIME := 0.15
const DIG_LIFETIME := 0.5
const DIG_COLOR := Color(0.52, 0.38, 0.26)

# ---------------------------------------------------------------- secret item (§9)
const ITEM_RISE_FROM := -0.15
const ITEM_RISE_TO := 0.7
const ITEM_RISE_TIME := 0.7
const ITEM_HOLD_TIME := 1.4
# G7.1: evidence 0 is Ellie's toy, not the old rusty key. The key constants stay
# so nothing that still references them breaks, but the mesh is no longer built.
const KEY_COLOR := Color(0.62, 0.48, 0.22)
const KEY_METALLIC := 0.8
const KEY_TORUS_RADIUS := 0.11
## Worn plush, a shade duller than the toy's ribbon so it reads as loved.
const TOY_FUR := Color(0.60, 0.42, 0.26)
const TOY_MUZZLE := Color(0.80, 0.66, 0.48)
const TOY_RIBBON := Color(0.72, 0.22, 0.28)
const TOY_EYE := Color(0.10, 0.08, 0.07)
## Body radius; every other part is sized from it, so the toy scales as a whole.
const TOY_BODY := 0.135
const RADIO_BOX := Vector3(0.44, 0.28, 0.14)
## NOT in §9 — "drifts up and fades" has no stated duration.
const ITEM_FADE_TIME := 0.9
const ITEM_FADE_RISE := 0.9
const ITEM_SPIN_RATE := 1.6

# ---------------------------------------------------------------- secret UI (§16)
const SECRET_TOTAL := SECRET_COUNT
## G10.2: a found piece of evidence is a story beat, not a toast. Long enough
## to read the name AND the line without hurrying.
const CARD_SHOW_TIME := 3.6
## NOT in §16 — the flight to the counter has no stated duration.
const CARD_FLY_TIME := 0.55

# ---------------------------------------------------------------- overlay (§16)
const VIGNETTE_STRENGTH := 0.16
const SUN_OVERLAY_WARM := 0.10
const SUN_OVERLAY_COOL := 0.08

# ---------------------------------------------------------------- secrets (§3)
const SECRET_COUNT := 2
const SECRET_EDGE_MARGIN := 2
const SECRET_MIN_SEPARATION := 8
const SECRET_PLACEMENT_TRIES := 300


static func linear_to_db(gain: float) -> float:
	return linear_to_db_safe(gain)


static func linear_to_db_safe(gain: float) -> float:
	if gain <= 0.0001:
		return -80.0
	return 20.0 * (log(gain) / log(10.0))


## How far out the distant hills and rooftops ring sits, in the yard. Well
## beyond the fence and the road, so nothing there is ever approached (G13.1).
const HORIZON_RADIUS := 78.0

# ---------------------------------------------------------------- desktop (G14)
## The game is authored for a 1170-wide portrait screen. On a desktop window the
## viewport stretches sideways (keep_height), which is GOOD for the 3D — the
## neighbouring yards come into view — but the HUD would spread its top bar
## across 4500 px with a hole in the middle. Interface elements are held to this
## width and centred instead.
const UI_MAX_WIDTH := 1170.0
## Windowed size the desktop build opens at.
const DESKTOP_WINDOW := Vector2i(900, 1500)

# ---------------------------------------------------------------- hub diorama (G13)
## The hub's backdrop is either the 2D collage it has always been, or a small
## fixed-camera 3D town. This is a TRIAL: legacy stays wired and working, and
## flipping this one value returns the hub to it.
const HUB_MODE_DIORAMA := "diorama"
const HUB_MODE_LEGACY := "legacy"
static var hub_mode := HUB_MODE_DIORAMA

## The plate the town sits on. Small on purpose — this reads as a model of a
## town, not a place you walk around in.
## Narrow and DEEP, not wide and shallow. The screen is 1170x2532: a 24x16
## plate laid the other way filled the width and left two thirds of the screen
## empty above and below it. Turning it to face the phone is what made the
## model fill the frame.
## Big enough that the frame is FULL: the edges are trees, hedges and fog, not
## bare ground running out (G13.1). Still narrow-and-deep for a portrait screen.
## Grown again for G13.5: ten buildings on the 26x34 plate stood shoulder to
## shoulder and the greenhouse sat inside the barn. Roughly double the area.
const DIORAMA_PLATE := Vector2(36.0, 46.0)
## How far the ground bevels in at the rim, which is what sells "model".
const DIORAMA_BEVEL := 2.4
const DIORAMA_BEVEL_DROP := 1.6
## The hub does not need 60: it is a still scene behind menus.
const DIORAMA_FPS := 30
## Writes draw-call, triangle and frame-rate lines to the console on hub entry.
const PERF_LOG := true

## Framed for a PORTRAIT screen. Godot measures fov vertically by default, and
## at 1170x2532 that leaves a ~20 degree horizontal window — the two side
## buildings sat completely outside it. keep_aspect KEEP_WIDTH makes this a
## HORIZONTAL angle instead, and the tall screen then has depth to spare.
const DIORAMA_CAM_POS := Vector3(0.0, 28.0, 28.5)
const DIORAMA_CAM_LOOK := Vector3(0.0, 1.8, -3.4)
const DIORAMA_CAM_FOV := 48.0
## The hub's cards cover the bottom half of the screen, so the model is pushed
## up into the half that stays visible. This is a frustum shift, not a rotation:
## turning the camera up would have tilted the whole model off its plate.
const DIORAMA_V_OFFSET := -9.6
## The plate's grass. grass_albedo is a greyscale pattern, so this is what makes
## it green (the yard tints it in a shader instead).
const DIORAMA_GRASS_TINT := Color(0.40, 0.58, 0.28)

# ---- the diorama's grass field (G13.1)
## Sparse across the plate, dense where a ruin stands: nature took the town
## back, and a rebuilt plot gets cleared.
const DIORAMA_TUFT_SPACING := 0.78
const DIORAMA_TUFT_JITTER := 0.34
## Radius around a ruined building that grows thick weeds, and how many extra
## clumps go in it.
const DIORAMA_OVERGROWTH_RADIUS := 4.6
const DIORAMA_OVERGROWTH_COUNT := 40
## Kept clear of the paving so the square does not sprout grass.
const DIORAMA_SQUARE_RADIUS := 4.2
## Trees and hedges that close the frame. Radius from centre, count.
const DIORAMA_EDGE_TREES := 24
const DIORAMA_EDGE_BUSHES := 44
## A breath of movement so the scene is not a photograph. Degrees and Hz.
const DIORAMA_SWAY_DEG := 0.55
const DIORAMA_SWAY_HZ := 0.06
## Optional finger pan, clamped hard: this is a diorama, not a camera you fly.
const DIORAMA_PAN_ENABLED := true
const DIORAMA_PAN_DEG := 10.0
const DIORAMA_PAN_PER_PIXEL := 0.02
const DIORAMA_PAN_RETURN := 1.6

## Where each restorable building stands, and which way it faces. Only three
## exist in this slice; the rest of projects.json is not in the scene yet.
## The buildings are authored at roughly 3 m; the plate is much bigger than
## that, so each plot is scaled as one piece rather than every box being
## rewritten.
const DIORAMA_BUILDING_SCALE := 1.55

## All ten restore projects, each with a place on the plate. Every one has a
## ruined form as well as a restored one: a locked project shows its RUIN, not
## an empty lot, so the player can see what the money is for (G13.5).
const DIORAMA_BUILDINGS := {
	"station": {"pos": Vector3(-7.4, 0.0, 5.2), "yaw": 0.34},
	"homes": {"pos": Vector3(7.6, 0.0, 5.8), "yaw": -0.34},
	"watchtower": {"pos": Vector3(2.0, 0.0, -13.2), "yaw": 0.10},
	# The swing hangs from the oak, so its plot IS the oak's spot; its parts are
	# positioned against the limb rather than the ground.
	# scale 1.0, NOT the shared building scale: the swing has to line up with
	# the oak's limb, and the oak is not scaled. At 1.55 the ropes hung in open
	# air beside the tree (G13.5).
	"swing": {"pos": Vector3(-1.2, 0.0, -4.6), "yaw": 0.40, "scale": 1.0},
	"lantern": {"pos": Vector3(4.8, 0.0, -1.0), "yaw": 0.0},
	"greenhouse": {"pos": Vector3(12.4, 0.0, 0.6), "yaw": -0.55},
	"clinic": {"pos": Vector3(-12.6, 0.0, -1.8), "yaw": 0.62},
	"mast": {"pos": Vector3(-10.8, 0.0, -12.4), "yaw": 0.18},
	"farm": {"pos": Vector3(11.2, 0.0, -9.6), "yaw": -0.22},
	"barn": {"pos": Vector3(13.4, 0.0, -15.8), "yaw": -0.40},
}

## Who walks the town, and between which two points. A figure only appears once
## the thing that brings them here is built (G13.5). Positions are plate-space;
## the pair is walked back and forth, not a path-finding route.
const DIORAMA_FIGURES := {
	"sarah": {"needs": "greenhouse", "colour": Color(0.72, 0.42, 0.48),
		"from": Vector3(8.6, 0.0, 3.6), "to": Vector3(11.6, 0.0, 1.4), "speed": 0.55},
	"gus": {"needs": "mast", "colour": Color(0.42, 0.46, 0.56),
		"from": Vector3(-8.4, 0.0, -9.0), "to": Vector3(-10.2, 0.0, -11.4), "speed": 0.45},
	"farmer": {"needs": "farm", "colour": Color(0.56, 0.50, 0.34),
		"from": Vector3(9.6, 0.0, -8.4), "to": Vector3(12.4, 0.0, -10.6), "speed": 0.40},
	"cat": {"needs": "barn", "colour": Color(0.38, 0.34, 0.32),
		"from": Vector3(12.2, 0.0, -14.4), "to": Vector3(14.2, 0.0, -16.4), "speed": 0.65},
}
## Ellie sits on the swing once the case is closed AND the swing is built.
const DIORAMA_ELLIE_NEEDS := "swing"

# ---- reclaimed: mowing -> town (G13.4)
## A band of tall weeds around the town that retreats one step per finished
## chapter. This is the visible answer to "what did all that mowing do?" — and
## it is tied to CHAPTERS, not money, so it measures work rather than spending.
const RECLAIM_STEPS := 8
## How deep the band is at step 0, and at the last step.
const RECLAIM_BAND_START := 9.0
const RECLAIM_BAND_END := 1.6
## Clumps per square unit of band. Dense: this is meant to look like the town
## is being strangled.
const RECLAIM_DENSITY := 0.42
const RECLAIM_CLUMP_SCALE := Vector2(1.15, 1.85)
## The retreat animation played on returning to the hub.
const RECLAIM_FALL_SECONDS := 1.5
## Percentages of a chapter's lawn at which the Marshal says something and a
## faint tint appears near the evidence (G13.4 §3).
const SCENT_AT := [0.30, 0.60]
const SCENT_TINT_CELLS := 3
const SCENT_TOAST_SECONDS := 3.4
## Purists can switch the hints off.
static var hint_moments := true

## How long a restore card has to be held before the camera glances at the plot
## it would build, and how long the glance lasts.
const DIORAMA_PEEK_HOLD := 0.35
const DIORAMA_PEEK_SECONDS := 1.6
## The dead oak in the square. The swing project will hang from it later.
const DIORAMA_TREE_POS := Vector3(-1.2, 0.0, -4.6)

# ---- the restore transition (G13 §3)
## Camera push-in, the collapse, then parts landing one after another.
const RESTORE_ZOOM_IN := 1.0
const RESTORE_ZOOM_OUT := 0.7
const RESTORE_COLLAPSE := 0.55
## The gap between two parts landing. It is a CEILING, not a fixed value: a
## building with many parts (the greenhouse has about thirty) would otherwise
## take five seconds to raise, and the brief's whole transition is meant to be
## three or four (G13.7).
const RESTORE_PART_GAP := 0.15
## However many parts a building has, the raise takes about this long.
const RESTORE_RAISE_SECONDS := 1.7
const RESTORE_PART_FALL := 0.34
## How high a part starts above its resting place.
## Low enough that a falling wall stays inside the frame. At 5.0 the station's
## wall block filled the screen on its way down.
const RESTORE_PART_RISE := 2.8
const RESTORE_SHINE := 0.5
## How close the camera gets to the building it is rebuilding.
## Along the camera's own view line, so this is a true distance from the
## building. Under about 8 the building overflows the frame.
const RESTORE_CAM_DISTANCE := 13.0
