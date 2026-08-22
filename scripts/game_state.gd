extends Node
## GameState autoload: run-level state and the persisted settings file.
##
## The lawn data model itself is REFERENCE.md §3 and lands with Sprint G1; this
## holds only what is not spec-dependent — the run timer used by the completion
## panel, and the mute preference the brief requires to persist via ConfigFile.

signal run_started()
signal run_finished(elapsed: float)

const SETTINGS_PATH := "user://settings.cfg"

var elapsed: float = 0.0
var is_running: bool = false

var _config := ConfigFile.new()


func _ready() -> void:
	_load_settings()


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


func _load_settings() -> void:
	var err := _config.load(SETTINGS_PATH)
	if err != OK and err != ERR_FILE_NOT_FOUND:
		push_warning("GameState: could not read %s (error %d)" % [SETTINGS_PATH, err])
