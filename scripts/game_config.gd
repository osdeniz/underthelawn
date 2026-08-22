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
const TINT_STRIPE: Array[Color] = [
	Color(1.00, 1.00, 0.92),   # N — lightest
	Color(0.90, 0.95, 0.82),   # E
	Color(0.66, 0.75, 0.58),   # S — darkest
	Color(0.77, 0.85, 0.67),   # W
]
const TINT_TALL := Color(0.62, 0.64, 0.44)
const TINT_SOIL := Color(0.52, 0.38, 0.26)
const TINT_POOL_FLOOR := Color(0.70, 0.92, 0.95)

# ---------------------------------------------------------------- grass (§5)
const GROUND_UV_REPEAT_X := 7.0
const GROUND_UV_REPEAT_Z := 10.5
const GROUND_NORMAL_STRENGTH := 0.6
const GROUND_ROUGHNESS := 0.95

const TUFT_VARIANTS := 8
const TUFTS_PER_CLUSTER := 7
const TUFT_HEIGHT_MIN := 0.30
const TUFT_HEIGHT_MAX := 0.66
const TUFT_WIDTH_MIN := 0.26
const TUFT_WIDTH_MAX := 0.46
const TUFT_CLUSTER_SPREAD := 0.34             # in-cluster offset, +/-
const TUFT_TOP_TAPER := 0.75                  # upper edge narrows to 75%
const TUFT_CELL_SCALE_MIN := 0.9
const TUFT_CELL_SCALE_MAX := 1.1
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

# ---------------------------------------------------------------- movement (§7)
const ACCEL_TIME := 0.4
const DECEL_TIME := 0.55
const STEER_SMOOTHING := 9.0
const STEER_SPEED_RADIUS_FACTOR := 0.45
const STEER_ERROR_GAIN := 5.0                 # shortestAngle * 5 -> desiredOmega
const DRAG_THRESHOLD_PX := 8.0
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
const HAPTIC_LIGHT_MS := 10
const HAPTIC_MEDIUM_MS := 25

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
