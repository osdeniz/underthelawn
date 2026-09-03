extends Node
## G14.25: the animals read the lawn. That is the whole claim, so it is what
## gets measured — not "an animal exists", which would pass on a static prop.

var _fails := 0


func _ready() -> void:
	GameState.set_setting("meta", "orientation_done", true)
	await _ordinary_yard()
	await _harvest_and_cellar()

	if _fails > 0:
		push_error("%d HAYVAN TESTI BASARISIZ" % _fails)
		print("--- %d HAYVAN TESTI BASARISIZ ---" % _fails)
	else:
		print("--- TUM HAYVAN TESTLERI GECTI ---")
	get_tree().quit()


func _ordinary_yard() -> void:
	var game: Node = await _open("ch01_aldridge")
	var animals := game._animals as Animals
	ck("bahcede hayvanlar var", animals != null, "null")
	if animals == null:
		return

	var rabbits := _of(animals, Animals.Kind.RABBIT)
	var peckers := _of(animals, Animals.Kind.PECKER)
	var dogs := _of(animals, Animals.Kind.DOG)
	ck("tavsan sayisi", rabbits.size() == GameConfig.RABBIT_COUNT,
		"%d" % rabbits.size())
	ck("kus sayisi", peckers.size() == GameConfig.PECKER_COUNT,
		"%d" % peckers.size())
	ck("evin kopegi var", dogs.size() == 1, "%d" % dogs.size())

	# --- Nothing is cut yet, so no bird has anywhere to stand. This is the
	# assertion that would catch a bird spawned on faith.
	_ring(animals)
	await _frames(6)
	var standing := 0
	for entry: Dictionary in peckers:
		if (entry["node"] as Node3D).visible:
			standing += 1
	ck("bicilmeden once kus yok", standing == 0, "%d kus" % standing)

	# --- A rabbit sits in LONG grass.
	_ring(animals)
	await _frames(10)
	var calm := _first_calm(rabbits)
	ck("tavsan yerlesti", not calm.is_empty(), "hicbiri CALM degil")
	if calm.is_empty():
		game.queue_free()
		await _frames(6)
		return
	var at: Vector3 = (calm["node"] as Node3D).position
	var cell := LawnModel.cell_at(at)
	# Nothing is cut yet, so this one IS in the long grass — hidden, and the
	# bolt below is the first the player sees of it.
	ck("bicilmemisken uzun cimende", not game.model.is_cut(cell.x, cell.y),
		"%s bicilmis" % cell)

	# --- It bolts. Driven by MOVING THE MOWER, not by setting the animal's
	# state: what is under test is that the machine coming is what does it.
	game.mower.global_position = at + Vector3(1.2, 0.0, 0.0)
	await _frames(4)
	ck("makine yaklasinca kaciyor", int(calm["state"]) != Animals.State.CALM,
		"hala CALM")
	# Given a moment it is off the lawn entirely.
	# The longest bolt is a corner-to-fence run: about 13 units at
	# RABBIT_SPEED, so a little over two seconds.
	var spent := 0.0
	while spent < 3.0 and int(calm["state"]) != Animals.State.GONE:
		get_tree().paused = false
		await get_tree().process_frame
		spent += get_process_delta_time()
	ck("kacinca gorunmez oluyor",
		int(calm["state"]) == Animals.State.GONE
			and not (calm["node"] as Node3D).visible,
		"durum=%d" % int(calm["state"]))

	# --- Cut some ground, and the birds come down onto it.
	for row in range(2, 15):
		for col in range(2, 13):
			if game.model.is_mowable(col, row):
				game.model.mow(col, row, 0)
	# The mower is parked far away so its own flee radius is not the reason a
	# bird cannot land.
	game.mower.global_position = Vector3(0.0, 0.0, GameConfig.HALF_Z - 0.5)
	_ring(animals)
	await _frames(12)
	var landed := 0
	var wrong := 0
	for entry: Dictionary in peckers:
		var node := entry["node"] as Node3D
		if not node.visible:
			continue
		landed += 1
		var spot := LawnModel.cell_at(node.position)
		if not game.model.is_cut(spot.x, spot.y):
			wrong += 1
	ck("bicilen yere kus konuyor", landed > 0, "%d kus" % landed)
	ck("kuslar sadece bicilmis hucrede", wrong == 0, "%d yanlis" % wrong)

	# --- And the rabbit moves to the MOWN EDGE once there is one. This is the
	# assertion the render forced: in the long grass it was invisible.
	_ring(animals)
	await _frames(12)
	var edge := _first_calm(rabbits)
	# The one that never bolted is still sitting in long grass; give the
	# resettle its interval and it moves out to the edge like the other.
	if not edge.is_empty():
		var first := LawnModel.cell_at((edge["node"] as Node3D).position)
		if not game.model.is_cut(first.x, first.y):
			await _settle(GameConfig.RABBIT_RESETTLE + 0.4)
			_ring(animals)
			await _frames(12)
			edge = _first_calm(rabbits)
	ck("bicildikten sonra tavsan geri geliyor", not edge.is_empty(), "yok")
	if not edge.is_empty():
		var spot := LawnModel.cell_at((edge["node"] as Node3D).position)
		ck("tavsan bicilmis zeminde", game.model.is_cut(spot.x, spot.y),
			"%s bicilmemis" % spot)
		ck("tavsan uzun cimenin kenarinda",
			animals._borders_uncut(spot.x, spot.y), "%s ic tarafta" % spot)

	# --- The dog never comes in. Watched over time, not sampled once: it walks
	# a line, and a single frame cannot tell a line from a point.
	var dog := dogs[0]["node"] as Node3D
	# Watched over a real stretch of its walk, not over a frame count: the dog
	# crosses its whole line in about ten seconds, and two of those is enough
	# to catch it wandering in.
	var worst := 1e9
	var watched := 0.0
	while watched < 2.0:
		get_tree().paused = false
		await get_tree().process_frame
		watched += get_process_delta_time()
		worst = minf(worst, absf(dog.position.z) - GameConfig.HALF_Z)
	ck("kopek cime girmiyor", worst > 0.0, "%.2f birim icerde" % -worst)
	print("  [olcum] kopek cim kenarindan en yakin %.2f birim uzakta" % worst)
	print("  [olcum] hayvan dugumu=%d" % _node_count(animals))

	# --- What they cost, in ONE scene with the animals as the only variable.
	# Comparing two scenes measures two scenes; that mistake has been made in
	# this project twice (the fireflies, then the legibility pass) and it is
	# written down both times.
	# Every animal placed and standing first, so the number is the WORST case
	# rather than whatever happened to be on screen at the sample moment.
	_ring(animals)
	await _settle(0.5)
	var showing := 0
	for entry: Dictionary in animals._entries:
		if (entry["node"] as Node3D).visible:
			showing += 1
	var on_total := 0
	var off_total := 0
	for _round in 4:
		off_total += await _draws(animals, false)
		on_total += await _draws(animals, true)
	var on := int(round(float(on_total) / 4.0))
	var off := int(round(float(off_total) / 4.0))
	if on == 0 and off == 0:
		print("  ATLANDI maliyet olcumu: headless'ta cizim sayaci yok"
			+ " - pencereli calistir")
	else:
		print("  [olcum] ayni sahne: hayvanli=%d hayvansiz=%d fark=%d cizim (%d hayvan)"
			% [on, off, on - off, showing])
		# Not "free": every animal is a handful of separate meshes because its
		# ears, head and legs move. The budget is what a yard can spare.
		ck("hayvanlar butcede", on - off <= 48, "%d cizim" % (on - off))
	animals.visible = true
	animals.set_process(true)

	game.queue_free()
	await _frames(6)


func _harvest_and_cellar() -> void:
	var farm: Node = await _open("harvest_field")
	var animals := farm._animals as Animals
	if animals == null:
		ck("tarlada hayvan var", false, "null")
	else:
		ck("tarlada kopek yok", _of(animals, Animals.Kind.DOG).is_empty(), "var")
		ck("tarlada tavsan var",
			_of(animals, Animals.Kind.RABBIT).size() == GameConfig.RABBIT_COUNT,
			"eksik")
	farm.queue_free()
	await _frames(6)

	var cellar: Node = await _open("ch08_cellar")
	ck("mahzende hayvan yok", cellar._animals == null, "var")
	cellar.queue_free()
	await _frames(6)


# ---------------------------------------------------------------- helpers

func _open(chapter: String) -> Node:
	var game: Node = load("res://scenes/Main.tscn").instantiate()
	game.variant_id = chapter
	add_child(game)
	await _frames(10)
	get_tree().paused = false
	game.hud._close_pause()
	game._begin_search()
	await _frames(20)
	return game


func _frames(count: int) -> void:
	for _i in count:
		get_tree().paused = false
		await get_tree().process_frame


## Yields frames until `seconds` of PROCESS TIME have gone by. Everything an
## animal does is a rate per SECOND, and a frame count is not a duration —
## headless this scene reaches hundreds of frames a second, so a 240-frame wait
## for a bolt to finish was under half a second on a fast run and over four on
## a slow one. LifeCheck failed and passed on identical code for exactly this
## reason before it was fixed the same way.
func _settle(seconds: float) -> void:
	var spent := 0.0
	while spent < seconds:
		get_tree().paused = false
		await get_tree().process_frame
		spent += get_process_delta_time()


## Zeroes every waiting timer. The RETURN delays are seconds long by design —
## an animal that reappears instantly reads as a spawn — but a test should not
## spend ten seconds proving a placement rule, and the timer is not the thing
## under test.
func _ring(animals: Animals) -> void:
	for entry: Dictionary in animals._entries:
		if int(entry["state"]) == Animals.State.GONE:
			entry["timer"] = 0.0


## Draw calls with the animals in the given state, averaged over frames so one
## odd frame cannot decide it.
func _draws(animals: Animals, on: bool) -> int:
	animals.visible = on
	animals.set_process(on)
	await _frames(8)
	var total := 0
	for _i in 8:
		get_tree().paused = false
		await get_tree().process_frame
		total += RenderingServer.get_rendering_info(
			RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
	return int(round(float(total) / 8.0))


func _of(animals: Animals, kind: int) -> Array:
	var out: Array = []
	for entry: Dictionary in animals._entries:
		if int(entry["kind"]) == kind:
			out.append(entry)
	return out


func _first_calm(entries: Array) -> Dictionary:
	for entry: Dictionary in entries:
		if int(entry["state"]) == Animals.State.CALM:
			return entry
	return {}


func _node_count(root: Node) -> int:
	var total := 1
	for child in root.get_children():
		total += _node_count(child)
	return total


func ck(label: String, passed: bool, detail: String) -> void:
	if passed:
		return
	_fails += 1
	print("  FAIL %s  %s" % [label, detail])
