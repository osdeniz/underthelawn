extends Node
## G14.14: six fields have to be six different days.

var _fails := 0


func _ready() -> void:
	var seen_shape := {}
	var seen_ground := {}
	var money: Array = []
	var food: Array = []
	for id_any: Variant in GameConfig.HARVEST_VARIANTS:
		var id := str(id_any)
		var variant := LevelVariant.of(id)
		ck("%s hasat tipi" % id, variant.is_harvest(), variant.level_type)
		ck("%s gida butcesi tanimli" % id, variant.food_budget >= 0,
			str(variant.food_budget))
		ck("%s grid tanimli: %s" % [id, variant.grid_size],
			GameConfig.GRID_SIZES.has(variant.grid_size), variant.grid_size)
		seen_shape[variant.grid_size] = true
		seen_ground[variant.obstacle_layout_id] = true
		money.append(variant.scrap_budget)
		food.append(variant.food_budget)

	# The whole point: the six must not be one level in six colours. They used
	# to share a grid, a layout and a budget, so the choice was a palette.
	ck("tarlalar ayni sekilde degil", seen_shape.size() >= 3,
		"%d sekil" % seen_shape.size())
	ck("tarlalar ayni zeminde degil", seen_ground.size() >= 3,
		"%d zemin" % seen_ground.size())
	ck("para farki gercek", money.max() >= money.min() * 2,
		"%d..%d" % [money.min(), money.max()])
	ck("gida farki gercek", food.max() >= food.min() * 4,
		"%d..%d" % [food.min(), food.max()])

	# And no field may be strictly better than another: the one that pays most
	# must not also feed most.
	var rich := GameConfig.HARVEST_VARIANTS[money.find(money.max())]
	var fed := GameConfig.HARVEST_VARIANTS[food.find(food.max())]
	ck("en cok odeyen en cok doyuran degil", rich != fed,
		"%s" % rich)

	# The sheet has to SAY the difference, or the player still cannot see it.
	var map := TownMap.new()
	add_child(map)
	await get_tree().process_frame
	var notes := {}
	for id_any2: Variant in GameConfig.HARVEST_VARIANTS:
		notes[map._field_note(str(id_any2))] = true
	ck("her tarlanin kendi notu var", notes.size() >= 4,
		"%d farkli not" % notes.size())
	map.queue_free()

	if _fails > 0:
		push_error("%d TARLA TESTI BASARISIZ" % _fails)
		print("--- %d TARLA TESTI BASARISIZ ---" % _fails)
	else:
		print("--- TUM TARLA TESTLERI GECTI ---")
	get_tree().quit()


func ck(label: String, passed: bool, detail: String) -> void:
	if passed:
		return
	_fails += 1
	print("  FAIL %s  %s" % [label, detail])
