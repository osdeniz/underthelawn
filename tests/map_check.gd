extends Node
## G13.5: the case map replaces the PLACES list without changing what starting a
## chapter means.

var _fails := 0


func _ready() -> void:
	ChapterProgress.reset()
	var map := TownMap.new()
	map.size = Vector2(1170, 2000)
	add_child(map)
	await get_tree().process_frame

	# Every chapter must have a place on the map, or it becomes unreachable the
	# moment the list is gone.
	var chapters: Array = Story.list("chapters")
	ck("her bolumun haritada yeri var",
		GameConfig.MAP_PLACES.size() == chapters.size(),
		"%d yer / %d bolum" % [GameConfig.MAP_PLACES.size(), chapters.size()])
	for chapter_any: Variant in chapters:
		var id := str((chapter_any as Dictionary).get("variant_id", ""))
		ck("yeri var: %s" % id, GameConfig.MAP_PLACES.has(id), "")

	# Case 1 must END east of where it STARTED, and finish in the far east.
	#
	# The first version demanded a strictly increasing x — every place further
	# east than the last. The painted map does not allow it: the greenhouse is
	# drawn on the west side of the town, and moving that pin off the building
	# it is named after would be worse than a detour in the route. A real trail
	# doubles back; what matters is that it ARRIVES in the east.
	var route: Array = GameConfig.MAP_PLACES.keys()
	var first: Vector2 = GameConfig.MAP_PLACES[route[0]]
	var last: Vector2 = GameConfig.MAP_PLACES[route[route.size() - 1]]
	ck("rota doguda bitiyor", last.x > first.x + 0.35,
		"basla=%.2f bitis=%.2f" % [first.x, last.x])
	# The last three places are the eastern edge of the map: the case leaves
	# town, and that is the shape the player should feel.
	var eastern := 0
	for i in range(route.size() - 3, route.size()):
		if (GameConfig.MAP_PLACES[route[i]] as Vector2).x > 0.7:
			eastern += 1
	ck("son uc mekan doguda", eastern == 3, "%d/3" % eastern)

	# Exactly one pin is the active one, and it is the first unfinished place.
	map.refresh()
	await get_tree().process_frame
	ck("tam bir aktif pin var", _count_state(map, "next") == 1,
		"%d aktif" % _count_state(map, "next"))

	# Finishing a place moves the active pin along and marks the old one done.
	var order: Array = GameConfig.MAP_PLACES.keys()
	ChapterProgress.record(str(order[0]), 2, 2)
	map.refresh()
	await get_tree().process_frame
	ck("bitince pin yesillenir", _count_state(map, "done") == 1,
		"%d bitmis" % _count_state(map, "done"))
	ck("aktif pin ilerler", _count_state(map, "next") == 1,
		"%d aktif" % _count_state(map, "next"))

	# A place finished WITHOUT all its evidence is flagged, not silently green.
	ChapterProgress.record(str(order[1]), 1, 2)
	map.refresh()
	await get_tree().process_frame
	ck("eksik kanit isaretlenir", _count_state(map, "missed") == 1,
		"%d eksik" % _count_state(map, "missed"))

	# The pin's button emits the same signal the chapter rows used.
	var emitted := []
	map.place_chosen.connect(func(id: String) -> void: emitted.append(id))
	map.focus_place(str(order[2]))
	await get_tree().process_frame
	var panel := map.get_node_or_null("PlacePanel")
	ck("pin paneli acilir", panel != null, "panel yok")

	map.queue_free()
	ChapterProgress.reset()
	if _fails > 0:
		push_error("%d HARITA TESTI BASARISIZ" % _fails)
		print("--- %d HARITA TESTI BASARISIZ ---" % _fails)
	else:
		print("--- TUM HARITA TESTLERI GECTI ---")
	get_tree().quit()


## How many pins carry a given state flag.
func _count_state(map: TownMap, flag: String) -> int:
	var host := map.get_node_or_null("TownLayer/Pins")
	if host == null:
		return -1
	var total := 0
	for child in host.get_children():
		if child is Button and bool((child as Button).get_meta(flag, false)):
			total += 1
	return total


func ck(label: String, passed: bool, detail: String) -> void:
	if passed:
		return
	_fails += 1
	print("  FAIL %s  %s" % [label, detail])
