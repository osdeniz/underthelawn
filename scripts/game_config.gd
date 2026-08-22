class_name GameConfig
extends RefCounted
## Single home for every tunable number, per the sprint brief.
##
## IMPORTANT: only values stated explicitly in the sprint brief are filled in
## below. Nothing here is invented. The brief says the names must come from
## REFERENCE.md §17 and that spec section is not in the repo yet, so these names
## are PROVISIONAL and will be renamed once §17 arrives.
##
## The MISSING block at the bottom is the checklist of what Sprint G1 still
## cannot be built without.

# ---------------------------------------------------------------- platform
const VIEWPORT_WIDTH := 1170
const VIEWPORT_HEIGHT := 2532

# ---------------------------------------------------------------- lawn (§3)
const GRID_COLS := 16
const GRID_ROWS := 24

## Obstacle footprints in cells. The pool is 12 cells but ONE collision rect.
const OBSTACLE_CELLS_FLOWERBED := 2
const OBSTACLE_CELLS_STONE := 1
const OBSTACLE_CELLS_POOL := 12
const OBSTACLE_CELLS_SUNBED := 1

# ---------------------------------------------------------------- striping (§4)
const STRIPE_TONE_COUNT := 4
# Tone colours themselves are §4 — see MISSING.

# ---------------------------------------------------------------- tufts (§5)
const TUFT_VARIANTS := 8
const TUFTS_PER_CELL := 7
## A cut tuft lies over in the mower's direction and disappears in this time.
const TUFT_FALL_TIME := 0.1

# ---------------------------------------------------------------- mower (§7)
const MOW_DECK_RADIUS := 0.7
## Time to reach full speed while the finger is held.
const THROTTLE_ACCEL_TIME := 0.4
## Natural coast-down once the finger lifts.
const THROTTLE_RELEASE_TIME := 0.55
const STEER_SMOOTHING := 9.0
## Turn radius grows with speed by this factor.
const STEER_SPEED_RADIUS_FACTOR := 0.45
## Drag distance, in screen points, before a touch counts as steering.
const DRAG_THRESHOLD_PT := 8.0

# ---------------------------------------------------------------- camera (§10)
const CAMERA_FOV := 55.0
## "mid preset (5.0 / 4.2 / 2.2)" from the brief. Which component is distance /
## height / look-at height is NOT stated — confirm before wiring.
const CAMERA_PRESET_MID := Vector3(5.0, 4.2, 2.2)
const CAMERA_POSITION_LERP := 4.0
const CAMERA_YAW_LERP := 2.6
## Bird's-eye reward transition at 100%.
const CAMERA_WIN_HEIGHT := 30.0
const CAMERA_WIN_LERP := 1.8

# ---------------------------------------------------------------- atmosphere (§13)
const FOG_NEAR := 26.0
const FOG_FAR := 70.0
## SSAO is never enabled: it does not work in the Mobile renderer. Fake AO
## (radial dark decals under objects) is the only method.
const USE_SSAO := false

# ---------------------------------------------------------------- feedback (§15)
const HAPTIC_LIGHT_MS := 10
const HAPTIC_MEDIUM_MS := 25

# ----------------------------------------------------------------------------
# MISSING — needs REFERENCE.md sections that are not in the repo yet:
#
#   §3   CellState enum members, mow() result types, secret placement algorithm
#   §4   the 4 striping tone colours (N lightest -> S darkest), tint map details
#   §5   tuft height/scale values, the wind sway formula
#   §6   push mower primitive dimensions and colours
#   §7   the exact throttle/steering formulas (only the constants above are known)
#   §10  what the camera preset triple means, and the near/far presets
#   §13  sun angle/colour/energy, ambient, sky gradient colours, fake AO size
#   §14  engine idle/moving volume+pitch targets, cut pitch range
#   §17  the canonical names for everything in this file
#   §18  performance guidance and the pitfall list (incl. the tint y-flip trap)
# ----------------------------------------------------------------------------
