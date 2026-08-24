class_name Dialogue
extends RefCounted
## Loader for data/dialogue.json — the one conversation format in the game.
##
## A conversation is a list of entries. An entry is either a spoken line
## `{speaker, text}` or a flavour choice `{choice: {options: [...]}}`. A choice
## never branches: picking an option appends its single reaction line and the
## conversation continues. That keeps writing cheap and keeps every caller's
## control flow linear, which is why brief, debrief and town chatter can all be
## the same data.
##
## `text` values are translation keys; `speaker` ids double as portrait file
## names (textures/portraits/<id>.png).

const PATH := "res://data/dialogue.json"

static var _data: Dictionary = {}
static var _warned := false


static func data() -> Dictionary:
	if not _data.is_empty():
		return _data
	if not FileAccess.file_exists(PATH):
		_warn("data/dialogue.json yok - diyaloglar bos")
		return _data
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if parsed is Dictionary:
		_data = parsed
	else:
		_warn("data/dialogue.json cozumlenemedi")
	return _data


## The entry list for a named conversation, or [] if it does not exist.
static func conversation(id: String) -> Array:
	var all: Variant = data().get("conversations", {})
	if all is Dictionary and (all as Dictionary).has(id):
		var convo: Variant = (all as Dictionary)[id]
		if convo is Dictionary:
			return (convo as Dictionary).get("lines", [])
	return []


## Optional accept-button label key for a conversation (the briefing has one;
## town chatter does not).
static func accept_key(id: String) -> String:
	var all: Variant = data().get("conversations", {})
	if all is Dictionary and (all as Dictionary).has(id):
		var convo: Variant = (all as Dictionary)[id]
		if convo is Dictionary:
			return str((convo as Dictionary).get("accept", ""))
	return ""


## Town chatter for one person, picking the highest variant whose `min_done` the
## player has reached — so the town reacts to case progress without any extra
## bookkeeping at the call site.
static func town_lines(person_id: String, chapters_done: int) -> Array:
	var town: Variant = data().get("town", {})
	if not (town is Dictionary) or not (town as Dictionary).has(person_id):
		return []
	var variants: Variant = (town as Dictionary)[person_id]
	if not (variants is Array):
		return []
	var best: Array = []
	var best_min := -1
	for variant: Dictionary in variants:
		var needs := int(variant.get("min_done", 0))
		if needs <= chapters_done and needs > best_min:
			best_min = needs
			best = variant.get("lines", [])
	return best


static func speakers() -> Array:
	return data().get("speakers", [])


static func _warn(message: String) -> void:
	if _warned:
		return
	_warned = true
	push_warning("[Dialogue] " + message)
	print("[Dialogue] " + message)
