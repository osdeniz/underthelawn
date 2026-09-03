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
	## Harvest fields. Half again the cells of a "large" yard, because a harvest
	## is the paying job and should feel like a day's work rather than another
	## search — and because the crop now runs to the horizon, a small square of
	## it in the middle of all that land read as a sample plot.
	"harvest": Vector2i(26, 38),
	## Two more harvest shapes, so the six fields are six different DAYS rather
	## than one day in six colours (G14.14): a quick strip you can bring in
	## before dark, and a long haul that pays for it.
	"harvest_small": Vector2i(20, 28),
	"harvest_big": Vector2i(30, 44),
	## The road home (G13): narrow and long, so the shape of the level is the
	## shape of a walk rather than of a yard. Low plant density carries the
	## rest — B18 is a conversation with mowing under it, not a search.
	##
	## The PROLOGUE reuses this exact shape (G15.1), and reuses it on purpose
	## once it turned out to exist: the game now opens on a road and closes
	## Case 01 on the same road. 306 cells, about eighty of them under fallen
	## timber, which is roughly half a minute of cutting at the push mower's
	## measured 8.3 cells a second — short, which is the point of a prologue.
	"road": Vector2i(9, 34),
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

	# Harvest levels (G13.6). AMBER pushed all the way into grain: the tips are
	# nearly white-gold, the base is dry straw, and nothing flowers — this is a
	# crop standing too long, not a lawn.
	"LAVENDER": {
		"cluster_base": Color(0.18, 0.13, 0.26),
		"cluster_tip": Color(0.72, 0.52, 0.90),
		"accents": [
			{ "base": Color(0.22, 0.15, 0.30), "tip": Color(0.84, 0.62, 0.98),
				"weight": 0.24, "flowers": true },
			{ "base": Color(0.15, 0.14, 0.22), "tip": Color(0.58, 0.46, 0.76),
				"weight": 0.12, "flowers": false },
		],
		"ground_mowed": [
			Color(0.40, 0.33, 0.28), Color(0.35, 0.29, 0.25),
			Color(0.29, 0.24, 0.22), Color(0.33, 0.27, 0.24),
		],
		"clipping": Color(0.76, 0.56, 0.92),
	},
	"PUMPKIN": {
		"cluster_base": Color(0.13, 0.24, 0.09),
		"cluster_tip": Color(0.44, 0.62, 0.22),
		"accents": [
			{ "base": Color(0.16, 0.28, 0.11), "tip": Color(0.54, 0.70, 0.26),
				"weight": 0.20, "flowers": false },
			{ "base": Color(0.11, 0.20, 0.08), "tip": Color(0.36, 0.52, 0.18),
				"weight": 0.12, "flowers": false },
		],
		"ground_mowed": [
			Color(0.44, 0.34, 0.20), Color(0.38, 0.29, 0.17),
			Color(0.31, 0.24, 0.14), Color(0.35, 0.27, 0.16),
		],
		"clipping": Color(0.90, 0.50, 0.14),
	},
	"COTTON": {
		"cluster_base": Color(0.20, 0.17, 0.11),
		"cluster_tip": Color(0.58, 0.55, 0.38),
		"accents": [
			{ "base": Color(0.23, 0.19, 0.12), "tip": Color(0.68, 0.65, 0.46),
				"weight": 0.22, "flowers": true },
			{ "base": Color(0.17, 0.15, 0.10), "tip": Color(0.48, 0.46, 0.32),
				"weight": 0.10, "flowers": false },
		],
		"ground_mowed": [
			Color(0.52, 0.46, 0.34), Color(0.46, 0.40, 0.29),
			Color(0.38, 0.33, 0.24), Color(0.42, 0.37, 0.27),
		],
		"clipping": Color(0.94, 0.93, 0.88),
	},
	"WHEAT": {
		"cluster_base": Color(0.34, 0.24, 0.08),
		"cluster_tip": Color(0.96, 0.82, 0.40),
		"accents": [
			{ "base": Color(0.38, 0.27, 0.09), "tip": Color(1.0, 0.90, 0.52),
				"weight": 0.22, "flowers": false },
			{ "base": Color(0.30, 0.22, 0.08), "tip": Color(0.84, 0.70, 0.30),
				"weight": 0.10, "flowers": false },
		],
		"ground_mowed": [
			Color(0.78, 0.64, 0.30), Color(0.70, 0.56, 0.25),
			Color(0.54, 0.42, 0.18), Color(0.62, 0.49, 0.21),
		],
		"clipping": Color(0.94, 0.80, 0.38),
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
	# A reed cuts pale, corn cuts gold: the plant profile overrides the
	# palette's clipping colour when it has an opinion (G13).
	var profile := plant_profile()
	if profile.has("clipping"):
		return profile["clipping"]
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
# ---------------------------------------------------------------- plants (G13)
## What GROWS in a chapter, as opposed to what COLOUR it is.
##
## The palette system (GRASS_PALETTES) answers "what shade of green"; this
## answers "what plant". They are deliberately separate axes: the east road
## passes through reeds, corn and sunflowers without leaving the same country,
## so a chapter picks a palette AND a profile.
##
## "form" is the one field that changes the geometry rather than its numbers:
##   blade — the fanning V-folded clumps the game has always grown
##   stalk — upright stems with leaves, and optionally a head on top
##
## Everything else scales the shared builder. GRASS restates the original
## constants exactly, so a chapter that names no profile grows what it always
## grew.
const PLANT_PROFILES := {
	"GRASS": {
		"form": "blade", "per_cell": 9, "blades": 6,
		"height_min": 0.40, "height_max": 0.90, "tall_chance": 0.30,
		"base_min": 0.45, "base_max": 0.62,
		"width_scale": 1.0, "lean_scale": 1.0, "spread": 0.44,
		"sway": 1.0, "cut_pitch": 1.0, "clipping_scale": 1.0,
	},
	## Water-green, chest high, thin as wire, and it moves twice as much as
	## grass does — a reed bed reads as reeds because of the sway, not the
	## colour.
	"REED": {
		"form": "blade", "per_cell": 7, "blades": 5,
		"height_min": 0.95, "height_max": 1.55, "tall_chance": 0.45,
		"base_min": 0.30, "base_max": 0.42,
		"width_scale": 0.55, "lean_scale": 0.45, "spread": 0.40,
		"sway": 1.9, "cut_sound": "cut_reed", "cut_pitch": 1.18,
		"clipping_scale": 0.7, "clipping": Color(0.56, 0.72, 0.52),
	},
	## Taller than the machine, which is the whole point: inside a corn field
	## the camera cannot see past the next row, so the yard becomes corridors
	## and the player earns the view by cutting it. Free claustrophobia.
	"CORN": {
		"form": "stalk", "per_cell": 4, "leaves": 5,
		"height_min": 2.10, "height_max": 2.70, "tall_chance": 0.5,
		"stalk_width": 0.055, "leaf_length": 0.62, "spread": 0.42,
		"sway": 0.45, "cut_sound": "cut_corn", "cut_pitch": 0.78,
		"clipping_scale": 2.2, "clipping": Color(0.74, 0.68, 0.34),
	},
	## Every head turned the same way. One detail, and the field is alive.
	"SUNFLOWER": {
		"form": "stalk", "per_cell": 3, "leaves": 4,
		"height_min": 1.85, "height_max": 2.35, "tall_chance": 0.5,
		"stalk_width": 0.048, "leaf_length": 0.52, "spread": 0.44,
		## EAST. Row 0 is north (-Z), so east is +X, and _add_head builds its
		## facing as Vector3(sin(yaw), .., cos(yaw)) — which makes east exactly
		## a quarter turn. The first pass used -1.20 and the whole field faced
		## WEST, away from the road the flavour text says they are following.
		"head": true, "head_radius": 0.30, "head_yaw": PI * 0.5,
		"head_petal": Color(0.94, 0.72, 0.16), "head_disc": Color(0.30, 0.20, 0.10),
		## The stalk and leaves are GREEN, whatever the palette says.
		##
		## Stalks and leaves normally take the palette's base->tip gradient, and
		## on the amber field that made a sunflower amber all the way down —
		## stalk, leaves and head one colour, which read as a dead crop. Only
		## the head is meant to be gold. These two override the gradient for
		## stalk-form plants and leave everything else alone.
		"stalk_root": Color(0.13, 0.26, 0.09),
		"stalk_tip": Color(0.42, 0.62, 0.22),
		"sway": 0.5, "cut_sound": "cut_sunflower", "cut_pitch": 0.92,
		"clipping_scale": 1.8, "clipping": Color(0.92, 0.74, 0.26),
	},
	## The harvest field's crop, grown thinner and shorter for the roadside.
	## Knee high, wiry, and violet to the root. It moves more than anything else
	## in the game — a lavender row is mostly motion — and the cut is a dry
	## snap rather than a tear.
	"LAVENDER": {
		"form": "blade", "per_cell": 8, "blades": 6,
		"height_min": 0.70, "height_max": 1.15, "tall_chance": 0.40,
		"base_min": 0.26, "base_max": 0.36,
		"width_scale": 0.50, "lean_scale": 0.70, "spread": 0.38,
		"sway": 1.7, "cut_sound": "cut_reed", "cut_pitch": 1.26,
		"clipping_scale": 0.8, "clipping": Color(0.72, 0.52, 0.86),
	},
	## The odd one out, and the point of it. Ankle high with a fat orange globe
	## sitting on almost no stalk, so a pumpkin patch is the only harvest you
	## can see straight across — after four fields that close over your head,
	## an open one is a change of weather.
	"PUMPKIN": {
		"form": "stalk", "per_cell": 2, "leaves": 5,
		"height_min": 0.34, "height_max": 0.52, "tall_chance": 0.3,
		"stalk_width": 0.070, "leaf_length": 0.78, "spread": 0.52,
		"head": true, "head_shape": "globe", "head_radius": 0.38,
		"head_yaw": 0.0,
		"head_petal": Color(0.90, 0.46, 0.10), "head_disc": Color(0.62, 0.26, 0.05),
		"stalk_root": Color(0.16, 0.28, 0.10),
		"stalk_tip": Color(0.38, 0.56, 0.20),
		"sway": 0.30, "cut_sound": "cut_corn", "cut_pitch": 0.70,
		"clipping_scale": 2.4, "clipping": Color(0.92, 0.52, 0.14),
	},
	## Waist high, dark stems, and a white boll on every one. The bolls are what
	## you see — a cotton field at dusk is a field of small pale lights.
	"COTTON": {
		"form": "stalk", "per_cell": 4, "leaves": 4,
		"height_min": 0.95, "height_max": 1.35, "tall_chance": 0.45,
		"stalk_width": 0.040, "leaf_length": 0.40, "spread": 0.40,
		"head": true, "head_radius": 0.15, "head_yaw": 0.0,
		"head_petal": Color(0.96, 0.95, 0.92), "head_disc": Color(0.88, 0.86, 0.82),
		"stalk_root": Color(0.20, 0.16, 0.10),
		"stalk_tip": Color(0.42, 0.40, 0.26),
		"sway": 0.75, "cut_sound": "cut_sunflower", "cut_pitch": 1.10,
		"clipping_scale": 1.2, "clipping": Color(0.94, 0.93, 0.88),
	},
	"WILD_WHEAT": {
		"form": "blade", "per_cell": 8, "blades": 7,
		"height_min": 0.80, "height_max": 1.15, "tall_chance": 0.40,
		"base_min": 0.34, "base_max": 0.46,
		"width_scale": 0.50, "lean_scale": 0.70, "spread": 0.42,
		"sway": 1.4, "cut_pitch": 1.08, "clipping_scale": 1.2,
	},
}

## B14's signal pair. The static starts at full and ends silent; the clear tone
## does the opposite, so the total loudness stays roughly level and only the
## CHARACTER of the sound changes (G13).
const SIGNAL_STATIC_GAIN := 0.34
const SIGNAL_CLEAR_GAIN := 0.30

## The red string on the corkboard. One colour, named, because the board draws
## it in two places (the thread and the pin heads) (G13).
const BOARD_STRING := Color(0.72, 0.16, 0.14)

# ---------------------------------------------------------------- quiet scenes
## What passing The Toll costs: a share of what the player is carrying, floored
## and capped so it is never trivial and never ruinous. A percentage alone would
## punish a rich player and cost a poor one nothing (G13).
const TOLL_SCRAP_SHARE := 0.15
const TOLL_SCRAP_MIN := 30
const TOLL_SCRAP_MAX := 200
## The drawn still behind a quiet scene: evening, a road, and three people on it.
const QUIET_SKY := Color(0.16, 0.15, 0.20)
const QUIET_GROUND := Color(0.11, 0.11, 0.13)
const QUIET_ROAD := Color(0.19, 0.18, 0.20)
const QUIET_FIGURE := Color(0.05, 0.05, 0.06)

## Where a chapter's mid-chapter conversation fires, as a completion ratio.
## Half way: far enough in that the place has been seen, early enough that the
## chapter is not already ending (G13).
const MID_CHAT_AT := 0.5

## Set per chapter by LevelVariant, exactly as active_grass_palette is.
static var active_plant_profile := "GRASS"


static func plant_profile() -> Dictionary:
	return PLANT_PROFILES.get(active_plant_profile, PLANT_PROFILES["GRASS"])


## One field of the active profile, falling back to GRASS's value and then to
## `fallback` — so a profile only has to state what it actually changes.
static func plant(key: String, fallback: Variant = 0.0) -> Variant:
	var profile := plant_profile()
	if profile.has(key):
		return profile[key]
	var grass: Dictionary = PLANT_PROFILES["GRASS"]
	return grass[key] if grass.has(key) else fallback


static func plant_is_stalk() -> bool:
	return str(plant("form", "blade")) == "stalk"


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
## How many restoration projects make the town "ready".
##
## This is Ellie's closing line turned into a number: the stranger said he would
## come back when the town was ready, so the player makes it ready and he comes.
## Case 02 shows on the board from the moment Case 01 closes, with this counter
## on its face — visible, never a wall.
##
## Calibrated against the measured economy: one chapter at 100% pays 1 567 and
## the three cheapest projects cost 950 together, so anyone who spends anything
## at all on the town clears this after a single lawn. It bites only for a
## player who put every last piece of scrap into the garage — which is the
## choice the gate exists to notice.
const TOWN_READY_PROJECTS := 3

## PLACEHOLDERS. The top bar shows the town's food store and how many people
## live there beside the scrap. Neither is simulated yet — these are the
## numbers it displays until something produces them, and they are constants
## rather than magic literals in the HUD so that wiring them up later is one
## edit in one place.
# ---------------------------------------------------------------- food (G14.12)

## Food is the town's OTHER currency and it only ever goes two ways: up when
## you bring some back from a yard, down when the town eats while you search.
## It was a hardcoded 42 on the top bar for a while — a number nothing produced
## and nothing spent, which a player reads as state and then watches never move.
##
## It drains PER FINISHED CHAPTER, never by the clock. A real-time drain would
## punish a player for not opening the game, which is the opposite of what this
## one is for.
const FOOD_START := 40
## What ONE resident eats in a day. The town's daily bill is this times the
## population, which is what makes taking someone in a decision (G14.13).
const FOOD_PER_PERSON := 1
## A day passes while you are OUT WORKING, not while the app is open. Draining
## in the menus would tax reading the case board; draining in real time would
## tax putting the phone down. This is how many seconds of mowing make a day.
const FOOD_DAY_SECONDS := 45.0
## How many baskets a yard hides, and what each is worth.
const FOOD_PICKUPS := Vector2i(2, 4)
const FOOD_VALUE := Vector2i(3, 6)
## Bought from the workshop, in sacks. Food has to be BUYABLE or a bad run
## becomes a dead end, and money is the only thing the player has a lot of.
const FOOD_SACK := 12
const FOOD_SACK_COST := 220

## Below this the town is told, once, on the way back in.
const FOOD_LOW := 12
## And below this it is not a warning any more.
const FOOD_CRITICAL := 4
## The basket prop.
const FOOD_CRATE := Color(0.52, 0.36, 0.20)
const FOOD_CRATE_DARK := Color(0.38, 0.26, 0.14)
const FOOD_PRODUCE := [Color(0.86, 0.32, 0.22), Color(0.92, 0.62, 0.18),
	Color(0.44, 0.62, 0.24)]
const FOOD_SIZE := Vector3(0.46, 0.30, 0.40)

## The population is DERIVED, never stored: the named townsfolk who are
## actually here, plus one returning resident per rebuilt project. A number the
## player can check against the diorama is worth more than a number they have
## to trust.
const TOWN_BASE_PEOPLE := 5
## Debug only: grants money from the pause menu for balance testing. Ships false.
const DEV_GRANT_SCRAP := false
## Debug only: the wallet a fresh save starts with, so systems downstream of the
## economy can be exercised without grinding to them. Ships 0.
const DEV_STARTING_SCRAP := 0
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
## G14.3 recalibration. The measured problem: reaching the harvest (2 tier-1
## restore projects + the tractor, the cheapest path = 550 + 800 = 1350, plus
## the farm's 900 = 2250) is gated behind `chapters:3`, but the first three
## chapters at 100% paid only 1 519 — the harvest loop was unreachable exactly
## when the game asks the player to reach it. Applied the same way as
## HARVEST_SCRAP_MULTIPLIER (post-hoc in Game._payout, so ScrapField's unit
## math stays untouched): 1 519 * 1.7 = 2 582, clearing the gate with the same
## ~15% headroom the harvest gate's own design implies elsewhere.
const SEARCH_SCRAP_MULTIPLIER := 1.7
## Money bundle prop: the genre-classic green cash stack, VISIBLE above the
## grass before it is collected — hidden pickups read as luck, visible ones as
## goals to steer toward.
## Deeper than the first pass: at 0.45 green the stack read as painted plastic.
const MONEY_BILL := Color(0.06, 0.34, 0.15)
const MONEY_BILL_TOP := Color(0.16, 0.62, 0.26)
## A paper strap, not a plastic clip: pale and thin. The first pass was a fat
## saturated yellow band that stood proud of the stack.
const MONEY_BAND := Color(0.93, 0.88, 0.70)
## A US note is about 2.35 times as long as it is wide, and that ratio is most
## of what makes a stack read as CASH rather than as a green brick. It was
## 1.47:1 and looked like a box with a stripe painted on it (G14.12).
const MONEY_SIZE := Vector3(0.66, 0.20, 0.28)
## Individual notes in the bundle. The stack used to be one box with a stripe,
## which read as a green brick; the stepped edges are what say "paper".
const MONEY_SHEETS := 5
## The printed mark on the top note.
const MONEY_INK := Color(0.08, 0.22, 0.13)
## The printed FACE of the top note. Banknote paper is pale and greyish; the
## saturated green belongs to the edges of the stack, which is all you see of
## the notes underneath.
const MONEY_FACE := Color(0.66, 0.78, 0.58)
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
## Bigger on request (G14.23): the speaker should carry the screen during a
## conversation, and at 430x764 the portrait was a stamp beside a box. The
## bubble grew with it, or a bigger head would only have crowded the same text.
const DIALOGUE_PORTRAIT_SIZE := Vector2(560, 940)
## How far above the screen's bottom the bubble's top edge sits; the portrait
## stands on that line, so both move together.
const DIALOGUE_PANEL_LIFT := 700.0


# ---------------------------------------------------------------- G7 story
## Warm dark ground behind an intro card whose illustration is missing, and the
## letterbox behind one that does not match the screen aspect.
## Ken Burns end scale for the intro cards; tools/shrink_art.gd sizes the
## source art from it, so the two can never drift apart.
const INTRO_KEN_BURNS_TO := 1.06
const INTRO_GROUND := Color(0.13, 0.10, 0.08)
# ---------------------------------------------------------------- UI scale
## The type scale. Six steps, and every label in the UI uses one of them.
##
## Before this there were EIGHTEEN distinct font sizes across the screens —
## 19, 20, 22, 24, 26, 28, 30, 32, 34, 36, 38, 40, 42, 44, 46, 52, 54, 76 —
## chosen one at a time as each screen was written. That is the single loudest
## reason the UI read as a web dashboard rather than as a game: nothing lined
## up, so nothing looked deliberate. A scale is not a style preference, it is
## what makes hierarchy legible without the reader having to work it out.
##
## Steps are roughly 1.25x apart, which is wide enough that two adjacent sizes
## are visibly different rather than accidentally different.
## Sizes are PIXELS in a 1170x2532 viewport, which is a 3x device scale — so
## divide by three for points. The first version of this scale ran 18-72px,
## i.e. 6pt to 24pt, and everything below UI_HEAD landed under Apple's 11pt
## floor: labels at 7pt and body text at 9pt. It was reported, correctly, as
## simply too small to read.
##
## The band below is anchored to sizes this game already proves are readable —
## its dialogue box and HUD run 32-52px — so the scale now starts where the
## rest of the game starts instead of half way beneath it.
const UI_DISPLAY := 84   ## 28pt. The game's name. One place only.
const UI_TITLE := 58     ## 19pt. Screen headers.
const UI_HEAD := 46      ## 15pt. Card titles, primary buttons.
const UI_BODY := 38      ## 13pt. Ordinary reading text.
const UI_LABEL := 32     ## 11pt. Section labels, hints, secondary lines.
const UI_MICRO := 26     ##  9pt. Fine print only — never a full sentence.

## Vertical rhythm. Same argument as the type scale: spacing picked per screen
## is what makes a layout feel assembled rather than designed.
const UI_GAP_TIGHT := 8
const UI_GAP := 16
const UI_GAP_WIDE := 28
const UI_GAP_SECTION := 40

## Standard tap target. Apple's HIG floor is 44pt; at this project's 1170-wide
## portrait viewport that is about 96px, and nothing interactive goes under it.
const UI_TAP_MIN := 96

# ---------------------------------------------------------------- UI palette
## Semantic colours. Named for what they MEAN, not for what they look like, so
## a row that is "done" and a row that is "positive" cannot drift apart.
##
## Warmer and more saturated than the near-neutral greys this UI started with.
## A dark interface built out of pure greys reads as a developer tool; the same
## interface built out of browns, brass and moss reads as an object from the
## game's own world. Every surface below carries a little red and yellow, and
## nothing is a pure grey.
##
## Ground: warm charcoal, like unpainted iron rather than black plastic.
const UI_BG := Color(0.086, 0.078, 0.067)
## A panel lifted off that ground — one step, not three.
const UI_SURFACE := Color(0.128, 0.116, 0.098)
## The panel that carries the primary action.
const UI_SURFACE_RAISED := Color(0.165, 0.148, 0.122)
## Hairlines and dividers.
const UI_LINE := Color(0.42, 0.36, 0.26, 0.42)

## Text. Three weights and no more: anything needing a fourth is really asking
## for a different size.
const UI_INK := Color(0.97, 0.95, 0.90)
const UI_INK_SOFT := Color(0.83, 0.79, 0.71)
const UI_INK_FAINT := Color(0.62, 0.58, 0.51)

## BRASS — the objective, the thing to do next, the one thing on screen that
## wants the eye. Deeper and more metallic than the pale gold it replaces.
const UI_BRASS := Color(0.93, 0.72, 0.28)
## Used for text as well as for rules and borders — index numbers, section
## headings, counters — so it is held at 5.7:1 on UI_BG and 5.2:1 on
## UI_SURFACE. A darker, prettier brass measured 3.8:1 against the panel and
## failed the 4.5:1 floor.
const UI_BRASS_DEEP := Color(0.72, 0.53, 0.21)
## GREEN — done, restored, healthy. A real moss, not a washed mint.
const UI_GREEN := Color(0.52, 0.76, 0.38)
const UI_GREEN_DEEP := Color(0.22, 0.38, 0.19)
## RED — danger, blocked, destructive. Warm brick, never a signal red.
const UI_RED := Color(0.87, 0.38, 0.30)
## Text ON a brass fill — the primary button, the harvest tile. Nearly black
## and slightly warm, so the bright plate reads as painted metal rather than as
## a web accent colour.
const UI_ON_BRASS := Color(0.14, 0.10, 0.04)

## These three predate the palette above and are used in about fifty places
## across eight screens. Rather than edit fifty call sites, they are now
## ALIASES onto the semantic tokens — they always meant the same three things,
## so the whole app moves to the new palette at once and cannot drift out of
## step with it later.
##
## The practical effect is that secondary text got brighter: CASE_MUTED sat at
## 0.72 grey, and every hint and caption in the game was dimmer than it needed
## to be.
## Briefing box and case-note panel ground.
const CASE_PANEL := Color(UI_SURFACE, 0.94)
## Case title / objective text.
const CASE_ACCENT := UI_BRASS
## The town-page MISSING poster for Ellie (G12.10).
const POSTER_BG := Color(0.148, 0.132, 0.108)
const CASE_MUTED := UI_INK_SOFT
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
## Every landmark EnvironmentBuilder._build_landmark can draw. A variant naming
## anything else logs a warning and stands in an empty yard, so this list and
## that match statement have to move together.
const LANDMARK_IDS: Array[String] = [
	"playground", "greenhouse", "water_tower", "mill", "barn",
	# Case 02, Act 1 (G13).
	"antenna_mast", "orchard",
	# Case 02, Act 2 — the east road.
	"crossing", "roadside_camp", "listening_post", "old_clinic",
	# Case 02, Act 3 — the confrontation.
	"meeting_stone", "signal_garden",
	# The prologue: what he was walking towards (G15.1).
	"clearing",
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
## Measured, not guessed: the play camera leaves roughly five degrees of sky
## above the horizon line. Clouds at y 24-30 on a 96 ring sit at nine degrees —
## above the frame, which is why nobody had ever seen one (G14.2).
const CLOUD_Y_MIN := 9.0
const CLOUD_Y_MAX := 17.0
const CLOUD_DRIFT := 2.5
const CLOUD_PERIOD := 30.0

# ---------------------------------------------------------------- character (§8)
## No skeleton: joints are separate Node3D pivots, animation is sine/lerp.
## Height ~1.55, head/height ~1/7. Root pivot sits at the waist.
const CHAR_SHIRT := Color(0.92, 0.50, 0.18)
## Outfits (G14.19). The Marshal is always the orange shirt — he is the player
## and has to be findable in a yard at a glance — but every OTHER figure in the
## town takes one of these, so the diorama stops being a crowd of identical
## men. Picked by a seed, never at random on the frame, so a townsperson wears
## the same clothes every time you look at them.
const CHAR_OUTFITS: Array[Dictionary] = [
	{"shirt": Color(0.92, 0.50, 0.18), "jeans": Color(0.28, 0.36, 0.52),
		"hat": Color(0.55, 0.52, 0.34), "hair": Color(0.24, 0.16, 0.11)},
	{"shirt": Color(0.36, 0.52, 0.62), "jeans": Color(0.30, 0.28, 0.26),
		"hat": Color(0.42, 0.40, 0.32), "hair": Color(0.14, 0.12, 0.11)},
	{"shirt": Color(0.72, 0.30, 0.32), "jeans": Color(0.34, 0.32, 0.38),
		"hat": Color(0.60, 0.50, 0.30), "hair": Color(0.42, 0.26, 0.13)},
	{"shirt": Color(0.52, 0.56, 0.34), "jeans": Color(0.24, 0.30, 0.42),
		"hat": Color(0.36, 0.34, 0.28), "hair": Color(0.30, 0.22, 0.16)},
	{"shirt": Color(0.86, 0.78, 0.52), "jeans": Color(0.32, 0.34, 0.40),
		"hat": Color(0.48, 0.44, 0.34), "hair": Color(0.56, 0.44, 0.24)},
	{"shirt": Color(0.44, 0.36, 0.56), "jeans": Color(0.26, 0.26, 0.30),
		"hat": Color(0.52, 0.48, 0.36), "hair": Color(0.20, 0.18, 0.18)},
]


## The face (G14.19). Two eyes, a brow line and a mouth, all flat boxes on the
## front of the head: at the distance this game is played at anything more is
## invisible, and anything less leaves a blank ball under a hat.
## Smaller and further apart than the first pass, which put a 0.024-tall eye
## 0.030 below a brow and merged the two into one dark band across the face —
## it read as sunglasses (G14.19).
const CHAR_EYE_SIZE := Vector3(0.019, 0.016, 0.010)
const CHAR_EYE_GAP := 0.044
const CHAR_EYE_Y := 0.022
const CHAR_BROW_SIZE := Vector3(0.026, 0.007, 0.009)
const CHAR_BROW_Y := 0.058
const CHAR_MOUTH_SIZE := Vector3(0.030, 0.009, 0.009)
const CHAR_MOUTH_Y := -0.038
## Hair (G14.21). It has to live UNDER the hat brim and behind the face: a
## sphere the size of the head would swallow the eyes, so this is a back cap
## plus two temple tufts, each sitting in the gap between the brim and the jaw.
const CHAR_HAIR_BACK := 0.118
const CHAR_HAIR_TUFT := 0.052
const CHAR_HAIR := Color(0.26, 0.18, 0.12)

## The hand: a flattened palm with a thumb on the inside edge. A cube read as
## a fist-shaped brick, and the thumb is the one detail that says which way a
## hand is facing.
const CHAR_PALM := Vector3(0.062, 0.078, 0.046)
const CHAR_THUMB := Vector3(0.024, 0.042, 0.024)

const CHAR_EYE := Color(0.14, 0.12, 0.11)
const CHAR_BROW := Color(0.26, 0.19, 0.13)
const CHAR_MOUTH := Color(0.58, 0.36, 0.32)
const CHAR_SKIN := Color(0.87, 0.67, 0.52)
const CHAR_JEANS := Color(0.28, 0.36, 0.52)
## "Haki" hat and the dark brow band have no numeric colours in §8.
const CHAR_HAT := Color(0.55, 0.52, 0.34)
const CHAR_BAND := Color(0.13, 0.11, 0.09)
const CHAR_BOOT := Color(0.20, 0.15, 0.11)

## Proportions, revisited (G14.17). The torso was 0.44 against 0.70 of leg,
## which reads as a short body on long legs; a person is closer to even. The
## head was small enough that the hat did the work of finding the face.
const CHAR_TORSO_SIZE := Vector3(0.35, 0.50, 0.21)
## The torso is ONE tapered eight-sided prism, not a box and not a stack of
## boxes (G14.18). A box read as a crate with a head on it; splitting it into a
## chest over a waist read worse — the step between them plus the shoulder yoke
## made a T. A single form that is wider at the shoulders than at the hips is
## what says "body", and it is also one draw instead of three.
const CHAR_CHEST_RADIUS := 0.168
const CHAR_WAIST_RADIUS := 0.138
const CHAR_TORSO_SIDES := 8
## How deep the torso is against how broad. A chest is about half as deep as it
## is wide; a CylinderMesh is circular, so without this the body came out a
## barrel (G14.20).
const CHAR_TORSO_DEPTH := 0.62
## How much narrower the pelvis is than the shirt's waist. At 1.0 the two
## surfaces were coincident and the pelvis showed THROUGH the shirt.
const CHAR_PELVIS_INSET := 0.88
## How far above the hip line the shirt ends. At zero its bottom rim sat exactly
## where the thighs begin and the two intersected: the hem showed as a row of
## red teeth over the jeans (G14.22). The pelvis covers the gap.
const CHAR_SHIRT_LIFT := 0.055
## Limbs are tapered prisms too (G14.20). A square-section arm or leg is the
## loudest remaining thing that says "built out of bricks", and a real limb
## narrows along its length: thigh to knee, knee to ankle, shoulder to wrist.
## Six sides is enough at this size and cheaper than eight.
const CHAR_LIMB_SIDES := 6
const CHAR_ARM_TOP := 0.052
const CHAR_ARM_MID := 0.040
const CHAR_ARM_WRIST := 0.033
const CHAR_LEG_TOP := 0.072
const CHAR_LEG_KNEE := 0.056
const CHAR_LEG_ANKLE := 0.046
const CHAR_HEAD_RADIUS := 0.125
const CHAR_BAND_SIZE := Vector2(0.16, 0.035)
const CHAR_HAT_BRIM_RADIUS := 0.175
const CHAR_HAT_TOP_RADIUS := 0.10
const CHAR_SHOULDER := Vector2(0.195, 0.46)    # +/-x, y — on the torso
## Arm to leg was 0.66 against a human's ~0.72: measurably short, and it read
## as short — the hands sat above the hips instead of beside them.
const CHAR_UPPER_ARM := 0.26
const CHAR_LOWER_ARM := 0.24
const CHAR_HIP_X := 0.09
const CHAR_UPPER_LEG := 0.36
const CHAR_LOWER_LEG := 0.34
## A real boot, in two parts: a sole that meets the ground and an upper that
## meets the shin. It was one 0.09-tall box tucked INSIDE the bottom of the leg
## and read, at any distance the game is actually played at, as no foot at all
## (G14.17).
const CHAR_BOOT_SIZE := Vector3(0.135, 0.075, 0.28)
const CHAR_BOOT_SOLE := Vector3(0.145, 0.045, 0.30)
const CHAR_BOOT_TOE := 0.09
## The pelvis the legs hang off, and the neck the head sits on. Without them
## the torso floated over two separate legs and the head over the torso.
const CHAR_PELVIS_SIZE := Vector3(0.30, 0.13, 0.19)
const CHAR_NECK_SIZE := Vector3(0.085, 0.07, 0.085)
## Hands, so the arms end in something.
const CHAR_HAND_SIZE := Vector3(0.075, 0.085, 0.075)
## A yoke across the shoulders: the shirt reads as a shirt with it, and as a
## rectangle without.
const CHAR_YOKE_SIZE := Vector3(0.37, 0.075, 0.23)
const CHAR_AO_SIZE := 0.7                      # NOT in §8 — small contact shadow

# Push mode (§8): walks behind the mower.
const CHAR_PUSH_SEAT := Vector3(0.0, 0.79, 1.45)
## Waist height on foot (G14.17). The figure's root IS its waist and the legs
## hang DOWN from it, so a walker placed at y 0 buries them: that is why the
## man appeared to have no feet. 0.79 is the push mower's own waist height,
## which is the same person standing on the same ground.
const CHAR_WALK_WAIST_Y := 0.79
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

# ---------------------------------------------------------------- hub diorama (G13)
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
## Writes draw-call, triangle and frame-rate lines to the console on hub entry.
## OS.is_debug_build(), not a hand-edited true: this shipped switched on, and a
## release build has no console to read it in (G16).
static var PERF_LOG := OS.is_debug_build()

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


# ---------------------------------------------------------------- map (G13.5)
## The case board's PLACES list is replaced by a two-layer map. Positions are
## fractions of the map rect, so the same numbers work at any screen size.
##
## Case 1 reads WEST to EAST across the town: the Aldridge house at the edge,
## then the neighbour, the square, the creek, and out past the greenhouse to the
## mill and the cellar. That line IS Ellie's route, drawn without a word.
const MAP_PLACES := {
	"ch01_aldridge": Vector2(0.25, 0.73),
	"ch02_neighbor": Vector2(0.37, 0.84),
	"ch03_playground": Vector2(0.47, 0.54),
	"ch04_flooded": Vector2(0.41, 0.69),
	"ch05_greenhouse": Vector2(0.17, 0.31),
	"ch06_watertower": Vector2(0.85, 0.38),
	"ch07_mill": Vector2(0.83, 0.14),
	"ch08_cellar": Vector2(0.92, 0.26),
	# Case 02, Act 1 (G13). The break from town happens in FAMILIAR country, so
	# these are pins on the town sheet like Case 01's — not stops on the east
	# road, which only starts at the river. Without them the first three
	# chapters had no pin anywhere and the whole case was unreachable: every
	# east-road stop reported "finish the earlier places" about places the
	# player could not get to.
	"ch09_radio_room": Vector2(0.62, 0.62),
	"ch10_relay_hill": Vector2(0.70, 0.07),
	"ch11_orchard": Vector2(0.09, 0.58),
	# And the way back. B18 ends at the town, so it belongs to the town sheet
	# rather than to the road it walks along.
	"ch18_long_road_home": Vector2(0.965, 0.62),
}
## Restored buildings that appear on the town map as small icons, and which
## screen each one opens.
const MAP_BUILDINGS := {
	"station": {"at": Vector2(0.56, 0.30), "opens": "case_board"},
	"homes": {"at": Vector2(0.63, 0.55), "opens": "town"},
	"watchtower": {"at": Vector2(0.85, 0.38), "opens": "town"},
	"clinic": {"at": Vector2(0.28, 0.24), "opens": "town"},
	"greenhouse": {"at": Vector2(0.17, 0.31), "opens": "town"},
	"farm": {"at": Vector2(0.13, 0.45), "opens": "town"},
	"barn": {"at": Vector2(0.84, 0.78), "opens": "town"},
	"mast": {"at": Vector2(0.72, 0.22), "opens": "workshop"},
	"lantern": {"at": Vector2(0.50, 0.46), "opens": "town"},
	"swing": {"at": Vector2(0.45, 0.44), "opens": "town"},
}
## The town's own spot on the world map, and the far light in the east.
const MAP_TOWN_AT := Vector2(0.27, 0.50)
const MAP_FAR_LIGHT := Vector2(0.90, 0.32)

const MAP_INK := Color(0.30, 0.22, 0.15)
const MAP_INK_FAINT := Color(0.42, 0.34, 0.26, 0.55)
const MAP_PARCHMENT := Color(0.83, 0.74, 0.56)
const MAP_PARCHMENT_DARK := Color(0.62, 0.52, 0.37)
const MAP_WATER := Color(0.44, 0.56, 0.58)
## Pin states, in the scheme the rest of the case screens already use.
const MAP_PIN_DONE := Color(0.42, 0.72, 0.36)
const MAP_PIN_ACTIVE := Color(0.95, 0.82, 0.45)
const MAP_PIN_LOCKED := Color(0.52, 0.50, 0.46)
## How far a finished place brightens the map around it — the reclaimed band's
## answer on paper (G13.4).
const MAP_RECLAIM_RADIUS := 0.085
const MAP_ZOOM_SECONDS := 0.45
## The painted sheets are 3:2. On a portrait screen the map keeps that shape and
## is centred, rather than being cropped to a narrow strip — the greenhouse and
## the water tower live at the left and right edges and would be the first
## things lost (G13.5).
const MAP_SHEET_ASPECT := 1.5


# ---------------------------------------------------------------- first run (G15)
## The one-time orientation pass. A player who has finished a search never sees
## any of this again — it exists to stop somebody leaving in the first minute
## because they do not yet know what the mowing is FOR.
##
## Six layers already say it (five intro cards, the opening title, the case line
## in the top bar, the poster, the Marshal's radio, the first evidence card).
## These add a seventh and an eighth deliberately, for the first run only.
const FIRST_RUN_MODAL_AFTER := 4.0
## Percentages at which the Marshal speaks on a FIRST run: much earlier than the
## usual 30/60, so the player hears where to look inside the first few seconds.
const FIRST_RUN_SCENT_AT := [0.08, 0.45]
## How long Ellie's poster pulses at the start of a first run.
const FIRST_RUN_POSTER_PULSE := 12.0
## How wide the one-off evidence hint reaches, in cells. Wider than a scent
## moment: this one is allowed to point, once.
const FIRST_RUN_HINT_CELLS := 4


# ---------------------------------------------------------------- harvest (G13.6)
## A repeatable bonus level: mow the town's crop. It advances no case and holds
## no evidence — it pays in scrap and in the barn filling up.
##
## Everything here rides on systems that already exist: a LevelVariant, a grass
## palette, the scrap field and Gus's dialogue. The only new thing on screen is
## the crop standing around the plot, and that is decor.
## The harvest's own colour: the map badge and the radio card, so the bonus
## level reads as a different errand from a case pin.
const HARVEST_GOLD := Color(0.92, 0.76, 0.24)
## The six fields the farm offers, each growing a different crop: wheat,
## sunflowers, corn, lavender, pumpkin and cotton. HARVEST_VARIANT stays as the
## first of them because the map pin and a handful of older call sites name it
## directly.
const HARVEST_VARIANT := "harvest_field"
const HARVEST_VARIANTS: Array[String] = [
	"harvest_field", "harvest_sunflower", "harvest_corn",
	"harvest_lavender", "harvest_pumpkin", "harvest_cotton",
]
## What each field is called on the farm sheet, in the same order.
const HARVEST_NAMES: Array[String] = [
	"HARVEST_FIELD_WHEAT", "HARVEST_FIELD_SUN", "HARVEST_FIELD_CORN",
	"HARVEST_FIELD_LAVENDER", "HARVEST_FIELD_PUMPKIN", "HARVEST_FIELD_COTTON",
]


## True for any of the fields. Comparing against HARVEST_VARIANT alone
## sent the rest down the case-pin path, where they have no route slot and
## the panel would have talked about a place that does not exist.
static func is_harvest_variant(variant_id: String) -> bool:
	return HARVEST_VARIANTS.has(variant_id)


## Offered after this many finished searches, once the farm is rebuilt and the
## tractor is owned. It then waits indefinitely: an invitation, not a timer.
const HARVEST_EVERY := 3
## Scrap is denser here than in a search — this is the paying job.
const HARVEST_SCRAP_MULTIPLIER := 2.2
## Hay bales that pile up outside the barn in the diorama, one per harvest.
const HARVEST_BALES_MAX := 4

## The crop standing around the plot. Deliberately enormous: the brief asked for
## sunflowers and corn you look UP at, so these are authored at two to three
## times a person's height and planted right up to the fence.
const CROP_ROWS := 7
## The first row stands right against the fence — on a 20-wide plot the side
## rows are already near the edge of a portrait frame, and any further out they
## are simply not on screen.
const CROP_ROW_GAP := 1.15
const CROP_SPACING := 1.25
## Extra distance for the rows behind the mower's starting fence, so a six-metre
## sunflower does not sit in front of the camera.
const CROP_SOUTH_SETBACK := 0.0
## Sunflower: stalk height, head radius. A head this size is roughly a dinner
## plate at the game's scale.
const SUNFLOWER_HEIGHT := Vector2(4.2, 6.4)
const SUNFLOWER_HEAD := 0.95
const SUNFLOWER_PETALS := 18
const SUNFLOWER_PETAL := Color(0.98, 0.78, 0.16)
const SUNFLOWER_CENTRE := Color(0.32, 0.20, 0.10)
const SUNFLOWER_STALK := Color(0.32, 0.46, 0.18)
## Corn: stalk height, and the leaves that fan off it.
const CORN_HEIGHT := Vector2(4.6, 6.8)
const CORN_LEAVES := 7
const CORN_STALK := Color(0.44, 0.56, 0.22)
const CORN_LEAF := Color(0.38, 0.54, 0.20)
const CORN_COB := Color(0.92, 0.82, 0.34)
const CORN_TASSEL := Color(0.74, 0.66, 0.34)

# ---------------------------------------------------------------- time of day

## The eight chapters are ONE day (G14.1): Ellie goes missing on the morning of
## her ninth birthday and is found in time for the evening. These presets make
## that day visible without a dynamic sky — the same two nodes the scene already
## has, with different numbers. No addon, no textures, nothing per frame.
##
## `elev` is the sun's height above the horizon in degrees and `azim` the
## compass direction it comes from; midday is the hand-tuned angle the whole
## game was lit and balanced against, so it is the one entry that must not
## drift.
const TIME_OF_DAY := {
	# The hour, not the darkness: the grass still has to read tall-versus-cut,
	# so the low sun is paid for with ambient rather than with gloom. First pass
	# used elev 14 / energy 0.85 / ambient 0.50 and the yard was unplayable.
	"dawn": {
		"elev": 24.0, "azim": 95.0,
		"sun": Color(1.00, 0.88, 0.74), "sun_energy": 1.02,
		"sky_top": Color(0.42, 0.60, 0.86), "sky_horizon": Color(0.98, 0.86, 0.72),
		"ground": Color(0.66, 0.66, 0.58),
		"ambient": Color(0.62, 0.66, 0.78), "ambient_energy": 0.64,
		"fog": Color(0.90, 0.86, 0.82),
	},
	"morning": {
		"elev": 34.0, "azim": 78.0,
		"sun": Color(1.00, 0.95, 0.86), "sun_energy": 1.00,
		"sky_top": Color(0.33, 0.58, 0.92), "sky_horizon": Color(0.95, 0.91, 0.80),
		"ground": Color(0.63, 0.68, 0.60),
		"ambient": Color(0.55, 0.62, 0.72), "ambient_energy": 0.45,
		"fog": Color(0.85, 0.90, 0.95),
	},
	"midday": {
		"elev": 50.0, "azim": 47.7,
		"sun": Color(1.00, 0.96, 0.88), "sun_energy": 1.05,
		"sky_top": Color(0.28, 0.56, 0.94), "sky_horizon": Color(0.93, 0.89, 0.78),
		"ground": Color(0.62, 0.68, 0.60),
		"ambient": Color(0.55, 0.62, 0.70), "ambient_energy": 0.42,
		"fog": Color(0.80, 0.88, 0.95),
	},
	# Azimuth is the lever nobody expects: the camera looks north, so a sun near
	# azimuth 0 shines from behind it and flattens the lawn into one tone. This
	# used to sit at 8 degrees and measured 0.020 between cut and standing
	# grass, against 0.056 for the side-lit morning (G14.4).
	"afternoon": {
		"elev": 38.0, "azim": -58.0,
		"sun": Color(1.00, 0.94, 0.82), "sun_energy": 1.00,
		"sky_top": Color(0.31, 0.57, 0.90), "sky_horizon": Color(0.96, 0.88, 0.74),
		"ground": Color(0.64, 0.66, 0.56),
		"ambient": Color(0.58, 0.60, 0.66), "ambient_energy": 0.42,
		"fog": Color(0.86, 0.88, 0.90),
	},
	# Measured, not eyeballed: at elev 16 with ambient 0.48 the cut stripe and
	# the standing grass came out 0.001 apart in mean brightness — the lawn had
	# stopped reading at all. A higher sun and a quieter ambient give the blades
	# their own shadow back (G14.4).
	"golden": {
		"elev": 34.0, "azim": -72.0,
		"sun": Color(1.00, 0.82, 0.58), "sun_energy": 1.42,
		"sky_top": Color(0.36, 0.52, 0.82), "sky_horizon": Color(1.00, 0.78, 0.52),
		"ground": Color(0.62, 0.58, 0.46),
		"ambient": Color(0.64, 0.58, 0.54), "ambient_energy": 0.34,
		"fog": Color(0.95, 0.80, 0.62),
	},
	# The light switch's own sunset (G14.3), and the only preset no chapter
	# uses. B8's "dusk" is the story's evening and is deliberately subdued;
	# this one is the LOOK a player picks on purpose, so it is warmer, brighter
	# and more saturated than the hour it is named after. Tried and rejected
	# first: reusing "dusk" (read as dim rather than as sunset) and reusing
	# "golden" (read as a hazy afternoon, no sunset signature at all).
	"sunset": {
		# Low sun first, colour second: the long raking shadow is what says
		# "sunset" from a camera that is looking at the ground. Warmed twice on
		# request — the sun is nearly orange now and the ambient carries the
		# same fire rather than cooling it back down.
		"elev": 9.0, "azim": -34.0,
		"sun": Color(1.00, 0.56, 0.24), "sun_energy": 1.55,
		"sky_top": Color(0.32, 0.34, 0.60), "sky_horizon": Color(1.00, 0.48, 0.24),
		"ground": Color(0.58, 0.42, 0.32),
		"ambient": Color(0.86, 0.58, 0.44), "ambient_energy": 0.72,
		"fog": Color(1.00, 0.58, 0.34),
	},
	# Night, and the hardest preset in the file to get right: the whole game is
	# reading which grass is cut, and darkness is exactly what takes that away.
	# So this is a MOONLIT night, not a dark one — the key light is high enough
	# to keep the blades separated, the ambient is far above anything realistic,
	# and the colour does the work of saying "night" instead of the exposure.
	"night": {
		"elev": 52.0, "azim": 24.0,
		"sun": Color(0.60, 0.72, 1.00), "sun_energy": 0.52,
		"sky_top": Color(0.03, 0.04, 0.12), "sky_horizon": Color(0.09, 0.12, 0.26),
		"ground": Color(0.08, 0.10, 0.16),
		"ambient": Color(0.30, 0.42, 0.80), "ambient_energy": 0.42,
		"fog": Color(0.10, 0.14, 0.30),
	},
	# Same rule as dawn, harder: this is the chapter Ellie is found in, and it
	# must not be the chapter nobody can see. Colour carries the hour; ambient
	# keeps the lawn legible.
	"dusk": {
		"elev": 24.0, "azim": -68.0,
		"sun": Color(1.00, 0.72, 0.52), "sun_energy": 1.18,
		"sky_top": Color(0.28, 0.38, 0.66), "sky_horizon": Color(0.96, 0.66, 0.50),
		"ground": Color(0.52, 0.50, 0.48),
		"ambient": Color(0.60, 0.58, 0.70), "ambient_energy": 0.48,
		"fog": Color(0.84, 0.70, 0.68),
	},
}

## The one a level falls back to. Everything looked like this before G14.2.
const TIME_OF_DAY_DEFAULT := "midday"

## The player's own light switch (G14.3). AUTO leaves the chapter's own hour
## alone — the eight chapters are one day and that is the story — while the
## other two override every level.
##
## Night is moonlit rather than dark, for the same reason every other preset
## has a floor under it: the game is read by telling cut grass from uncut, and
## an honest night would end that. The sun does not move within a level either;
## nothing here ever looks up at the sky.
const SKY_MODE_AUTO := "auto"
const SKY_MODE_DAY := "day"
const SKY_MODE_DUSK := "dusk"
const SKY_MODE_NIGHT := "night"
const SKY_MODES: Array[String] = [SKY_MODE_AUTO, SKY_MODE_DAY, SKY_MODE_DUSK,
	SKY_MODE_NIGHT]
## Which TIME_OF_DAY preset each forced mode uses.
const SKY_MODE_PRESET := {
	SKY_MODE_DAY: "midday",
	SKY_MODE_DUSK: "sunset",
	SKY_MODE_NIGHT: "night",
}

# ---------------------------------------------------------------- open country

## What lies past the fence. Every yard used to end in a 90x76 dirt apron with
## nothing beyond it, and the distant hills were built at 78 while the fog
## closed at 70 — so the hills had never once been visible in the game (G14.2).
const MEADOW_SIZE := 420.0
## How far the meadow's colour sits from the yard's own grass: the country
## around a bright lawn is duller and greyer, never a second lawn.
const MEADOW_FADE := 0.45
const MEADOW_GREY := Color(0.42, 0.46, 0.34)

## Fog now has to reach past the horizon ring instead of stopping in front of
## it. Begin still sits just past the yard so the near ground is untouched.
const FOG_BEGIN := 34.0
const FOG_END := 210.0

## Clouds ring the whole sky rather than sitting in a strip to the north, so
## tilting the camera anywhere finds some.
const CLOUD_RING_RADIUS := 118.0
const CLOUD_RING_COUNT := 14

## Slow birds, high up and always in silhouette. Sound is deliberately NOT part
## of this: the ambient bird loop was removed from gameplay in G9.4 and stays
## removed.
const BIRDS_ENABLED := true
## Two flocks of four. Every bird is two unshaded quads, so this is 16 draws on
## a hub that was cut from 752 to 226 — a third of a percent is worth it, three
## percent would not be.
const BIRD_FLOCKS := 2
const BIRDS_PER_FLOCK := 4
const BIRD_SPEED := Vector2(0.020, 0.045)
const BIRD_COLOUR := Color(0.26, 0.28, 0.30, 0.70)

## The hub's own sky. These are placed RELATIVE TO THE CAMERA, not around the
## plate: the hub camera stands at (0, 28, 28.5) looking north and down, so a
## ring centred on the town put most of its clouds beside and behind it. A probe
## found 0 of 11 clouds and 0 of 30 birds actually on screen.
##
## `SPREAD` is the half-angle either side of the view direction, `DIST` how far
## out along it, and `DROP` how far below the camera's own height they sit —
## which is what decides where on the screen they land.
## The grass the town's own country is made of, matched to the plate's turf.
const DIORAMA_COUNTRY := Color(0.34, 0.44, 0.27)
const DIORAMA_CLOUD_COUNT := 11
## The camera's horizontal half-angle is 24 degrees (fov 48, keep-width), so a
## 38 degree spread threw most of the clouds off the sides before height was
## even considered.
const DIORAMA_SKY_SPREAD := 20.0
const DIORAMA_CLOUD_DIST := Vector2(58.0, 115.0)
## NEGATIVE drop = above the camera, i.e. in the actual sky. Measured at the
## shipping 1170x2532: the hub camera's top edge is 4.5 degrees ABOVE the
## horizon, so it has a real, if thin, band of sky. (An earlier measurement said
## the opposite; it was taken in a 1519-wide test window, and the camera keeps
## its WIDTH — a wider window sees LESS vertically than the phone does.)
const DIORAMA_CLOUD_DROP := Vector2(-0.5, 4.5)
const DIORAMA_CLOUD_SIZE := Vector2(9.0, 17.0)
## Birds fly nearer and lower than the clouds, so they cross in front of the
## far hills rather than sitting in empty haze.
const DIORAMA_BIRD_DIST := Vector2(46.0, 78.0)
const DIORAMA_BIRD_DROP := Vector2(19.0, 26.0)
const DIORAMA_BIRD_SIZE := 0.75

# ---------------------------------------------------------------- fireflies

## Sparks over the lawn once the sun is low (G14.5). One GPU particle system,
## so the count below costs the same as one node would; what it must NOT do is
## turn up at noon, where it would read as dust on the lens.
const FIREFLIES_ENABLED := true
const FIREFLY_HOURS: Array[String] = ["sunset", "dusk", "night"]
const FIREFLY_COUNT := 48
const FIREFLY_LIFETIME := 5.5
## Height band they stay inside: from `x` up by `y`. Chest to head height —
## below that the grass eats them, above it they read as stars.
const FIREFLY_BAND := Vector2(0.8, 2.6)
const FIREFLY_DRIFT := Vector2(0.12, 0.42)
const FIREFLY_SIZE := 0.13
const FIREFLY_COLOUR := Color(1.00, 0.94, 0.52, 0.95)

# ---------------------------------------------------------------- town life

## Which restored buildings have a chimney worth smoking, and where the smoke
## leaves them (plate space, relative to the building's own position).
##
## Smoke ONLY on rebuilt buildings: a ruin with a fire in it would say the
## opposite of what the diorama is for. This is the shortest sentence the town
## has for "someone lives here now" (G14.6).
const DIORAMA_SMOKE := {
	"homes": Vector3(0.6, 3.4, -0.4),
	"station": Vector3(-0.8, 3.6, 0.2),
	"clinic": Vector3(0.4, 3.2, 0.6),
	"farm": Vector3(-0.6, 3.0, -0.5),
}
const SMOKE_COUNT := 14
const SMOKE_LIFETIME := 4.2
const SMOKE_RISE := Vector2(0.35, 0.75)
const SMOKE_SIZE := 0.55
const SMOKE_COLOUR := Color(0.86, 0.86, 0.84, 0.30)

## Warm windows after dark, on rebuilt buildings only — so a night visit to the
## hub can be COUNTED: this many lit houses is this much town back.
const WINDOW_HOURS: Array[String] = ["dusk", "night"]
const WINDOW_COLOUR := Color(1.00, 0.86, 0.48)
const WINDOW_SIZE := Vector2(0.42, 0.34)
## Per building: where its lit windows sit, relative to the building.
const DIORAMA_WINDOWS := {
	"homes": [Vector3(-0.9, 1.3, 1.5), Vector3(0.9, 1.3, 1.5)],
	"station": [Vector3(-1.1, 1.4, 1.6), Vector3(1.1, 1.4, 1.6)],
	"clinic": [Vector3(0.0, 1.4, 1.6)],
	"farm": [Vector3(-0.8, 1.2, 1.4), Vector3(0.8, 1.2, 1.4)],
	"greenhouse": [Vector3(0.0, 1.0, 1.2)],
	"barn": [Vector3(0.0, 1.6, 1.5)],
	"watchtower": [Vector3(0.0, 3.4, 0.8)],
}

## The far silhouettes get windows too, as one merged mesh: a dark ring of
## rooftops around a lit town reads as abandonment, which is not what the story
## says by then (G14.6).
const FAR_WINDOW_CHANCE := 0.55
const FAR_WINDOW_SIZE := 0.28

## The firefly swarm doubles as the golden hour's dust, which costs nothing:
## same node, same draw, different colour and speed per hour.
const MOTE_PROFILES := {
	"golden": {"colour": Color(1.00, 0.92, 0.72, 0.42), "size": 0.09,
		"drift": Vector2(0.05, 0.18), "count": 40},
	"afternoon": {"colour": Color(1.00, 0.96, 0.86, 0.30), "size": 0.08,
		"drift": Vector2(0.04, 0.14), "count": 30},
	"sunset": {"colour": Color(1.00, 0.88, 0.52, 0.85), "size": 0.12,
		"drift": Vector2(0.10, 0.36), "count": 44},
	"dusk": {"colour": Color(1.00, 0.94, 0.56, 0.95), "size": 0.13,
		"drift": Vector2(0.12, 0.42), "count": 48},
	"night": {"colour": Color(1.00, 0.94, 0.52, 0.95), "size": 0.13,
		"drift": Vector2(0.12, 0.42), "count": 48},
}

## Cut grass at night is not grass-coloured: what comes up out of the blades in
## the dark reads as moths. Same particle system, second profile (G14.6).
const NIGHT_CLIP_HOURS: Array[String] = ["night"]
const NIGHT_CLIP_COLOUR := Color(0.92, 0.90, 0.78, 0.85)
const NIGHT_CLIP_SCALE := 1.8

## A gust crossing the field, on top of the per-blade sway that was already
## there. Zero extra draws: it is three terms in the vertex shader.
const WIND_GUST_SPEED := 0.42
const WIND_GUST_LENGTH := 0.055
const WIND_GUST_STRENGTH := 0.85

# ---------------------------------------------------------------- weather

## Rain is a property of the CHAPTER, not of the clock: it is set in
## data/levels.json next to the hour, and a yard either has it or does not
## (G14.7). No cycle, no timer, nothing to keep in sync.
const WEATHER_CLEAR := "clear"
const WEATHER_RAIN := "rain"

## One GPU particle system, like every other bit of weather-and-life in this
## project: the count below costs what one node costs.
const RAIN_COUNT := 340
const RAIN_LIFETIME := 1.15
## Fall speed, and how far above the lawn the column starts.
const RAIN_SPEED := Vector2(16.0, 22.0)
const RAIN_HEIGHT := 12.0
## Drops are drawn as thin vertical slivers; a square would read as snow.
const RAIN_DROP := Vector2(0.022, 0.62)
const RAIN_COLOUR := Color(0.80, 0.88, 0.98, 0.58)
## A little slant, so it is weather rather than a shower head.
const RAIN_SLANT := Vector3(1.6, 0.0, 0.9)

## What rain does to the light. Measured against the legibility floor before
## being kept: a storm that hides the cut line would break the only thing the
## player reads.
const RAIN_SUN_ENERGY := 0.74
const RAIN_AMBIENT_ENERGY := 1.18
const RAIN_FOG := Color(0.62, 0.68, 0.76)
const RAIN_FOG_MIX := 0.62

## Rain has to be GENTLER after dark, and the measurement is the reason. Lifting
## the ambient is what an overcast sky does and it looks right at noon — but in
## an hour that is already dim, raising the fill light drowns the only
## directional contrast left, and the cut line disappears. With the daytime
## values the three dark hours measured 0.002, 0.004 and 0.022 against a 0.030
## floor: unplayable (G14.7).
const RAIN_DARK_HOURS: Array[String] = ["sunset"]

## The hours it does not rain in, and the reason is measured rather than
## artistic. On one yard with rain as the ONLY variable, a downpour at night
## flattened cut against standing grass to 0.000 against a 0.030 floor — the
## drops veil the frame to a single value when there is no sun to separate the
## two. Thinning them to 120 at a fifth of the alpha, and damping the light not
## at all, still only reached 0.027 and 0.021. At that point the honest answer
## is a rule, not another tuning pass: no rain in the last two hours of the
## day. A chapter that asks for both simply plays dry.
const RAIN_FORBIDDEN_HOURS: Array[String] = ["dusk", "night"]
const RAIN_DARK_SUN_ENERGY := 0.94
const RAIN_DARK_AMBIENT_ENERGY := 0.92
const RAIN_DARK_FOG_MIX := 0.22

# ---------------------------------------------------------------- on foot

## Getting off the machine (G14.16). The player can step down and walk the
## yard: nothing is cut on foot, which is the point — it is for looking, for
## reaching a crate the tractor cannot turn into, and for being in the place
## rather than driving over it.
##
## The robot and the blade already have their driver standing at the edge
## watching; for those two "step down" means taking control of the person who
## was already there, and the machine carries on by itself.
const WALK_SPEED := 3.1
const WALK_TURN := 7.5
## How close you have to be to climb back on.
const WALK_REMOUNT := 2.2
## The walker's own camera, in the same (back, height, look_ahead) shape every
## machine uses. Closer and lower than any of them: on foot the yard should
## feel bigger and the grass taller.
const WALK_CAMERA := Vector3(4.0, 3.3, 1.4)

# ---------------------------------------------------------------- life (G14.22)

## What sells a person at the size this one is drawn — measured at 18% of the
## screen's height, so about 460px on a phone and 75px of face — is BEHAVIOUR,
## not geometry. At that size a pore is sub-pixel; a head that turns is not.

## The head follows what the driver has noticed. Clamped to a human range: past
## these the neck reads as broken rather than as attentive.
const LOOK_YAW_MAX := 1.15          # ~66 degrees either side
const LOOK_PITCH_MAX := 0.42        # ~24 degrees up or down
## How fast the head swings onto a new target, and how far it can see one.
const LOOK_LERP := 5.0
const LOOK_RANGE := 7.5
## Anything nearer than this is behind the shoulder and not worth turning for.
const LOOK_MIN := 0.9
## How long the head stays on one thing before it is allowed to be re-chosen.
## Without it the head snaps between two equidistant crates every frame.
const LOOK_HOLD := 1.4

## Standing still, the weight goes onto one leg and swaps every few seconds.
## A figure that stands perfectly level on both feet reads as a mannequin, and
## the shift is three joints moving a few degrees.
const IDLE_SHIFT_PERIOD := 5.2
const IDLE_HIP_DROP := 0.035
const IDLE_TORSO_ROLL := 0.055
const IDLE_TORSO_YAW := 0.045
const IDLE_SHIFT_LERP := 1.6

# ---------------------------------------------------------------- shading

## Contact shade at the seams (G14.24). One flat colour per part is what reads
## as "toy": a real form is darker where another form sits against it — under
## the hat brim, under the chin, at the shirt's hem, at the top of the boot.
##
## Translucent BLACK, never a darker version of the garment: the same shade has
## to sit correctly over an orange shirt, a red one and a green one, so it
## darkens what is behind it rather than replacing it.
const CHAR_SHADE := Color(0.0, 0.0, 0.0, 0.30)
## A little stronger under the brim, which is a real overhang.
const CHAR_SHADE_BRIM := Color(0.0, 0.0, 0.0, 0.42)
const CHAR_SHADE_THIN := 0.022

# ---------------------------------------------------------------- animals (G14.25)

## Things that live at GROUND level, where the player actually is. The sky had
## birds and the night had fireflies, but the grass itself was empty — nothing
## in the yard ever reacted to the machine coming.
##
## Every animal here is tied to the state of the LAWN, which is what makes them
## part of the game rather than decoration:
##
##   the rabbit grazes the MOWN EDGE and bolts for cover when you get near it,
##   so the line between cut and uncut is where the yard is busiest. It was in
##   the long grass in the first pass and had to be moved: the clumps are 0.4
##   to 0.9 units tall against a 0.32 rabbit, and a bolt nobody ever sees is
##   not a moment;
##
##   the birds land on ground that has JUST BEEN CUT and peck at what the
##   blades turned up, so cutting gives something back instead of only taking
##   the grass away. They are real: birds follow mowers for the insects.
##
## The dog belongs to the HOUSE, not to the lawn: it trots the strip between
## the porch and the north fence, never crosses in, and never startles.
##
## Cost: eight or nine primitive meshes each, four animals at most, and a state
## machine of three states. No navmesh, no physics bodies, no per-frame
## allocation.
const ANIMALS_ENABLED := true

## Silent by design in this sprint. G9.4 took the random ambient chirp out of
## gameplay and that decision stands — a chirp with no bird was noise. A bird
## you can SEE take off is a different thing and it belongs to the audio pass,
## along with the rustle the rabbit ought to make.

const RABBIT_COUNT := 2
## How near the machine (or the man on foot) may come before it goes. Wider
## than it sounds on purpose: a rabbit that lets you touch it is a toy, and the
## bolt has to be visible from behind the mower, not underneath it.
const RABBIT_BOLT_RANGE := 4.2
const RABBIT_SPEED := 8.0
const RABBIT_HOP_FREQ := 7.5
const RABBIT_HOP_HEIGHT := 0.13
## Seconds gone before another one appears somewhere else in the long grass.
const RABBIT_RETURN := Vector2(9.0, 16.0)
## How often a rabbit that is sitting in long grass looks for the mown edge
## instead. Without it, one placed before the player cut anything sits in the
## blades for the whole chapter and is never seen at all.
const RABBIT_RESETTLE := 6.0
## It never reappears in your lap: that reads as a spawn, not as an animal.
## Just past the bolt range and no further. At 7.0 it was measured failing:
## early in a chapter the only mown ground is the strip right around the
## player, so nothing cut was ever far enough away and the rabbit kept falling
## back into the long grass, where it cannot be seen at all.
const RABBIT_MIN_PLAYER_DIST := 5.2
const RABBIT_FUR := Color(0.52, 0.45, 0.38)
## The white scut is the whole silhouette of a bolting rabbit. It is the part
## you actually recognise, so it is the part that gets its own colour.
const RABBIT_SCUT := Color(0.92, 0.90, 0.86)
const RABBIT_EAR_PERIOD := 3.4
const RABBIT_NIBBLE_PERIOD := 1.9

const PECKER_COUNT := 3
const PECKER_FLEE_RANGE := 2.6
const PECKER_SPEED := 7.0
const PECKER_RISE := 5.5
const PECKER_RETURN := Vector2(4.0, 9.0)
const PECKER_MIN_PLAYER_DIST := 5.0
const PECKER_PECK_PERIOD := 0.85
const PECKER_FLAP_FREQ := 22.0
const PECKER_BODY := Color(0.30, 0.28, 0.26)
const PECKER_BEAK := Color(0.80, 0.66, 0.28)

## No dog on a wheat field and none in the cellar: it belongs to a house, and
## those two chapters do not have one.
const DOG_ENABLED := true
const DOG_SPEED := 1.35
const DOG_COAT := Color(0.62, 0.48, 0.32)
## Its beat. This took three tries and each failure taught the next number.
##
## The ground in front of the house is NOT free. The house sits HOUSE_MARGIN_Z
## past the lawn edge with a 4.2-deep body, so its south wall is 2.69 outside
## the lawn; the porch is a 5.0-wide, 1.6-deep platform centred 0.8 further
## out, reaching to within nine centimetres of the north fence; and the wall
## bushes fill the rest. The first line ran down the middle of that platform,
## and the dog walked through the boards.
##
## Moving it INSIDE the fence fixed the clipping and broke the visibility: the
## uncut clumps stand up to 0.9 and the dog is 0.56, so from the player's low
## camera it was behind a wall of grass. The same mistake as the rabbit, one
## sprint later.
##
## So: north of the fence, where it is above the grass line and plainly seen,
## and BESIDE the porch rather than on it. The z offset is measured from the
## fence like every other distance around the yard (G9.1) — ch01's grid is
## smaller than the default and absolute numbers were wrong for it. The x
## range is absolute, and that is deliberate: the porch is 5.0 wide in the
## HOUSE mesh whatever the lawn measures, so clearing it is an absolute
## distance, not a fraction of anything.
const DOG_PATH_OUTSET := 0.55
## Starts clear of the 5.0-wide porch (x -2.5 to 2.5) and stops well inside the
## side fence.
const DOG_RUN_X := Vector2(3.0, 6.2)
const DOG_TROT_FREQ := 7.0
const DOG_TAIL_FREQ := 4.5


# ---------------------------------------------------------------- prologue (G15.1)

## The long walk. Nine years before Case 01, and it is nine and not three
## because the existing town dialogue fixes the arithmetic: Sarah says "nine
## years ago the town handed me a baby", and Ellie is nine. So the man who
## carried that baby in is the player, and the day she goes missing is the
## anniversary of the day he gave her up. None of that is ever said out loud —
## it is available to anyone who does the sum, which is the tone rule (G14.1).
const PROLOGUE_ID := "ch00_the_long_walk"

## Every mower is drivable for this one level and then taken away. The player
## feels the tractor before the garage board ever asks them to pay for it,
## which is what makes that board mean anything on day one.
const PROLOGUE_TRIAL_MOWERS := true

## The dog. He finds it on the road with the basket, and from then on it is HIS
## dog: in every yard, it comes to where he is instead of walking a fence.
const DOG_FOLLOW_NEAR := 2.6
const DOG_FOLLOW_FAR := 5.5
const DOG_FOLLOW_SPEED := 3.4
## Where it is sitting when he comes up the road: just inside the lawn's far
## edge, in front of the open gate the clearing landmark builds. It cannot be a
## constant — the grid size, and therefore HALF_Z, is per chapter.
static func prologue_dog_spot() -> Vector3:
	return Vector3(0.6, 0.0, -HALF_Z + 1.2)
