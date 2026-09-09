class_name Achievements
extends RefCounted
## The records (G33, gamification sprint 3): things the player has done, written
## down in the Journal — no popup, no badge, no score. A finished yard checks
## the list; anything newly true gets one line on the panel ("Written in the
## Journal: …") and a dated entry in the Journal's RECORDS tab, where the ones
## not yet done sit greyed with the sentence that says what they are, so the
## list is a set of quiet invitations rather than a scoreboard.
##
## Every condition reads state that already exists; the list stores only the
## day each one came true.

const SECTION := "achievements"

## id → [name key, line key]. The check is `_holds(id)`.
const LIST: Array[Array] = [
	["first_yard", "ACH_FIRST_YARD", "ACH_FIRST_YARD_LINE"],
	["dog_named", "ACH_DOG_NAMED", "ACH_DOG_NAMED_LINE"],
	["case_one", "ACH_CASE_ONE", "ACH_CASE_ONE_LINE"],
	["thorough_3", "ACH_THOROUGH_3", "ACH_THOROUGH_3_LINE"],
	["rows_3", "ACH_ROWS_3", "ACH_ROWS_3_LINE"],
	["rings_1", "ACH_RINGS_1", "ACH_RINGS_1_LINE"],
	["cross_1", "ACH_CROSS_1", "ACH_CROSS_1_LINE"],
	["postcards_5", "ACH_POSTCARDS_5", "ACH_POSTCARDS_5_LINE"],
	["every_field", "ACH_EVERY_FIELD", "ACH_EVERY_FIELD_LINE"],
	["echoes_all", "ACH_ECHOES_ALL", "ACH_ECHOES_ALL_LINE"],
	["town_rebuilt", "ACH_TOWN_REBUILT", "ACH_TOWN_REBUILT_LINE"],
	["surprises_all", "ACH_SURPRISES_ALL", "ACH_SURPRISES_ALL_LINE"],
	["deduction", "ACH_DEDUCTION", "ACH_DEDUCTION_LINE"],
	["lake", "ACH_LAKE", "ACH_LAKE_LINE"],
	["night", "ACH_NIGHT", "ACH_NIGHT_LINE"],
]


static func ids() -> Array[String]:
	var out: Array[String] = []
	for row: Array in LIST:
		out.append(str(row[0]))
	return out


static func name_key(id: String) -> String:
	for row: Array in LIST:
		if str(row[0]) == id:
			return str(row[1])
	return ""


static func line_key(id: String) -> String:
	for row: Array in LIST:
		if str(row[0]) == id:
			return str(row[2])
	return ""


static func is_earned(id: String) -> bool:
	return str(GameState.get_setting(SECTION, id, "")) != ""


## The date it came true, "" when it has not.
static func earned_on(id: String) -> String:
	return str(GameState.get_setting(SECTION, id, ""))


static func earned_count() -> int:
	var n := 0
	for id in ids():
		if is_earned(id):
			n += 1
	return n


## Checks every record not yet earned; returns the ids that came true now.
static func evaluate() -> Array[String]:
	var fresh: Array[String] = []
	for id in ids():
		if is_earned(id):
			continue
		if _holds(id):
			GameState.set_setting(SECTION, id, Time.get_date_string_from_system())
			fresh.append(id)
	return fresh


static func reset() -> void:
	for id in ids():
		GameState.set_setting(SECTION, id, "")


static func _holds(id: String) -> bool:
	match id:
		"first_yard":
			return ChapterProgress.done_count() >= 1
		"dog_named":
			return DogName.has_name()
		"case_one":
			return bool(GameState.get_setting("story", "case01_closed", false))
		"thorough_3":
			return ThoroughStreak.best() >= 3
		"rows_3":
			return MowPattern.count(MowPattern.ROWS) >= 3
		"rings_1":
			return MowPattern.count(MowPattern.RINGS) >= 1
		"cross_1":
			return MowPattern.count(MowPattern.CROSS) >= 1
		"postcards_5":
			return Postcard.all().size() >= 5
		"every_field":
			for vid: String in GameConfig.HARVEST_VARIANTS:
				if not HarvestLog.field_cut(vid):
					return false
			return true
		"echoes_all":
			return EchoLog.total() > 0 and EchoLog.found_count() >= EchoLog.total()
		"town_rebuilt":
			var p := RestoreBoard.town_ready_progress()
			return p.y > 0 and p.x >= p.y
		"surprises_all":
			for sid in Surprises.ALL:
				if not Surprises.seen(sid):
					return false
			return true
		"deduction":
			return DeductionLog.made_count() >= 1
		"lake":
			return ChapterProgress.is_done("ch04_flooded")
		"night":
			return ChapterProgress.is_done("ch08_cellar") or ChapterProgress.is_done("ch25_night_watch")
	return false
