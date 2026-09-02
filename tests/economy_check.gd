extends Node
## G14.11: can a player who finishes the game afford the game?
##
## Written because a review of mine got this exactly backwards. I read the
## sinks as 8 850 — missing the 5 560 in workshop upgrades entirely — and never
## measured the income at all, then reported that money was meaningless. The
## real curve was the opposite: 10 779 of income against 14 410 of sinks, with
## the gap quietly closed by farming harvests.
##
## Everything below runs through the SHIPPING functions, not a copy of their
## arithmetic, so the guard cannot drift away from the formulas it guards.

## The chapters pay for the game, and the harvest is the bonus it is presented
## as. Below 1.0 a completionist is forced to farm; far above it money stops
## meaning anything by the midpoint.
const MIN_COVER := 1.0
const MAX_COVER := 1.6

var _fails := 0


func _ready() -> void:
	var sinks := _sinks()
	var case_one := _income(_chapter_ids(false))
	var case_two := _income(_chapter_ids(true))
	var harvest := _payout_for(GameConfig.HARVEST_VARIANT)
	var income := case_one + case_two
	print("  gelir : vaka1 %d + vaka2 %d = %d" % [case_one, case_two, income])
	print("  gider : %d" % sinks)
	print("  hasat : %d (tekrarlanabilir)" % harvest)
	print("  kapsam: %.2fx" % (float(income) / maxf(float(sinks), 1.0)))

	var cover := float(income) / maxf(float(sinks), 1.0)
	ck("bolumler oyunun bedelini oduyor", cover >= MIN_COVER,
		"%.2fx — eksigi hasat kapatiyor, yani hasat zorunlu" % cover)
	ck("para anlamini yitirmiyor", cover <= MAX_COVER,
		"%.2fx — alinacak sey bitiyor" % cover)

	# A case whose yards are BIGGER must not pay less than one whose yards are
	# smaller: that is what 0.32 did, and it made the last ten chapters the
	# poorest ones in the game.
	var per_cell_one := float(case_one) / maxf(float(_budget(false)), 1.0)
	var per_cell_two := float(case_two) / maxf(float(_budget(true)), 1.0)
	ck("vaka 2 kendi boyutuna gore odeme yapiyor",
		per_cell_two >= per_cell_one * 0.5,
		"birim odeme %.1f vs %.1f" % [per_cell_two, per_cell_one])

	if _fails > 0:
		push_error("%d EKONOMI TESTI BASARISIZ" % _fails)
		print("--- %d EKONOMI TESTI BASARISIZ ---" % _fails)
	else:
		print("--- EKONOMI DENGEDE ---")
	get_tree().quit()


## Everything the game asks money for.
func _sinks() -> int:
	var total := 0
	for any: Variant in RestoreBoard.projects():
		total += int((any as Dictionary).get("cost", 0))
	for id: String in GameConfig.UNLOCK_COSTS:
		total += int(GameConfig.UNLOCK_COSTS[id])
	for id2: String in GameConfig.UPGRADE_COSTS:
		for step: Variant in GameConfig.UPGRADE_COSTS[id2]:
			total += int(step)
	return total


## What every chapter of a case pays at 100%, through Game's own payout path.
func _income(ids: Array) -> int:
	var total := 0
	for id_any: Variant in ids:
		total += _payout_for(str(id_any))
	return total


func _payout_for(variant_id: String) -> int:
	var variant := LevelVariant.of(variant_id)
	var ground := variant.scrap_budget * int(round(
		float(GameConfig.SCRAP_PICKUP_MIN + GameConfig.SCRAP_PICKUP_MAX) * 0.5))
	var payout := ScrapField.payout(ground, 1.0, variant.scrap_budget)
	var multiplier := GameConfig.HARVEST_SCRAP_MULTIPLIER if variant.is_harvest() \
		else GameConfig.SEARCH_SCRAP_MULTIPLIER
	multiplier *= variant.scrap_multiplier
	return int(round(float(payout["total"]) * multiplier))


func _chapter_ids(second: bool) -> Array:
	var out: Array = []
	var list: Array = Story.list("case_02.chapters") if second \
		else Story.list("chapters")
	for any: Variant in list:
		out.append(str((any as Dictionary).get("variant_id", "")))
	return out


func _budget(second: bool) -> int:
	var total := 0
	for id_any: Variant in _chapter_ids(second):
		total += LevelVariant.of(str(id_any)).scrap_budget
	return total


func ck(label: String, passed: bool, detail: String) -> void:
	if passed:
		return
	_fails += 1
	print("  FAIL %s  %s" % [label, detail])
