extends Node
## G10: the workshop economy and the evidence-board data contract.

var _fails := 0


func _ready() -> void:
	Garage.reset()
	GameState.set_setting("economy", "scrap", 0)

	# --- unlock table sanity
	ck("push bedava", Garage.unlock_cost(GameConfig.MOWER_PUSH) == 0, "")
	ck("push acik", Garage.is_unlocked(GameConfig.MOWER_PUSH), "")
	ck("robot kilitli", not Garage.is_unlocked(GameConfig.MOWER_ROBOT), "")
	ck("robot 300", Garage.unlock_cost(GameConfig.MOWER_ROBOT) == 300, "")
	ck("traktor 800", Garage.unlock_cost(GameConfig.MOWER_TRACTOR) == 800, "")
	ck("blade 1500", Garage.unlock_cost(GameConfig.MOWER_BLADE) == 1500, "")

	# --- the Robot target must be REACHABLE: two full early chapters must fund
	# it, or the first purchase is a grind wall.
	var two_chapters := 0
	for id in ["ch01_aldridge", "ch02_neighbor"]:
		var v := LevelVariant.of(id)
		var expected_ground := float(v.scrap_budget) \
			* float(GameConfig.SCRAP_PICKUP_MIN + GameConfig.SCRAP_PICKUP_MAX) * 0.5
		var pay := ScrapField.payout(int(expected_ground), 1.0, v.scrap_budget)
		two_chapters += int(pay["total"])
	ck("2 bolum robotu fonluyor", two_chapters >= 300,
		"%d / 300" % two_chapters)

	# --- purchase flow: insufficient, then funded, then deducted
	ck("parasiz alim reddedilir", not Garage.buy_unlock(GameConfig.MOWER_ROBOT), "")
	GameState.set_setting("economy", "scrap", 350)
	ck("parali alim gecer", Garage.buy_unlock(GameConfig.MOWER_ROBOT), "")
	ck("para dustu", GameState.scrap_total() == 50, str(GameState.scrap_total()))
	ck("robot artik acik", Garage.is_unlocked(GameConfig.MOWER_ROBOT), "")
	ck("tekrar alinamaz", not Garage.buy_unlock(GameConfig.MOWER_ROBOT), "")

	# --- upgrades: three tiers, costs from the table, effects compound
	GameState.set_setting("economy", "scrap", 5000)
	var costs: Array = GameConfig.UPGRADE_COSTS["push"]
	for step in GameConfig.UPGRADE_MAX_TIER:
		ck("push kademe %d maliyeti" % step,
			Garage.next_upgrade_cost(GameConfig.MOWER_PUSH) == int(costs[step]),
			str(Garage.next_upgrade_cost(GameConfig.MOWER_PUSH)))
		ck("push kademe %d alimi" % step,
			Garage.buy_upgrade(GameConfig.MOWER_PUSH), "")
	ck("push tam gelismis", Garage.next_upgrade_cost(GameConfig.MOWER_PUSH) == -1, "")
	ck("push tavan asilamaz", not Garage.buy_upgrade(GameConfig.MOWER_PUSH), "")
	ck("push hizi +%30",
		is_equal_approx(Garage.speed_multiplier(GameConfig.MOWER_PUSH), 1.30),
		str(Garage.speed_multiplier(GameConfig.MOWER_PUSH)))

	# --- blade upgrade grows the disk, not the speed
	GameState.set_setting("garage", "blade_unlocked", true)
	Garage.buy_upgrade(GameConfig.MOWER_BLADE)
	ck("blade hizi degismez",
		is_equal_approx(Garage.speed_multiplier(GameConfig.MOWER_BLADE), 1.0), "")
	Garage.apply_blade_scale()
	ck("blade diski buyudu", is_equal_approx(GameConfig.BLADE_SCALE, 1.15),
		str(GameConfig.BLADE_SCALE))

	# --- G12.7 restoration tiers
	RestoreBoard.reset()
	GameState.set_setting("economy", "scrap", 20000)
	ck("10 proje", RestoreBoard.projects().size() == 10,
		str(RestoreBoard.projects().size()))
	# Tier 2 is locked until enough tier-1 work is done, and a locked project
	# cannot be bought even with money in hand.
	ck("tier2 basta kilitli", RestoreBoard.is_locked("station"), "")
	ck("kilitliyken alinamaz", not RestoreBoard.buy("station"), "")
	ck("tier1 acik", not RestoreBoard.is_locked("swing"), "")
	ck("kilit sebebi var", RestoreBoard.lock_reason("station") != "", "")
	RestoreBoard.buy("swing")
	ck("1 tier1 sonrasi hala kilitli", RestoreBoard.is_locked("station"), "")
	RestoreBoard.buy("lantern")
	ck("2 tier1 sonrasi acildi", not RestoreBoard.is_locked("station"), "")
	ck("tier2 acik bayragi", RestoreBoard.tier2_open(), "")

	# The barn hangs off the farm regardless of tier progress.
	ck("ambar ciftlige bagli kilitli", RestoreBoard.is_locked("barn"), "")
	ck("ciftlik acik", not RestoreBoard.is_locked("farm"), "")
	RestoreBoard.buy("farm")
	ck("ciftlikten sonra ambar acildi", not RestoreBoard.is_locked("barn"), "")

	# The farm lifts the payout; the clinic adds a salvage point.
	ck("ciftlik payout bonusu", is_equal_approx(RestoreBoard.payout_bonus(), 0.05),
		str(RestoreBoard.payout_bonus()))
	var plain := ScrapField.payout(10, 1.0, 9)
	RestoreBoard.reset()
	var bare := ScrapField.payout(10, 1.0, 9)
	ck("ciftlik odemeyi artiriyor", int(plain["bonus"]) > int(bare["bonus"]),
		"%d vs %d" % [int(plain["bonus"]), int(bare["bonus"])])

	# The station regroups the case screens.
	GameState.set_setting("economy", "scrap", 20000)
	RestoreBoard.buy("swing")
	RestoreBoard.buy("lantern")
	ck("karakol once yok", not RestoreBoard.station_built(), "")
	RestoreBoard.buy("station")
	ck("karakol yapildi", RestoreBoard.station_built(), "")
	ck("marshal projesi var",
		RestoreBoard.projects_for("marshal").size() >= 1, "")
	RestoreBoard.reset()
	GameState.set_setting("economy", "scrap", 0)

	# --- board data contract
	var pins := Story.list("board.pins")
	ck("8 pano pini", pins.size() == 8, str(pins.size()))
	var seen := {}
	for pin: Dictionary in pins:
		var chapter := str(pin.get("chapter", ""))
		ck("pin bolumu gercek: %s" % chapter,
			LevelVariant.ids().has(chapter), chapter)
		seen[chapter] = true
		for axis in ["x", "y", "x2", "y2"]:
			var v := float(pin.get(axis, -1.0))
			ck("pin %s.%s 0-1 araligi" % [chapter, axis],
				v >= 0.0 and v <= 1.0, str(v))
	ck("her bolumun pini var", seen.size() == 8, str(seen.size()))
	for i in range(1, pins.size()):
		ck("baglanti notu var: %d" % i,
			str((pins[i] as Dictionary).get("note", "")) != "", "")

	# leave clean state for whoever runs next
	Garage.reset()
	GameState.set_setting("economy", "scrap", 0)
	GameConfig.BLADE_SCALE = 1.0

	if _fails > 0:
		push_error("%d GARAJ TESTI BASARISIZ" % _fails)
		print("--- %d GARAJ TESTI BASARISIZ ---" % _fails)
	else:
		print("--- TUM GARAJ TESTLERI GECTI ---")
	get_tree().quit()


func ck(label: String, passed: bool, detail: String) -> void:
	if passed:
		return
	_fails += 1
	print("  FAIL %s  %s" % [label, detail])
