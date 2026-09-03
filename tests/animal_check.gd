extends Node
## G14.25: the animals read the lawn. That is the whole claim, so it is what
## gets measured — not "an animal exists", which would pass on a static prop.

var _fails := 0


func _ready() -> void:
	GameState.set_setting("meta", "orientation_done", true)
	_facing_maths()
	await _ordinary_yard()
	await _harvest_and_cellar()

	if _fails > 0:
		push_error("%d HAYVAN TESTI BASARISIZ" % _fails)
		print("--- %d HAYVAN TESTI BASARISIZ ---" % _fails)
	else:
		print("--- TUM HAYVAN TESTLERI GECTI ---")
	get_tree().quit()


## Animals.face is checked by ROTATING A NODE and reading its forward axis --
## the ground truth, not a second copy of the formula. WalkDirCheck spent a
## whole sprint passing because it restated the maths it was testing.
func _facing_maths() -> void:
	var probe := Node3D.new()
	add_child(probe)
	for want: Vector2 in [Vector2(0, -1), Vector2(1, 0), Vector2(0, 1),
			Vector2(-1, 0), Vector2(0.6, -0.8)]:
		probe.rotation.y = Animals.face(want)
		var forward := -probe.global_transform.basis.z
		var got := Vector2(forward.x, forward.z).normalized()
		var off := rad_to_deg(absf(got.angle_to(want.normalized())))
		ck("face%v dogru eksende" % want, off < 0.5, "%.1f derece" % off)
	probe.queue_free()


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
	var runner := calm["node"] as Node3D
	var prev := runner.position
	var worst_face := 0.0
	while spent < 3.0 and int(calm["state"]) != Animals.State.GONE:
		get_tree().paused = false
		await get_tree().process_frame
		spent += get_process_delta_time()
		worst_face = maxf(worst_face, _face_error(runner, prev))
		prev = runner.position
	# Tail-first was how all three animals ran before G14.27.
	ck("tavsan kactigi yone bakiyor", worst_face < 15.0,
		"%.0f derece" % worst_face)
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
	var dog_prev := dog.position
	var dog_face := 0.0
	var outside := 1e9
	var clear := 1e9
	while watched < 2.0:
		get_tree().paused = false
		await get_tree().process_frame
		watched += get_process_delta_time()
		worst = minf(worst, absf(dog.position.z) - GameConfig.HALF_Z)
		# Past the FENCE, so it is above the grass line rather than behind it,
		# and clear of the porch in x. "Outside the lawn" alone let it walk
		# through the porch boards for two sprints.
		outside = minf(outside,
			absf(dog.position.z) - absf(GameConfig.fence_north_z()))
		clear = minf(clear, absf(dog.position.x) - 2.5)
		dog_face = maxf(dog_face, _face_error(dog, dog_prev))
		dog_prev = dog.position
	ck("kopek gittigi yone bakiyor", dog_face < 15.0, "%.0f derece" % dog_face)
	ck("kopek citin otesinde yuruyor", outside > 0.0,
		"%.2f birim citin icinde" % -outside)
	# The porch platform is 5.0 wide in the house mesh, so x -2.5 to 2.5.
	ck("kopek verandanin yanindan geciyor", clear > 0.0,
		"%.2f birim veranda uzerinde" % -clear)
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
	# And all of them IN FRAME. The chase camera looks down the lawn from
	# behind the mower; when the dog moved off the porch (G14.27) it left the
	# frustum, the toggle stopped changing anything, and this measurement
	# reported the animals costing 0 draws. A number that cannot move is not a
	# measurement, so the shot is taken from above the whole yard and the
	# assertion below requires the difference to be NON-ZERO.
	var above := Camera3D.new()
	above.fov = 70.0
	above.position = Vector3(0.0, 24.0, -4.0)
	above.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	above.current = true
	game.add_child(above)
	for _i in 8:
		get_tree().paused = false
		await RenderingServer.frame_post_draw
	var showing := 0
	for entry: Dictionary in animals._entries:
		if (entry["node"] as Node3D).visible:
			showing += 1
	# PROVE THE COUNTER RESPONDS before believing anything it says. Hiding the
	# whole neighbourhood is most of the yard's mesh, so the reading has to
	# fall a long way; the first version of this measurement reported a flat
	# 400 for eight rounds running -- the renderer had not settled after the
	# camera changed and the counter was handing back a stale value, which
	# looked exactly like "the animals are free".
	var hood := game.get_node("Neighborhood") as Node3D
	var with_hood := await _draws(animals, true)
	hood.visible = false
	await _frames(8)
	var without_hood := await _draws(animals, true)
	hood.visible = true
	await _frames(8)
	var counter_live := with_hood - without_hood > 100
	ck("cizim sayaci canli", counter_live,
		"mahalleli=%d mahallesiz=%d" % [with_hood, without_hood])

	var on_total := 0
	var off_total := 0
	for _round in 4:
		off_total += await _draws(animals, false)
		on_total += await _draws(animals, true)
	var on := int(round(float(on_total) / 4.0))
	var off := int(round(float(off_total) / 4.0))
	if not counter_live:
		print("  ATLANDI maliyet olcumu: sayac cevap vermiyor")
	else:
		print("  [olcum] ayni sahne: hayvanli=%d hayvansiz=%d fark=%d cizim"
			% [on, off, on - off]
			+ " (%d hayvan, hepsi kadrajda)" % showing)
		ck("hayvanlar kadrajda", on - off > 0,
			"fark yok - kadraj disinda olcum yapilmis")
		# Not "free": every animal is a handful of separate meshes because its
		# ears, head and legs move. This is the WORST case - all six on screen
		# at once from above the whole yard. Behind the mower, where fewer of
		# them are in frame, it measured 33.
		ck("hayvanlar butcede", on - off <= 80, "%d cizim" % (on - off))
	animals.visible = true
	animals.set_process(true)
	above.queue_free()

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
	# Waits on frames that were actually DRAWN. process_frame advances the game
	# loop, and in a fast headless run several of those can pass between two
	# renders — the draw counter then hands back the same stale number for
	# every sample, which is exactly what made this measurement report a flat
	# 400 for eight rounds and look like "the animals are free".
	for _i in 6:
		get_tree().paused = false
		await RenderingServer.frame_post_draw
	var total := 0
	for _i in 8:
		get_tree().paused = false
		await RenderingServer.frame_post_draw
		total += RenderingServer.get_rendering_info(
			RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
	return int(round(float(total) / 8.0))


## How far a body's forward axis is from where it just moved, in degrees. Zero
## when it did not move far enough to say.
func _face_error(node: Node3D, previous: Vector3) -> float:
	var step := Vector2(node.position.x - previous.x, node.position.z - previous.z)
	if step.length() < 0.0008:
		return 0.0
	var forward := -node.global_transform.basis.z
	return rad_to_deg(absf(Vector2(forward.x, forward.z).angle_to(step)))


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
