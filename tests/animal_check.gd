extends Node
## G14.25: the animals read the lawn. That is the whole claim, so it is what
## gets measured — not "an animal exists", which would pass on a static prop.

var _fails := 0


func _ready() -> void:
	GameState.set_setting("meta", "orientation_done", true)
	_facing_maths()
	await _ordinary_yard()
	await _harvest_and_cellar()
	await _dog_follows()

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
	var bolt_until := Time.get_ticks_msec() + 3000
	while Time.get_ticks_msec() < bolt_until and int(calm["state"]) != Animals.State.GONE:
		get_tree().paused = false
		await get_tree().process_frame
		spent += 0.0
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
			# The resettle interval is six seconds by design; the timer is not
			# what is under test, so it is zeroed the way _ring zeroes the rest.
			for entry: Dictionary in rabbits:
				entry["settle"] = 0.0
			await _settle(0.4)
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
	var watch_until := Time.get_ticks_msec() + 2000
	while Time.get_ticks_msec() < watch_until:
		get_tree().paused = false
		await get_tree().process_frame
		watched += 0.0
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
	print("  [asama] maliyet olcumu basliyor")

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
	# Through _drawn_frame, never a bare await on frame_post_draw: this was the
	# one raw wait left after the _draws fix, and it is exactly where the test
	# sat for 280 s with no verdict when the window was not drawing.
	for _i in 8:
		await _drawn_frame()
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
	print("  [asama] kadraj kuruldu, sayac sondasi")
	var with_hood := await _draws(animals, true)
	hood.visible = false
	await _frames(8)
	var without_hood := await _draws(animals, true)
	hood.visible = true
	await _frames(8)
	var counter_live := with_hood - without_hood > 100
	if not counter_live:
		print("  ATLANDI maliyet olcumu: cizim sayaci cevap vermiyor (mahalleli=%d"
			% with_hood + " mahallesiz=%d) - pencere cizmiyor, on planda calistir"
			% without_hood)

	var on_total := 0
	var off_total := 0
	for _round in 4:
		off_total += await _draws(animals, false)
		on_total += await _draws(animals, true)
	var on := int(round(float(on_total) / 4.0))
	var off := int(round(float(off_total) / 4.0))
	if not counter_live:
		pass  # already reported above, with the numbers
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


## Once the long walk is done the dog is HIS, and it comes to where he is
## instead of pacing a fence (G15.1). Driven by MOVING THE MOWER, and measured
## as a distance that closes — the dog's own state is not the claim.
func _dog_follows() -> void:
	GameState.set_setting("story", "prologue_done", true)
	var game: Node = await _open("ch01_aldridge")
	var animals := game._animals as Animals
	ck("kendi kopegimiz var", animals != null
		and animals.get_node_or_null("Dog") != null, "yok")
	if animals == null or animals.get_node_or_null("Dog") == null:
		GameState.set_setting("story", "prologue_done", false)
		game.queue_free()
		await _frames(6)
		return
	var dog := animals.get_node("Dog") as Node3D
	# Sent to the far corner of the yard, well past DOG_FOLLOW_FAR.
	game.mower.global_position = Vector3(-GameConfig.HALF_X + 1.5,
		game.mower.global_position.y, -GameConfig.HALF_Z + 1.5)
	await _frames(4)
	var before := Vector2(dog.position.x - game.mower.global_position.x,
		dog.position.z - game.mower.global_position.z).length()
	await _settle(2.2)
	var after := Vector2(dog.position.x - game.mower.global_position.x,
		dog.position.z - game.mower.global_position.z).length()
	ck("kopek bize dogru geliyor", after < before - 1.0,
		"%.2f -> %.2f birim" % [before, after])
	# And STOPS short. A dog that arrives at your feet stands in the picture.
	await _settle(2.6)
	var settled := Vector2(dog.position.x - game.mower.global_position.x,
		dog.position.z - game.mower.global_position.z).length()
	ck("kopek dibimize girmiyor", settled > 0.8, "%.2f birim" % settled)
	ck("kopek yine de yakinda", settled < GameConfig.DOG_FOLLOW_FAR + 1.0,
		"%.2f birim" % settled)
	print("  [olcum] kopek %.1f -> %.1f -> %.1f birim" % [before, after, settled])

	# --- SCENT (G15.4). Driven by moving the MOWER so the dog follows into
	# range; the claim is the dog's FACING, read off its transform, not its
	# state. First a spot with NOTHING buried near it, so "not pointing" is a
	# real observation and not luck about where the secrets landed.
	var head := dog.get_node("Body/Head") as Node3D
	var buried_cells: Array[Vector2i] = []
	for cell: Vector2i in game.model.secret_cells:
		if game.model.states[LawnModel.index_of(cell.x, cell.y)] == LawnModel.CellState.SECRET:
			buried_cells.append(cell)
	ck("gomulu kanit var", not buried_cells.is_empty(), "yok")
	var clear_spot := Vector3.ZERO
	var clear_gap := 0.0
	for candidate: Vector3 in [Vector3(-GameConfig.HALF_X + 1.5, 0.0, GameConfig.HALF_Z - 1.5),
			Vector3(GameConfig.HALF_X - 1.5, 0.0, GameConfig.HALF_Z - 1.5),
			Vector3(-GameConfig.HALF_X + 1.5, 0.0, -GameConfig.HALF_Z + 1.5),
			Vector3(GameConfig.HALF_X - 1.5, 0.0, -GameConfig.HALF_Z + 1.5),
			Vector3(0.0, 0.0, 0.0)]:
		var nearest := 1e9
		for cell: Vector2i in buried_cells:
			nearest = minf(nearest, candidate.distance_to(LawnModel.cell_center(cell.x, cell.y)))
		if nearest > clear_gap:
			clear_gap = nearest
			clear_spot = candidate
	game.mower.global_position = Vector3(clear_spot.x, game.mower.global_position.y, clear_spot.z)
	# Wait for ARRIVAL, not a fixed time: a corner-to-corner walk at
	# DOG_FOLLOW_SPEED is six seconds, and a 3.5 s wait measured a dog that was
	# still on its way with its head where the last scent left it.
	await _dog_arrives(dog, game.mower)
	await _settle(1.0)
	ck("yakinda kanit yokken isaret etmiyor", head.rotation.x < 0.1,
		"kafa %.2f asagida (en yakin kanit %.1f)" % [head.rotation.x, clear_gap])
	if not buried_cells.is_empty():
		var buried := buried_cells[0]
		var at := LawnModel.cell_center(buried.x, buried.y)
		game.mower.global_position = at + Vector3(1.5, game.mower.global_position.y, 0.0)
		await _dog_arrives(dog, game.mower)
		await _settle(1.0)
		var to := Vector2(at.x - dog.position.x, at.z - dog.position.z)
		var fwd := -dog.global_transform.basis.z
		var off := rad_to_deg(absf(Vector2(fwd.x, fwd.z).angle_to(to)))
		ck("kopek gomulu hucreye donuyor", off < 20.0,
			"%.0f derece, mesafe %.1f" % [off, to.length()])
		ck("kopek isaret ederken kafasi asagida", head.rotation.x > 0.2,
			"kafa %.2f" % head.rotation.x)
		# Dug up: it loses interest.
		game.model.mow(buried.x, buried.y, 0)
		await _settle(1.5)
		ck("kanit cikinca serbest kaliyor", head.rotation.x < 0.15,
			"kafa %.2f" % head.rotation.x)
		print("  [olcum] koku: sapma %.0f derece, mesafe %.1f, bos noktada en yakin %.1f"
			% [off, to.length(), clear_gap])
	GameState.set_setting("story", "prologue_done", false)
	game.queue_free()
	await _frames(6)


## Waits until the dog has closed to its follow distance of `mower`, or ten
## seconds, whichever first.
func _dog_arrives(dog: Node3D, mower: Node3D) -> void:
	var until := Time.get_ticks_msec() + 10000
	while Time.get_ticks_msec() < until:
		get_tree().paused = false
		await get_tree().process_frame
		var gap := Vector2(dog.position.x - mower.global_position.x,
			dog.position.z - mower.global_position.z).length()
		if gap <= GameConfig.DOG_FOLLOW_NEAR + 0.3:
			return


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
	# WALL-CLOCK time, not summed deltas. get_process_delta_time() reads 0 on a
	# node the tree has paused — and the game pauses itself whenever the window
	# loses focus — so a delta-summing loop never reaches its target and the
	# test hangs with no verdict. The clock keeps moving whatever the tree does,
	# and a hard cap on frames means this can never spin for ever either.
	var until := Time.get_ticks_msec() + int(seconds * 1000.0)
	var frames := 0
	while Time.get_ticks_msec() < until and frames < 6000:
		get_tree().paused = false
		await get_tree().process_frame
		frames += 1


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
		await _drawn_frame()
	var total := 0
	for _i in 8:
		await _drawn_frame()
		total += RenderingServer.get_rendering_info(
			RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
	return int(round(float(total) / 8.0))


## One drawn frame, or 0.25 s, whichever comes first. A backgrounded or
## occluded window stops drawing altogether, and a bare
## `await RenderingServer.frame_post_draw` then never returns: this test hung
## at the cost measurement for the whole of a 280 s run with no verdict. If no
## frame is drawn the counter reading is stale, and the liveness check below
## SKIPS the measurement rather than trusting it.
var _drew := false
func _drawn_frame() -> void:
	_drew = false
	var mark := func() -> void: _drew = true
	RenderingServer.frame_post_draw.connect(mark, CONNECT_ONE_SHOT)
	var until := Time.get_ticks_msec() + 250
	while not _drew and Time.get_ticks_msec() < until:
		get_tree().paused = false
		await get_tree().process_frame
	if RenderingServer.frame_post_draw.is_connected(mark):
		RenderingServer.frame_post_draw.disconnect(mark)


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
