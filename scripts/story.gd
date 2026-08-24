class_name Story
extends RefCounted
## Every player-facing narrative string, loaded once from data/story.json.
##
## G7 gives the game its case framing, and G11 will drive whole chapters from
## data. Keeping the text in one file (never in scene .tscn text properties or
## inline in scripts) means a new case is a data change, not a code change.
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


static func text(path: String, fallback := "") -> String:
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
