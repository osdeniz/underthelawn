extends Node
## GameState autoload: run-level state and the persisted settings file.
##
## The lawn data model itself is REFERENCE.md §3 and lands with Sprint G1; this
## holds only what is not spec-dependent — the run timer used by the completion
## panel, and the mute preference the brief requires to persist via ConfigFile.

signal run_started()
signal run_finished(elapsed: float)

const SETTINGS_PATH := "user://settings.cfg"
## The save file's format version (G14.1).
##
## This is the one piece of desktop-readiness that CANNOT be added later: once
## players have save files, a file with no version in it is indistinguishable
## from a future format that happens to lack the key. Stamping it now means any
## later change to how progress is stored can be migrated instead of silently
## misread — or worse, wiped.
##
## Bump this when the MEANING of stored keys changes, and add a branch to
## `_migrate`. Adding a brand-new key needs no bump: readers already default.
const SAVE_VERSION := 1
const META := "meta"
## Whether the one-time orientation has been shown (G15). Stored, not a runtime
## flag: it has to survive the app being closed mid-search, or a player who
## quits during their first lawn gets the whole thing again.
const FIRST_RUN_KEY := "orientation_done"
## G9 currency section. Nowhere to spend it until G10's Workshop, so the total is
## the only thing stored.
const ECONOMY := "economy"

var elapsed: float = 0.0
var is_running: bool = false

var _config := ConfigFile.new()
var _session_id := ""
var _session_ended_sent := false


func _ready() -> void:
	_load_settings()
	Analytics.track(AnalyticsEvents.SESSION_STARTED, {})


## Fires once, best-effort, on whatever signal the platform actually gives us
## for "the player is gone" — a clean quit on desktop, backgrounding on
## mobile (where a true quit notification usually never arrives at all).
## Firing on background rather than waiting for a quit that may not come is
## the same call every mobile analytics SDK makes, for the same reason.
func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_WM_WINDOW_FOCUS_OUT, \
		NOTIFICATION_WM_CLOSE_REQUEST:
			if not _session_ended_sent:
				_session_ended_sent = true
				Analytics.track(AnalyticsEvents.SESSION_ENDED, {})


func _process(delta: float) -> void:
	if is_running:
		elapsed += delta


func start_run() -> void:
	elapsed = 0.0
	is_running = true
	run_started.emit()


func finish_run() -> void:
	if not is_running:
		return
	is_running = false
	run_finished.emit(elapsed)


## "1:07" style, for the completion panel.
func format_elapsed() -> String:
	var total := int(elapsed)
	return "%d:%02d" % [total / 60, total % 60]


# ---------------------------------------------------------------- settings

func get_setting(section: String, key: String, default: Variant) -> Variant:
	return _config.get_value(section, key, default)


func set_setting(section: String, key: String, value: Variant) -> void:
	_config.set_value(section, key, value)
	var err := _config.save(SETTINGS_PATH)
	if err != OK:
		push_warning("GameState: could not save %s (error %d)" % [SETTINGS_PATH, err])
		Analytics.log_error("save_write_failed", "error %d" % err, "game_state")


func _load_settings() -> void:
	var err := _config.load(SETTINGS_PATH)
	if err != OK and err != ERR_FILE_NOT_FOUND:
		push_warning("GameState: could not read %s (error %d)" % [SETTINGS_PATH, err])
		Analytics.log_error("save_read_failed", "error %d" % err, "game_state")
		return
	_migrate()


## Brings an older save up to SAVE_VERSION. A file with no version key is
## either brand new or predates versioning; both are treated as version 0 and
## walked forward through every step, so a player who has been on an old build
## keeps their town.
func _migrate() -> void:
	var found := int(_config.get_value(META, "save_version", 0))
	if found == SAVE_VERSION:
		return
	if found > SAVE_VERSION:
		# A newer build wrote this. Refuse to rewrite it rather than mangling
		# keys this build does not understand.
		push_warning("GameState: save is version %d, this build knows %d"
			% [found, SAVE_VERSION])
		Analytics.log_error("save_version_too_new",
			"file=%d build=%d" % [found, SAVE_VERSION], "game_state")
		return
	# while-loop rather than a match, so several versions can be crossed in one
	# launch by a player who skipped updates.
	while found < SAVE_VERSION:
		match found:
			0:
				# 0 -> 1: versioning introduced. Nothing to rewrite; the file's
				# existing keys already mean what version 1 means.
				pass
		found += 1
	_config.set_value(META, "save_version", SAVE_VERSION)
	var err := _config.save(SETTINGS_PATH)
	if err != OK:
		push_warning("GameState: could not stamp save version (error %d)" % err)
		Analytics.log_error("save_write_failed", "error %d" % err, "game_state")


## True until the player has been shown the first-run orientation once.
func is_first_run() -> bool:
	return not bool(get_setting(META, FIRST_RUN_KEY, false))


## A random anonymous id, generated once and persisted, so analytics can tell
## two sessions from the same install apart from two different installs
## without carrying anything that identifies the player.
func install_id() -> String:
	var existing := str(get_setting(META, "install_id", ""))
	if existing != "":
		return existing
	var bytes := PackedByteArray()
	for i in 16:
		bytes.append(randi() % 256)
	var id := bytes.hex_encode()
	set_setting(META, "install_id", id)
	return id


## A fresh random id every launch (unlike install_id, never persisted) — one
## Godot process run is one session. Good enough for "how long did this
## session last" via first/last event timestamp even on platforms that never
## give a clean session_ended.
func session_id() -> String:
	if _session_id == "":
		var bytes := PackedByteArray()
		for i in 16:
			bytes.append(randi() % 256)
		_session_id = bytes.hex_encode()
	return _session_id


func mark_orientation_done() -> void:
	set_setting(META, FIRST_RUN_KEY, true)


## Which format the file on disk is in. Zero means unversioned or absent.
func save_version() -> int:
	return int(_config.get_value(META, "save_version", 0))


# ---------------------------------------------------------------- scrap (G9)

func scrap_total() -> int:
	# A fresh save picks up DEV_STARTING_SCRAP once, so debug builds can reach
	# the workshop and the town without grinding there first.
	if not _config.has_section_key(ECONOMY, "scrap"):
		set_setting(ECONOMY, "scrap", GameConfig.DEV_STARTING_SCRAP)
	return int(get_setting(ECONOMY, "scrap", 0))


## Chapter payouts only ever add. Spending arrives with G10's Workshop.
func add_scrap(amount: int) -> int:
	var total := scrap_total() + maxi(amount, 0)
	set_setting(ECONOMY, "scrap", total)
	return total


## Takes `amount` off the wallet and returns what was actually taken, which is
## never more than the player had. Three call sites were each writing
## `set_setting("economy", "scrap", scrap_total() - cost)` by hand, and none of
## them clamped — a cost larger than the wallet wrote a NEGATIVE balance (G13).
func spend_scrap(amount: int) -> int:
	var take := clampi(amount, 0, scrap_total())
	set_setting(ECONOMY, "scrap", scrap_total() - take)
	return take
