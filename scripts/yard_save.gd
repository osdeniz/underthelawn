class_name YardSave
extends RefCounted
## The yard you were in the middle of (G42).
##
## Until now a run existed only in memory: a phone call, a low battery or the
## OS reclaiming the app threw away every cut, every find and the clock with
## them. On a game whose sessions are one yard long that is the whole session.
##
## So an open yard writes a small snapshot — the cut bitmap, where the evidence
## is and what has been carried out of it, the clock, the machine and where it
## stands — every `YARD_SAVE_EVERY` seconds and once more the moment the app
## goes to the background. On the next launch CONTINUE puts you back in it.
##
## What is NOT kept is anything cosmetic: which small surprises had fired,
## where the rain was in its loop, the animals' positions. Those are set
## dressing, and a resume that rebuilt them exactly would be a bigger save for
## no gain the player can name.

const SECTION := "yard"
const KEY := "snapshot"
## Bumped when the shape of the snapshot changes, so an old one is dropped
## rather than half-applied.
const VERSION := 1


static func has_snapshot() -> bool:
	var snap := load_snapshot()
	return not snap.is_empty()


static func variant_id() -> String:
	return str(load_snapshot().get("variant", ""))


static func load_snapshot() -> Dictionary:
	var raw: Variant = GameState.get_setting(SECTION, KEY, {})
	if not (raw is Dictionary):
		return {}
	var snap: Dictionary = raw
	if int(snap.get("version", 0)) != VERSION:
		return {}
	if str(snap.get("variant", "")) == "":
		return {}
	return snap


static func store(snap: Dictionary) -> void:
	if snap.is_empty():
		return
	snap["version"] = VERSION
	GameState.set_setting(SECTION, KEY, snap)


static func clear() -> void:
	if GameState.get_setting(SECTION, KEY, {}) is Dictionary \
			and (GameState.get_setting(SECTION, KEY, {}) as Dictionary).is_empty():
		return
	GameState.set_setting(SECTION, KEY, {})


## PackedByteArrays do not survive a JSON round trip; base64 does.
static func pack(bytes: PackedByteArray) -> String:
	return Marshalls.raw_to_base64(bytes)


static func unpack(text: String, size: int) -> PackedByteArray:
	var bytes := Marshalls.base64_to_raw(text)
	# A snapshot from a different grid is not a snapshot for this yard.
	if bytes.size() != size:
		return PackedByteArray()
	return bytes
