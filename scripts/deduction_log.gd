class_name DeductionLog
extends RefCounted
## Two finds that mean one thing (G48).
##
## The game asked the player to collect evidence for three cases and never
## once asked them to think about it: the Journal was a list of things owned.
## Now two discoveries can be put together. If they say something, the Marshal
## says what — and the sentence is kept, in his voice, in the notes.
##
## A piece of evidence is a CHAPTER and an id, never an id alone: `prints`,
## `stones`, `boot` and `ribbon` all appear in more than one chapter, and a
## sock at the river crossing is not a sock in the orchard.
##
## Nothing here gates anything. A wrong pair costs nothing but a flat answer,
## and a case can be closed without a single deduction; what they buy is the
## story of what you worked out, written down.

const SECTION := "links"


## "chapter/id", the way the story file names one side of a link.
static func piece(variant_id: String, evidence_id: String) -> String:
	return "%s/%s" % [variant_id, evidence_id]


## A node name for one piece. "/" is a path separator, so a raw "chapter/id"
## cannot be a node's name and could not be found again (G48).
static func node_name(side: String) -> String:
	return "Pick_" + side.replace("/", "-")


## Order never matters: the player taps two things, not a first and a second.
static func key(a: String, b: String) -> String:
	return "%s|%s" % [a, b] if a <= b else "%s|%s" % [b, a]


static func links() -> Array:
	return Story.list("links")


## The link joining these two pieces, or {} when they say nothing together.
static func find_link(a: String, b: String) -> Dictionary:
	for any: Variant in links():
		var link: Dictionary = any
		var side_a := str(link.get("a", ""))
		var side_b := str(link.get("b", ""))
		if (side_a == a and side_b == b) or (side_a == b and side_b == a):
			return link
	return {}


static func is_made(a: String, b: String) -> bool:
	return bool(GameState.get_setting(SECTION, key(a, b), false))


static func make(a: String, b: String) -> void:
	GameState.set_setting(SECTION, key(a, b), true)


static func made_count() -> int:
	var n := 0
	for any: Variant in links():
		var link: Dictionary = any
		if is_made(str(link.get("a", "")), str(link.get("b", ""))):
			n += 1
	return n


static func total() -> int:
	return links().size()


## The deductions already worked out, in the order the story file lists them,
## so the notes read as a case building rather than as a tap history.
static func made_links() -> Array:
	var out: Array = []
	for any: Variant in links():
		var link: Dictionary = any
		if is_made(str(link.get("a", "")), str(link.get("b", ""))):
			out.append(link)
	return out


## Which chapters a link's two sides belong to, for naming it in the notes.
static func chapter_of(side: String) -> String:
	var parts := side.split("/")
	return str(parts[0]) if parts.size() > 0 else ""


static func evidence_of(side: String) -> String:
	var parts := side.split("/")
	return str(parts[1]) if parts.size() > 1 else ""


## The name the Journal prints for one side: the evidence's own name, found by
## asking its chapter's variant rather than by keeping a second copy of it.
static func name_of(side: String) -> String:
	var variant := LevelVariant.of(chapter_of(side))
	var wanted := evidence_of(side)
	for slot in variant.evidence_count():
		var info := variant.evidence_info(slot)
		if str(info.get("id", "")) == wanted:
			return str(info.get("name", wanted))
	return wanted


static func reset() -> void:
	for any: Variant in links():
		var link: Dictionary = any
		GameState.set_setting(SECTION,
			key(str(link.get("a", "")), str(link.get("b", ""))), false)
