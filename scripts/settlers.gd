class_name Settlers
extends RefCounted
## People who turn up wanting to stay (G14.13).
##
## A settler is a DECISION, not a reward. Everyone taken in eats every day for
## the rest of the game, and pays for that by changing one number the game
## already had — the food a yard gives, the scrap it gives, what the town eats,
## what a restoration costs. Taking everyone in is a choice to run a bigger,
## hungrier, more productive town; turning them away is a choice to stay small.
##
## Nothing here is generated: the roster is data, the effects are four named
## branches, and the answer to "why is my food going down faster" is always a
## name the player agreed to.

const PATH := "res://data/settlers.json"
const SECTION := "settlers"

static var _data: Dictionary = {}
static var _warned := false


static func all() -> Array:
	if _data.is_empty():
		if not FileAccess.file_exists(PATH):
			_warn("data/settlers.json yok")
			return []
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		if parsed is Dictionary:
			_data = parsed
		else:
			_warn("data/settlers.json cozumlenemedi")
			return []
	var list: Variant = _data.get("settlers", [])
	return list if list is Array else []


static func of(id: String) -> Dictionary:
	for any: Variant in all():
		var spec: Dictionary = any
		if str(spec.get("id", "")) == id:
			return spec
	return {}


# ---------------------------------------------------------------- state

## "" = never answered, "yes" = living here, "no" = turned away.
static func answer(id: String) -> String:
	return str(GameState.get_setting(SECTION, id, ""))


static func accepted() -> Array:
	var out: Array = []
	for any: Variant in all():
		var spec: Dictionary = any
		if answer(str(spec.get("id", ""))) == "yes":
			out.append(spec)
	return out


## The next person waiting at the edge of town, or {} if nobody is. One at a
## time on purpose: two strangers in one modal is a menu, one is a decision.
static func pending() -> Dictionary:
	var done := ChapterProgress.done_count()
	for any: Variant in all():
		var spec: Dictionary = any
		if answer(str(spec.get("id", ""))) != "":
			continue
		if done >= int(spec.get("after", 0)):
			return spec
	return {}


static func accept(id: String) -> void:
	GameState.set_setting(SECTION, id, "yes")
	Analytics.track("settler_accepted", {"id": id})


static func reject(id: String) -> void:
	GameState.set_setting(SECTION, id, "no")
	Analytics.track("settler_rejected", {"id": id})


static func reset() -> void:
	for any: Variant in all():
		GameState.set_setting(SECTION, str((any as Dictionary).get("id", "")), "")


# ---------------------------------------------------------------- trades

## Extra food a yard gives, as a multiplier on what it hid.
static func food_yield() -> float:
	return 1.0 + _bonus("food_yield")


## Extra scrap, the same way.
static func scrap_yield() -> float:
	return 1.0 + _bonus("scrap_yield")


## Food per day a cook saves off the town's bill.
static func upkeep_saved() -> int:
	return int(round(_bonus("upkeep")))


## Share taken off a restoration's price.
static func build_discount() -> float:
	return minf(_bonus("build_discount"), 0.6)


static func _bonus(trade: String) -> float:
	var total := 0.0
	for any: Variant in accepted():
		var spec: Dictionary = any
		if str(spec.get("trade", "")) == trade:
			total += float(spec.get("value", 0.0))
	return total


## One line of what this person changes, for the arrival card.
static func effect_line(spec: Dictionary) -> String:
	var value := float(spec.get("value", 0.0))
	match str(spec.get("trade", "")):
		"food_yield":
			return tr_key("SET_EFFECT_FOOD").format({"pct": int(round(value * 100.0))})
		"scrap_yield":
			return tr_key("SET_EFFECT_SCRAP").format({"pct": int(round(value * 100.0))})
		"upkeep":
			return tr_key("SET_EFFECT_UPKEEP").format({"n": int(round(value))})
		"build_discount":
			return tr_key("SET_EFFECT_BUILD").format({"pct": int(round(value * 100.0))})
	return ""


static func tr_key(key: String) -> String:
	return TranslationServer.translate(key)


static func _warn(message: String) -> void:
	if _warned:
		return
	_warned = true
	push_warning("[Settlers] " + message)
	print("[Settlers] " + message)
