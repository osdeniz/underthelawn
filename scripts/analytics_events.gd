class_name AnalyticsEvents
extends RefCounted
## Every event name Analytics.track() is called with, in one place (G14.6).
## Before this, the 21 names in use lived as raw string literals scattered
## across ten files — a typo in one call site would silently create a new,
## disconnected event series with no error and no way to notice from the
## code. Call sites should never write an event name as a string literal;
## add a constant here instead. Metadata payload shape stays free-form
## (Dictionary), matching the backend's schemaless `props` column.

# ---------------------------------------------------------------- session
const SESSION_STARTED := "session_started"
const SESSION_ENDED := "session_ended"

# ---------------------------------------------------------------- errors
## metadata: {error_type, error_message, screen, stack (optional)}
const ERROR_OCCURRED := "error_occurred"

# ---------------------------------------------------------------- case flow
const CHAPTER_STARTED := "chapter_started"
const CHAPTER_COMPLETED := "chapter_completed"
const CASE_COMPLETED := "case_completed"
const EVIDENCE_FOUND := "evidence_found"
const ECHO_FOUND := "echo_found"
const EVIDENCE_LOCATION_PANNED := "evidence_location_panned"
const SCENT_SHOWN := "scent_shown"

# ---------------------------------------------------------------- harvest
const HARVEST_OFFERED := "harvest_offered"
const HARVEST_STARTED := "harvest_started"
const HARVEST_COMPLETED := "harvest_completed"

# ---------------------------------------------------------------- workshop / town economy
const MOWER_UNLOCKED := "mower_unlocked"
const MOWER_UPGRADED := "mower_upgraded"
const RESTORE_BOUGHT := "restore_bought"
const RESTORE_TIER2_UNLOCKED := "restore_tier2_unlocked"
const RESTORE_ANIMATION_WATCHED := "restore_animation_watched"
const RESTORE_ANIMATION_SKIPPED := "restore_animation_skipped"
const STATION_COMPLETED := "station_completed"

# ---------------------------------------------------------------- objectives
const OBJECTIVE_VIEWED := "objective_viewed"
const OBJECTIVE_COMPLETED := "objective_completed"

# ---------------------------------------------------------------- map / hub
const MAP_OPENED := "map_opened"
const MAP_PIN_TAPPED := "map_pin_tapped"
const WORLD_MAP_VIEWED := "world_map_viewed"

# ---------------------------------------------------------------- first run
# ---------------------------------------------------------------- quiet scenes
## metadata: {scene, amount} — what a scripted road scene cost the player.
const TOLL_PAID := "toll_paid"

const ORIENTATION_SHOWN := "orientation_shown"
const ORIENTATION_HINT_MARKED := "orientation_hint_marked"
