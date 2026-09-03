class_name SaveStore
extends RefCounted
## Where the save actually lives (G16.2): a versioned JSON file, written
## atomically, with a backup, and a one-time migration from the ConfigFile
## that held everything before.
##
## THE PROBLEM. `user://settings.cfg` was rewritten in place on every single
## set_setting call. A crash, a full disk or a kill during that write left a
## truncated file, and ConfigFile.load on a truncated file fails — at which
## point every reader in the game defaulted its keys and a player who had
## rebuilt half a town opened the app to a fresh one. No backup, no recovery,
## no way to tell.
##
## THE SHAPE. Values are stored as `var_to_str` strings inside JSON, not as
## JSON values: JSON has one number type and no vectors, and a save that turns
## every int into a float and every Vector2 into an error is not a migration,
## it is a different bug. var_to_str round-trips every Variant exactly and the
## file stays readable in a text editor.
##
## THE WRITE. Serialize; write to a .tmp beside the file; copy the current file
## to .bak; rename .tmp over the file. Whatever happens mid-way, one of the
## three is whole, and load() tries them in order.

## Overridable so a test can point the store at scratch files.
static var PATH := "user://save.json"
static var BACKUP := "user://save.json.bak"
static var TMP := "user://save.json.tmp"
static var LEGACY := "user://settings.cfg"

const FORMAT := 2

var _data: Dictionary = {}
## Where the data came from on load, for the log and for the test.
var loaded_from := ""


func get_value(section: String, key: String, default: Variant) -> Variant:
	var sec: Variant = _data.get(section, null)
	if sec is Dictionary and (sec as Dictionary).has(key):
		return (sec as Dictionary)[key]
	return default


func has_value(section: String, key: String) -> bool:
	var sec: Variant = _data.get(section, null)
	return sec is Dictionary and (sec as Dictionary).has(key)


func set_value(section: String, key: String, value: Variant) -> void:
	if not _data.has(section):
		_data[section] = {}
	(_data[section] as Dictionary)[key] = value


func sections() -> Array:
	return _data.keys()


func clear() -> void:
	_data.clear()


## Primary, then backup, then the pre-G16.2 ConfigFile. Returns OK if anything
## was loaded or there was nothing to load; an error only if every candidate
## existed and every one was unreadable.
func load() -> Error:
	loaded_from = ""
	_data.clear()
	if _read_json(PATH):
		loaded_from = "primary"
		return OK
	var primary_present := FileAccess.file_exists(PATH)
	if _read_json(BACKUP):
		loaded_from = "backup"
		# The primary was missing or corrupt; put a good one back.
		save()
		return OK
	if FileAccess.file_exists(LEGACY) and _read_legacy():
		loaded_from = "legacy"
		save()
		return OK
	if primary_present or FileAccess.file_exists(BACKUP):
		return ERR_FILE_CORRUPT
	loaded_from = "fresh"
	return OK


func _read_json(path: String) -> bool:
	if not FileAccess.file_exists(path):
		return false
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		return false
	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary):
		return false
	var root := parsed as Dictionary
	var sections_in: Variant = root.get("sections", null)
	if not (sections_in is Dictionary):
		return false
	var out := {}
	for section: Variant in sections_in:
		var keys: Variant = (sections_in as Dictionary)[section]
		if not (keys is Dictionary):
			continue
		var sec := {}
		for key: Variant in keys:
			sec[str(key)] = str_to_var(str((keys as Dictionary)[key]))
		out[str(section)] = sec
	_data = out
	return true


func _read_legacy() -> bool:
	var cfg := ConfigFile.new()
	if cfg.load(LEGACY) != OK:
		return false
	for section: String in cfg.get_sections():
		for key: String in cfg.get_section_keys(section):
			set_value(section, key, cfg.get_value(section, key))
	return true


## Atomic: tmp, backup, rename. Never writes over the live file in place.
func save() -> Error:
	var sections_out := {}
	for section: Variant in _data:
		var keys := {}
		for key: Variant in (_data[section] as Dictionary):
			keys[str(key)] = var_to_str((_data[section] as Dictionary)[key])
		sections_out[str(section)] = keys
	var text := JSON.stringify({"format": FORMAT, "sections": sections_out}, "\t")
	var f := FileAccess.open(TMP, FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_string(text)
	f.close()
	var dir := DirAccess.open(TMP.get_base_dir())
	if dir == null:
		return ERR_CANT_OPEN
	if FileAccess.file_exists(PATH):
		dir.copy(PATH, BACKUP)
	var err := dir.rename(TMP, PATH)
	if err != OK:
		return err
	return OK


## Everything gone, including the backup and the legacy file. The caller decides
## what to write back (GameState keeps the install id and the locale).
func erase() -> void:
	_data.clear()
	for path: String in [PATH, BACKUP, TMP, LEGACY]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)


## The whole save as text, for a cloud provider to carry (G16.2). The same
## bytes save() writes.
func export_text() -> String:
	save()
	return FileAccess.get_file_as_string(PATH) if FileAccess.file_exists(PATH) else ""
