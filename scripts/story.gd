class_name Story
extends RefCounted
## The narrative STRUCTURE, loaded once from data/story.json.
##
## The json holds translation KEYS, not sentences. `text()` runs the key through
## the TranslationServer, so the sentences come from i18n/strings.csv and adding
## a language is a new column there — never an edit to the json or to a scene.
## Values that are not language-dependent (image paths, emoji) are read with
## `raw()` instead.
##
## G11 will drive whole chapters from data shaped like this, so keep the nesting
## rather than flattening it.
##
## Static and cached, so it needs no autoload and no project.godot entry.

const PATH := "res://data/story.json"

static var _data: Dictionary = {}
static var _warned := false


## The whole story dictionary; empty if the file is missing or malformed.
static func data() -> Dictionary:
	if not _data.is_empty():
		return _data
	if not FileAccess.file_exists(PATH):
		_warn("data/story.json yok - anlati metinleri bos")
		return _data
	var text := FileAccess.get_file_as_string(PATH)
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Dictionary:
		_data = parsed
	else:
		_warn("data/story.json cozumlenemedi - anlati metinleri bos")
	return _data


## Dotted lookup: get("briefing.body"). Array indices work too: "intro.cards.0".
## Returns `fallback` for any missing step, so a half-written story file
## degrades to placeholder text instead of crashing the run.
static func get_value(path: String, fallback: Variant = "") -> Variant:
	var node: Variant = data()
	for step in path.split("."):
		if node is Dictionary and (node as Dictionary).has(step):
			node = (node as Dictionary)[step]
		elif node is Array and step.is_valid_int():
			var arr := node as Array
			var i := step.to_int()
			if i < 0 or i >= arr.size():
				return fallback
			node = arr[i]
		else:
			return fallback
	return node


## The translated sentence for the key stored at `path`. An unknown key comes
## back from the TranslationServer unchanged, which is exactly what you want to
## see on screen while a language is still being filled in.
static func text(path: String, fallback := "") -> String:
	var key := raw(path, fallback)
	if key == "":
		return fallback
	return TranslationServer.translate(key)


## The literal value at `path`, untranslated: image paths, emoji, ids.
static func raw(path: String, fallback := "") -> String:
	var value: Variant = get_value(path, fallback)
	return str(value) if value != null else fallback


static func list(path: String) -> Array:
	var value: Variant = get_value(path, [])
	return value as Array if value is Array else []


static func _warn(message: String) -> void:
	if _warned:
		return
	_warned = true
	push_warning("[Story] " + message)
	print("[Story] " + message)
