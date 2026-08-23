class_name GameConfig
extends RefCounted
## Every tunable number, per REFERENCE.md §17 (plus the sections it points at).
## Nothing here is invented; each block cites its source section.

# ---------------------------------------------------------------- platform
const VIEWPORT_WIDTH := 1170
const VIEWPORT_HEIGHT := 2532

# ---------------------------------------------------------------- world (§2)
const GRID_COLS := 16
const GRID_ROWS := 24
const CELL_COUNT := GRID_COLS * GRID_ROWS      # 384
## Cell centre: x = col + 0.5 - 8, z = row + 0.5 - 12. Row 0 = north (-Z).
const HALF_X := 8.0
const HALF_Z := 12.0
const MOWER_START := Vector2(0.0, 10.5)        # south-centre, facing north

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
const ACTIVE_GRASS_PALETTE := "GREEN"

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
}


static func grass_palette() -> Dictionary:
	return GRASS_PALETTES[ACTIVE_GRASS_PALETTE]


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
const MOWER_TYPES: Array[Dictionary] = [
	{
		"id": "push", "emoji": "🔴", "label": "Push",
		"speed": 3.0, "deck": 0.7, "max_turn": 1.7, "body": 0.55, "reverse": 0.0,
		# §7 defaults: the push mower is the reference feel.
		"steer_gain": 5.0, "turn_drag": 0.45,
	},
	{
		"id": "tractor", "emoji": "🚜", "label": "Traktör",
		"speed": 4.8, "deck": 1.1, "max_turn": 1.5, "body": 0.85, "reverse": 0.5,
		# G6.7: at 4.8 u/s the §7 0.45 drag gave a ~5.8 unit turning radius —
		# wider than a third of the lawn. 0.28 keeps it heavy but steerable.
		"steer_gain": 5.0, "turn_drag": 0.28,
	},
	{
		"id": "robot", "emoji": "🤖", "label": "Robot",
		"speed": 2.1, "deck": 0.7, "max_turn": 2.6, "body": 0.45, "reverse": 0.0,
		# G6.7: the robot chases waypoints, so it needs to snap onto a heading
		# quickly; its own 2.6 rad/s ceiling still bounds the rate.
		"steer_gain": 7.0, "turn_drag": 0.30,
	},
	{
		# G6 Blade: yaw-free, follows the finger. max_turn is a dummy (never
		# steers) kept non-zero so speed/turn ratios stay divide-safe.
		"id": "blade", "emoji": "⚙️", "label": "Blade",
		"speed": 5.0, "deck": 0.55, "max_turn": 1.0, "body": 0.40, "reverse": 0.0,
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

# ---------------------------------------------------------------- movement (§7)
const ACCEL_TIME := 0.4
const DECEL_TIME := 0.55
const STEER_SMOOTHING := 9.0
const STEER_SPEED_RADIUS_FACTOR := 0.45
const STEER_ERROR_GAIN := 5.0                 # shortestAngle * 5 -> desiredOmega
## §7's threshold is 8 POINTS, not pixels; multiply by POINT_SCALE.
const DRAG_THRESHOLD_PT := 8.0
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
const HAPTIC_LIGHT_MS := 10        # cell mown, mower commands
const HAPTIC_MEDIUM_MS := 25       # secret uncovered
## Secret collected and 100% complete: two medium pulses.
const HAPTIC_SUCCESS_GAP := 0.08

# ---------------------------------------------------------------- G6 quality switches
## Every G6 visual feature has a switch, for FPS calibration on the phone.
const TRAFFIC_ENABLED := true
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
const TRAFFIC_LANE_EAST_Z := 21.0
const TRAFFIC_LANE_WEST_Z := 17.8
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
const BLADE_FOLLOW_GAIN := 3.2           # 1/s: desired speed per unit of distance
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
const BLADE_SCALE := 1.0

# ---------------------------------------------------------------- neighborhood (§2, §12)
const HOUSE_POS_Z := -16.8                     # z = -(12 + 4.8)
const HOUSE_BODY := Vector3(13.0, 3.2, 4.2)
const HOUSE_ROOF := Vector3(14.2, 2.4, 5.4)
const FENCE_SIDE_X := 9.6
const FENCE_SOUTH_Z := 13.6
const FENCE_POST := Vector3(0.14, 0.85, 0.06)
const FENCE_SPACING := 0.62
const FENCE_HEIGHT_JITTER := 0.05
const FENCE_ANGLE_JITTER := 0.025
const SIDEWALK_Z := 15.2
const SIDEWALK_DEPTH := 2.2
const ROAD_Z := 19.4
const ROAD_DEPTH := 6.5
const ROAD_WIDTH := 60.0
const ROAD_DASH := Vector2(1.6, 0.14)          # size; 4 units apart
const ROAD_DASH_GAP := 4.0
const NEIGHBOR_Z := 28.4
const NEIGHBOR_X: Array[float] = [-11.0, 0.5, 11.5]
## §12 tree placements: (x, z) and scale.
const TREES: Array[Vector3] = [
	Vector3(-9.3, -10.8, 1.0),
	Vector3(9.1, -2.0, 0.85),
	Vector3(-9.2, 8.0, 0.9),
]
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
const KEY_COLOR := Color(0.62, 0.48, 0.22)
const KEY_METALLIC := 0.8
const KEY_TORUS_RADIUS := 0.11
const RADIO_BOX := Vector3(0.44, 0.28, 0.14)
## NOT in §9 — "drifts up and fades" has no stated duration.
const ITEM_FADE_TIME := 0.9
const ITEM_FADE_RISE := 0.9
const ITEM_SPIN_RATE := 1.6

# ---------------------------------------------------------------- secret UI (§16)
const SECRET_TOTAL := SECRET_COUNT
const CARD_SHOW_TIME := 2.0
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
