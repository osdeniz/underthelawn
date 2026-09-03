class_name Animals
extends Node3D
## The animals in the yard (G14.25). Every one of them reads the LAWN, which is
## what separates them from decoration: they know what has been cut.
##
## RABBITS graze the MOWN EDGE — short grass with long grass beside it — and
## bolt for the nearest fence line when the machine gets near. The first pass
## put them in the long grass, on the theory that uncut ground should feel
## inhabited; rendered, it was wrong. The clumps are 0.4 to 0.9 units tall and
## the rabbit is 0.32, so it was not hidden, it was invisible, and a bolt
## nobody sees is not a moment. The edge is also the truer picture: a rabbit
## comes out of cover to eat a lawn and runs back into it.
##
## The BIRDS are the other half of that trade: they land on ground that has
## just been cut and peck at what the blades turned up, and they only exist
## once there is cut ground to land on. Mowing gives something back rather than
## only taking the grass away.
##
## The DOG belongs to the house. It trots the strip between the porch and the
## north fence, never comes in, and never startles — it lives here, the machine
## does not frighten it, and it is the one animal that is not about the lawn.
##
## No navmesh, no physics bodies, no allocation per frame. Each animal is a
## handful of primitive meshes and a three-state machine, and the whole file
## adds four nodes to a yard that already draws eight hundred.

enum Kind { RABBIT, PECKER, DOG }
## CALM covers sitting, pecking and trotting: whatever the animal does when it
## is not running away. GONE is off-screen and counting down to a new spot.
enum State { CALM, FLEE, GONE }

## The chapter's lawn. Without it nothing can be placed, because every spot is
## chosen by whether its cell is cut.
var model: LawnModel
## Pushed in by Game every frame: where the player is and whether there is one.
var player_at := Vector3.ZERO
var player_on := false

## Whether the dog is the player's yet, and whether this is the prologue road.
var _owned := false
var _road := false

var _entries: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()
var _mats := {}
var _t := 0.0


## `farmland` and `vignette` are asked for rather than derived: the dog needs a
## house to belong to, and the cellar chapter is indoors.
static func build(parent: Node3D, lawn_model: LawnModel, seed_value: int,
		farmland: bool, vignette: bool) -> Animals:
	if not GameConfig.ANIMALS_ENABLED or vignette:
		return null
	var node := Animals.new()
	node.name = "Animals"
	node.model = lawn_model
	parent.add_child(node)
	node._populate(seed_value, farmland)
	return node


func _populate(seed_value: int, farmland: bool) -> void:
	set_meta("no_bake", true)
	_owned = is_dog_owned()
	_road = LevelVariant.current != null and LevelVariant.current.is_road()
	_rng.seed = seed_value if seed_value != 0 else 20260903

	for i in GameConfig.RABBIT_COUNT:
		var root := Node3D.new()
		root.name = "Rabbit%d" % i
		add_child(root)
		var body := _rabbit_body(root)
		# Placed straight away: the long grass is already there to sit in.
		var entry := {"kind": Kind.RABBIT, "node": root, "body": body,
			"state": State.GONE, "timer": _rng.randf_range(0.0, 2.0),
			"target": Vector3.ZERO, "phase": _rng.randf() * TAU,
			"settle": GameConfig.RABBIT_RESETTLE}
		_entries.append(entry)

	for i in GameConfig.PECKER_COUNT:
		var root := Node3D.new()
		root.name = "Bird%d" % i
		add_child(root)
		var body := _pecker_body(root)
		# They start away. Nothing has been cut yet, so there is nowhere for a
		# bird that follows the blades to be standing.
		var entry := {"kind": Kind.PECKER, "node": root, "body": body,
			"state": State.GONE,
			"timer": _rng.randf_range(GameConfig.PECKER_RETURN.x,
				GameConfig.PECKER_RETURN.y),
			"target": Vector3.ZERO, "phase": _rng.randf() * TAU}
		_entries.append(entry)

	# The dog is HIS from the prologue on (G15.1), and then it comes with him:
	# every yard, the harvest fields included, walking to where he is instead
	# of pacing somebody's fence. Before that — and in the prologue itself,
	# where it does not know him yet — it is the house's dog on its own line.
	if GameConfig.DOG_ENABLED and (_owned or not farmland):
		var root := Node3D.new()
		root.name = "Dog"
		add_child(root)
		var body := _dog_body(root)
		if _road:
			# Sitting at the end of the road with the basket, which is what the
			# player has been walking towards.
			root.position = GameConfig.prologue_dog_spot()
			root.rotation.y = PI
		elif _owned:
			var spawn := GameConfig.mower_start()
			root.position = Vector3(spawn.x + 1.6, 0.0, spawn.y + 0.4)
		else:
			# North of the fence and BESIDE the porch — see DOG_PATH_OUTSET for
			# why neither the porch strip nor the inside of the fence works.
			root.position = Vector3(_dog_x(0.0), 0.0, dog_z())
		_entries.append({"kind": Kind.DOG, "node": root, "body": body,
			"state": State.CALM, "timer": 0.0, "target": Vector3.ZERO,
			"phase": _rng.randf()})

	for entry: Dictionary in _entries:
		if entry["kind"] != Kind.DOG:
			(entry["node"] as Node3D).visible = false


# ---------------------------------------------------------------- tick

func _process(delta: float) -> void:
	_t += delta
	for entry: Dictionary in _entries:
		match int(entry["kind"]):
			Kind.RABBIT:
				_tick_rabbit(entry, delta)
			Kind.PECKER:
				_tick_pecker(entry, delta)
			Kind.DOG:
				_tick_dog(entry, delta)


func _tick_rabbit(entry: Dictionary, delta: float) -> void:
	var root := entry["node"] as Node3D
	var body := entry["body"] as Node3D
	match int(entry["state"]):
		State.CALM:
			_rabbit_idle(entry, body)
			_rabbit_resettle(entry, root, delta)
			if _player_within(root, GameConfig.RABBIT_BOLT_RANGE):
				entry["state"] = State.FLEE
				entry["target"] = _bolt_target(root.position)
				# Ears go FLAT and stay flat while it runs. Upright ears on a
				# sprinting rabbit is the tell that it is an animation, not an
				# animal.
				_set_ears(body, 1.35)
		State.FLEE:
			var to: Vector3 = entry["target"]
			var step := GameConfig.RABBIT_SPEED * delta
			var away := to - root.position
			away.y = 0.0
			if away.length() <= step:
				entry["state"] = State.GONE
				entry["timer"] = _rng.randf_range(GameConfig.RABBIT_RETURN.x,
					GameConfig.RABBIT_RETURN.y)
				root.visible = false
				return
			root.position += away.normalized() * step
			root.rotation.y = face(Vector2(away.x, away.z))
			# The hop: the whole body leaves the ground and pitches nose-down
			# as it lands. One sine drives both.
			var hop := sin(_t * GameConfig.RABBIT_HOP_FREQ)
			body.position.y = absf(hop) * GameConfig.RABBIT_HOP_HEIGHT
			body.rotation.x = hop * 0.22
		State.GONE:
			entry["timer"] = float(entry["timer"]) - delta
			if float(entry["timer"]) > 0.0:
				return
			# The MOWN EDGE, where cover meets food. Measured, not chosen:
			# the grass clumps stand 0.4 to 0.9 units and the rabbit is 0.32
			# tall, so one sitting in uncut grass is not hidden, it is
			# INVISIBLE — the player would never see it, let alone see it go.
			# On the short grass beside the long it is plain to see, and it is
			# also what rabbits actually do: they come out of the cover to
			# graze a lawn and run back into it.
			var cell := _pick_cell(true, GameConfig.RABBIT_MIN_PLAYER_DIST, true)
			if cell.x < 0:
				# Nothing cut yet. Then it IS in the long grass, hidden, and
				# the first the player sees of it is the bolt out of the
				# blades — which is the best version of this moment anyway.
				cell = _pick_cell(false, GameConfig.RABBIT_MIN_PLAYER_DIST)
			if cell.x < 0:
				# Only the grass under the player is left. Ask again shortly
				# rather than forcing a spot.
				entry["timer"] = 2.5
				return
			root.position = LawnModel.cell_center(cell.x, cell.y)
			root.rotation.y = _rng.randf() * TAU
			body.position.y = 0.0
			body.rotation.x = 0.0
			_set_ears(body, 0.0)
			root.visible = true
			entry["state"] = State.CALM


## Sitting: the ears flick on their own clock and the head dips to nibble. Both
## are a few degrees, and they are the whole reason it does not read as a prop.
func _rabbit_idle(entry: Dictionary, body: Node3D) -> void:
	var phase := float(entry["phase"])
	var flick := sin(_t * TAU / GameConfig.RABBIT_EAR_PERIOD + phase)
	# Sharp, not sinusoidal: an ear twitches, it does not sway. Cubing a sine
	# keeps it near zero most of the cycle and snaps through the middle.
	_set_ears(body, flick * flick * flick * 0.42)
	var head := body.get_node_or_null("Head") as Node3D
	if head != null:
		var dip := sin(_t * TAU / GameConfig.RABBIT_NIBBLE_PERIOD + phase * 1.7)
		head.rotation.x = maxf(0.0, dip) * 0.46


## A rabbit placed before anything was cut is sitting in grass taller than it
## is. Once there is a mown edge to sit on it slips into cover and comes back
## out there — otherwise it spends the whole chapter invisible, which is the
## same as not existing.
func _rabbit_resettle(entry: Dictionary, root: Node3D, delta: float) -> void:
	entry["settle"] = float(entry["settle"]) - delta
	if float(entry["settle"]) > 0.0:
		return
	entry["settle"] = GameConfig.RABBIT_RESETTLE
	var here := LawnModel.cell_at(root.position)
	if model == null or model.is_cut(here.x, here.y):
		return
	if _pick_cell(true, GameConfig.RABBIT_MIN_PLAYER_DIST, true).x < 0:
		return
	entry["state"] = State.GONE
	entry["timer"] = 0.0
	root.visible = false


func _set_ears(body: Node3D, amount: float) -> void:
	for side: String in ["EarL", "EarR"]:
		var ear := body.get_node_or_null(side) as Node3D
		if ear != null:
			ear.rotation.x = amount


func _tick_pecker(entry: Dictionary, delta: float) -> void:
	var root := entry["node"] as Node3D
	var body := entry["body"] as Node3D
	match int(entry["state"]):
		State.CALM:
			var phase := float(entry["phase"])
			var head := body.get_node_or_null("Head") as Node3D
			if head != null:
				# Down, hold, up: a peck is not a sway either. The sine is
				# rectified so the head only ever goes DOWN from level.
				var beat := sin(_t * TAU / GameConfig.PECKER_PECK_PERIOD + phase)
				head.rotation.x = maxf(0.0, beat) * 0.85
			# A hop sideways every few seconds, so it does not stand rooted.
			root.rotation.y += sin(_t * 0.7 + phase) * delta * 0.6
			if _player_within(root, GameConfig.PECKER_FLEE_RANGE):
				entry["state"] = State.FLEE
				entry["timer"] = 1.3
				var out := root.position - player_at
				out.y = 0.0
				if out.length() < 0.01:
					out = Vector3.FORWARD
				entry["target"] = out.normalized()
		State.FLEE:
			entry["timer"] = float(entry["timer"]) - delta
			var out: Vector3 = entry["target"]
			root.position += out * GameConfig.PECKER_SPEED * delta
			root.position.y += GameConfig.PECKER_RISE * delta
			root.rotation.y = face(Vector2(out.x, out.z))
			_flap(body, sin(_t * GameConfig.PECKER_FLAP_FREQ))
			if float(entry["timer"]) <= 0.0:
				entry["state"] = State.GONE
				entry["timer"] = _rng.randf_range(GameConfig.PECKER_RETURN.x,
					GameConfig.PECKER_RETURN.y)
				root.visible = false
		State.GONE:
			entry["timer"] = float(entry["timer"]) - delta
			if float(entry["timer"]) > 0.0:
				return
			var cell := _pick_cell(true, GameConfig.PECKER_MIN_PLAYER_DIST)
			if cell.x < 0:
				# Nothing cut yet. This is not a failure — it is the birds
				# waiting for a reason to come down.
				entry["timer"] = 2.0
				return
			root.position = LawnModel.cell_center(cell.x, cell.y)
			root.position.y = 0.0
			root.rotation.y = _rng.randf() * TAU
			_flap(body, 0.0, false)
			root.visible = true
			entry["state"] = State.CALM


## Wings exist only in the air. A small bird's folded wing is a few pixels of a
## smooth outline at this size — the first pass drew them spread while the bird
## stood pecking, and it read as a bird permanently about to take off. On the
## ground the body IS the silhouette.
func _flap(body: Node3D, amount: float, flying := true) -> void:
	for side: float in [-1.0, 1.0]:
		var wing := body.get_node_or_null(
			"WingL" if side < 0.0 else "WingR") as Node3D
		if wing == null:
			continue
		wing.visible = flying
		# Beating either side of level. Rotation about +Z lifts +X, so the
		# right wing takes the negative of it to go the same way as the left.
		wing.rotation.z = -side * (0.45 - amount * 0.55)


## Back and forth along the strip in front of the porch. The same triangle wave
## the town's figures use — two points and a line, no path-finding.
## Whether the long walk has happened. Read once at build time rather than per
## frame: it cannot change while a yard is open.
static func is_dog_owned() -> bool:
	return bool(GameState.get_setting("story", "prologue_done", false))


func _tick_dog(entry: Dictionary, delta: float) -> void:
	var root := entry["node"] as Node3D
	var body := entry["body"] as Node3D
	if _road:
		# It has not met him yet. It waits by the basket, and the only thing
		# moving is the tail.
		_wag(body, delta)
		return
	if _owned:
		_tick_dog_follow(entry, root, body, delta)
		return
	entry["phase"] = fmod(float(entry["phase"]) + delta * GameConfig.DOG_SPEED * 0.08, 1.0)
	var k := float(entry["phase"]) * 2.0
	var forward := k <= 1.0
	if not forward:
		k = 2.0 - k
	var was := root.position.x
	root.position.x = _dog_x(k)
	# Faced from where it is actually GOING, not from a hand-written constant
	# per leg: the constants were both the wrong way round, so the dog walked
	# backwards in both directions and turned at neither end.
	if absf(root.position.x - was) > 0.00001:
		root.rotation.y = face(Vector2(signf(root.position.x - was), 0.0))
	var trot := sin(_t * GameConfig.DOG_TROT_FREQ)
	body.position.y = absf(trot) * 0.035
	for leg: String in ["LegFL", "LegBR"]:
		var node := body.get_node_or_null(leg) as Node3D
		if node != null:
			node.rotation.x = trot * 0.5
	for leg: String in ["LegFR", "LegBL"]:
		var node := body.get_node_or_null(leg) as Node3D
		if node != null:
			node.rotation.x = -trot * 0.5
	var tail := body.get_node_or_null("Tail") as Node3D
	if tail != null:
		tail.rotation.y = sin(_t * GameConfig.DOG_TAIL_FREQ) * 0.5


# ---------------------------------------------------------------- placement

## The dog's line, measured out from the north fence.
static func dog_z() -> float:
	return GameConfig.fence_north_z() - GameConfig.DOG_PATH_OUTSET


## Where along that line the dog is, for `k` from 0 to 1.
static func _dog_x(k: float) -> float:
	return lerpf(GameConfig.DOG_RUN_X.x, GameConfig.DOG_RUN_X.y, k)


## His dog, in every yard after the prologue. It walks to where he is and then
## stops SHORT of him: a companion that arrives at your feet is standing in the
## picture, and one that never closes the gap is scenery. The two distances are
## deliberately different — closing to NEAR and only setting off again past
## FAR — because a single threshold makes a dog that twitches in and out of
## walking every time the mower drifts a centimetre.
func _tick_dog_follow(entry: Dictionary, root: Node3D, body: Node3D,
		delta: float) -> void:
	if not player_on:
		_wag(body, delta)
		return
	var flat := Vector2(player_at.x - root.position.x, player_at.z - root.position.z)
	var gap := flat.length()
	var walking := int(entry["state"]) == State.FLEE
	if walking and gap <= GameConfig.DOG_FOLLOW_NEAR:
		entry["state"] = State.CALM
		walking = false
	elif not walking and gap >= GameConfig.DOG_FOLLOW_FAR:
		entry["state"] = State.FLEE
		walking = true
	if not walking:
		# Arrived. NOW it scans the ground around where the player is. The first
		# version let a scent interrupt the walk itself, and a dog that locks
		# onto something five units from its start never follows anyone
		# anywhere — measured: 16.3 units away and it moved 0.7. Following
		# comes first; pointing is what it does once it is beside you.
		var scent := _scent_cell(root)
		if scent.x >= 0:
			var at := LawnModel.cell_center(scent.x, scent.y)
			root.rotation.y = face(Vector2(at.x - root.position.x, at.z - root.position.z))
			_point(body, delta)
		else:
			_wag(body, delta)
		return
	var step := minf(GameConfig.DOG_FOLLOW_SPEED * delta, maxf(gap - 0.2, 0.0))
	var dir := flat.normalized()
	root.position += Vector3(dir.x, 0.0, dir.y) * step
	root.rotation.y = face(dir)
	_trot(body)


## The nearest cell that still has something under it, within scent range of
## the dog, or (-1, -1). Reads the model's own state: a SECRET cell is buried,
## a SECRET_REVEALED one has been found, and the dog loses interest the frame
## it is dug up.
func _scent_cell(root: Node3D) -> Vector2i:
	if not GameConfig.DOG_SCENT_ENABLED or model == null:
		return Vector2i(-1, -1)
	var best := Vector2i(-1, -1)
	var best_d := GameConfig.DOG_SCENT_RANGE
	for cell: Vector2i in model.secret_cells:
		if model.states[LawnModel.index_of(cell.x, cell.y)] != LawnModel.CellState.SECRET:
			continue
		var at := LawnModel.cell_center(cell.x, cell.y)
		var d := Vector2(at.x - root.position.x, at.z - root.position.z).length()
		if d < best_d:
			best_d = d
			best = cell
	return best


## Pointing: legs settle, the tail goes STILL, and the head drops towards the
## ground. The stillness is the signal — a wagging dog is a dog with nothing to
## say.
func _point(body: Node3D, delta: float) -> void:
	_settle_legs(body, delta)
	var w := minf(1.0, GameConfig.IDLE_RECOVER_RATE * delta)
	var tail := body.get_node_or_null("Tail") as Node3D
	if tail != null:
		tail.rotation.y = lerpf(tail.rotation.y, 0.0, w)
	var head := body.get_node_or_null("Head") as Node3D
	if head != null:
		head.rotation.x = lerpf(head.rotation.x, GameConfig.DOG_POINT_HEAD, w)


## Standing about: the tail, and nothing else. A still dog with a still tail is
## a statue, and it is two lines to not be one.
func _wag(body: Node3D, delta: float) -> void:
	_settle_legs(body, delta)
	var tail := body.get_node_or_null("Tail") as Node3D
	if tail != null:
		tail.rotation.y = sin(_t * GameConfig.DOG_TAIL_FREQ) * 0.5
	var head := body.get_node_or_null("Head") as Node3D
	if head != null:
		head.rotation.x = lerpf(head.rotation.x, 0.0,
			minf(1.0, GameConfig.IDLE_RECOVER_RATE * delta))


## The diagonal pairs, which is what a trot is, plus the body's bob.
func _trot(body: Node3D) -> void:
	var beat := sin(_t * GameConfig.DOG_TROT_FREQ)
	body.position.y = absf(beat) * 0.035
	for leg: String in ["LegFL", "LegBR"]:
		var node := body.get_node_or_null(leg) as Node3D
		if node != null:
			node.rotation.x = beat * 0.5
	for leg: String in ["LegFR", "LegBL"]:
		var node := body.get_node_or_null(leg) as Node3D
		if node != null:
			node.rotation.x = -beat * 0.5
	var tail := body.get_node_or_null("Tail") as Node3D
	if tail != null:
		tail.rotation.y = sin(_t * GameConfig.DOG_TAIL_FREQ) * 0.5
	# A running dog is not pointing. Without this the head stayed down from the
	# last scent for the whole walk over, and read as pointing at nothing.
	var head := body.get_node_or_null("Head") as Node3D
	if head != null:
		head.rotation.x = lerpf(head.rotation.x, 0.0, 0.08)


func _settle_legs(body: Node3D, delta: float) -> void:
	var w := minf(1.0, GameConfig.IDLE_RECOVER_RATE * delta)
	body.position.y = lerpf(body.position.y, 0.0, w)
	for leg: String in ["LegFL", "LegBR", "LegFR", "LegBL"]:
		var node := body.get_node_or_null(leg) as Node3D
		if node != null:
			node.rotation.x = lerpf(node.rotation.x, 0.0, w)


## The Godot rotation.y that points a model FACING -Z along `direction` (x, z).
##
## Every model in this project faces -Z and every machine applies
## rotation.y = -yaw for that reason. All three animals had
## `rotation.y = atan2(dir.x, dir.z)`, which aims the model's +Z down the
## direction of travel — so the rabbit bolted tail-first, the bird flew
## backwards and the dog trotted in reverse. It is the same mistake the walker
## had (G14.26), in the same file family, and finding it there should have led
## to sweeping this one. One function now, so it can only be wrong once.
static func face(direction: Vector2) -> float:
	return -atan2(direction.x, -direction.y)


func _player_within(root: Node3D, range_units: float) -> bool:
	if not player_on:
		return false
	var flat := root.position - player_at
	flat.y = 0.0
	return flat.length() < range_units


## Straight out through the NEAREST fence line, which is what a startled animal
## does: it does not pick the prettiest exit, it picks the closest one.
func _bolt_target(from: Vector3) -> Vector3:
	var to_side := GameConfig.HALF_X - absf(from.x)
	var to_end := GameConfig.HALF_Z - absf(from.z)
	if to_side <= to_end:
		return Vector3(signf(from.x) * (GameConfig.fence_side_x() + 2.0),
			0.0, from.z)
	var edge := GameConfig.fence_south_z() if from.z > 0.0 \
		else GameConfig.fence_north_z()
	return Vector3(from.x, 0.0, edge + signf(from.z) * 2.0)


## A mowable cell in the state asked for, far enough from the player. Forty
## tries rather than a shuffled list of every cell: at 384 cells a list costs an
## allocation every time an animal moves, and a miss here is harmless. Forty
## and not twenty-four because early on the cut patch is a small fraction of
## the yard, and at twenty-four the search missed it outright about one time
## in twenty.
func _pick_cell(want_cut: bool, min_dist: float, prefer_edge := false) -> Vector2i:
	if model == null:
		return Vector2i(-1, -1)
	var fallback := Vector2i(-1, -1)
	for _try in 40:
		var col := _rng.randi_range(0, GameConfig.GRID_COLS - 1)
		var row := _rng.randi_range(0, GameConfig.GRID_ROWS - 1)
		if not model.is_mowable(col, row):
			continue
		if model.is_cut(col, row) != want_cut:
			continue
		var at := LawnModel.cell_center(col, row)
		if player_on:
			var flat := at - player_at
			flat.y = 0.0
			if flat.length() < min_dist:
				continue
		if not prefer_edge:
			return Vector2i(col, row)
		if fallback.x < 0:
			fallback = Vector2i(col, row)
		if _borders_uncut(col, row):
			return Vector2i(col, row)
	return fallback


## Whether this cell has long grass next to it. What makes the mown edge worth
## asking for is the cover: a rabbit out in the middle of a finished lawn has
## nowhere to go.
func _borders_uncut(col: int, row: int) -> bool:
	for step: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1),
			Vector2i(0, -1)]:
		var c := col + step.x
		var r := row + step.y
		if not LawnModel.in_bounds(c, r):
			continue
		if model.is_mowable(c, r) and not model.is_cut(c, r):
			return true
	return false


# ---------------------------------------------------------------- bodies

## Returns the node that carries the hop, so the tick does not have to look it
## up: the root holds the position on the ground and the body moves above it.
func _rabbit_body(root: Node3D) -> Node3D:
	var body := Node3D.new()
	body.name = "Body"
	root.add_child(body)
	var fur := _mat("rabbit", GameConfig.RABBIT_FUR)
	var scut := _mat("scut", GameConfig.RABBIT_SCUT)
	var paw := _mat("rabbit_paw", GameConfig.RABBIT_FUR.darkened(0.30))
	# COMPACT and crouched. Two wrong passes: squashed 1.55 in X it was a
	# potato (X is the side axis), and stretched 1.60 in Z it was a seal. A
	# crouched rabbit is barely longer than it is tall — what reads is the
	# high rump, the low head and the ears, not the length.
	_ball(body, 0.115, fur, Vector3(0.0, 0.110, 0.0), Vector3(1.0, 0.92, 1.30)) \
		.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	var head := Node3D.new()
	head.name = "Head"
	# High and well forward, so the profile steps DOWN from rump to head. A
	# head buried at body height is another lump on a tube.
	head.position = Vector3(0.0, 0.170, -0.120)
	body.add_child(head)
	_ball(head, 0.072, fur, Vector3(0.0, 0.0, -0.022), Vector3(0.95, 0.92, 1.15))
	for side: float in [-1.0, 1.0]:
		var ear := Node3D.new()
		ear.name = "EarL" if side < 0.0 else "EarR"
		ear.position = Vector3(side * 0.052, 0.048, 0.008)
		head.add_child(ear)
		# Splayed into a V. THIS is the feature that says rabbit, and it has to
		# survive being seen side-on: two near-parallel blades 0.10 apart
		# collapsed into a single stick from most angles.
		_box(ear, Vector3(0.046, 0.165, 0.014), fur,
			Vector3(0.0, 0.080, 0.008), Vector3(-0.14, 0.0, side * 0.42))
	# The scut is a patch on the rump, sunk in, not a pom-pom behind it.
	_ball(body, 0.042, scut, Vector3(0.0, 0.135, 0.128), Vector3(1.20, 0.95, 0.60))
	# Haunches: the rump is the highest point of a crouched rabbit.
	for side: float in [-1.0, 1.0]:
		_ball(body, 0.068, fur, Vector3(side * 0.078, 0.090, 0.068),
			Vector3(0.80, 1.05, 1.05))
	# Front paws, dark, tucked under the chest. Small, but they are what puts
	# the animal ON the ground instead of floating a centimetre over it.
	for side: float in [-1.0, 1.0]:
		_box(body, Vector3(0.036, 0.034, 0.075), paw,
			Vector3(side * 0.048, 0.018, -0.105))
	return body


func _pecker_body(root: Node3D) -> Node3D:
	var body := Node3D.new()
	body.name = "Body"
	root.add_child(body)
	var feather := _mat("pecker", GameConfig.PECKER_BODY)
	var beak := _mat("beak", GameConfig.PECKER_BEAK)
	_ball(body, 0.075, feather, Vector3(0.0, 0.095, 0.0), Vector3(1.0, 0.9, 1.45)) \
		.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	var head := Node3D.new()
	head.name = "Head"
	head.position = Vector3(0.0, 0.145, -0.06)
	body.add_child(head)
	_ball(head, 0.045, feather, Vector3(0.0, 0.0, -0.025))
	var bill := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 0.017
	cone.height = 0.05
	cone.radial_segments = 5
	cone.rings = 1
	bill.mesh = cone
	bill.material_override = beak
	bill.position = Vector3(0.0, -0.005, -0.075)
	bill.rotation = Vector3(-PI * 0.5, 0.0, 0.0)
	head.add_child(bill)
	# Tail, angled up: it is what makes a small dark lump read as a bird.
	_box(body, Vector3(0.05, 0.014, 0.095), feather,
		Vector3(0.0, 0.10, 0.10), Vector3(0.35, 0.0, 0.0))
	for side: float in [-1.0, 1.0]:
		var wing := Node3D.new()
		wing.name = "WingL" if side < 0.0 else "WingR"
		wing.position = Vector3(side * 0.055, 0.105, 0.0)
		body.add_child(wing)
		var panel := MeshInstance3D.new()
		var prism := PrismMesh.new()
		# Only ever seen in flight, so sized to read there: at 0.13 the beat was
		# a sliver against the body.
		prism.size = Vector3(0.19, 0.012, 0.090)
		panel.mesh = prism
		panel.material_override = feather
		panel.position = Vector3(side * 0.095, 0.0, 0.0)
		wing.add_child(panel)
		wing.visible = false
	return body


func _dog_body(root: Node3D) -> Node3D:
	var body := Node3D.new()
	body.name = "Body"
	root.add_child(body)
	var coat := _mat("dog", GameConfig.DOG_COAT)
	var dark := _mat("dog_dark", GameConfig.DOG_COAT.darkened(0.35))
	# LONG, LOW and level. Three passes to get here and all three failures were
	# the same mistake in a different direction: a round body. 0.34 deep on
	# 0.30 legs was a hippo; 0.26 deep on 0.40 legs was a table; a ball on
	# stilts was a cat. What reads as a dog at any size is a long shallow body
	# with a level back, the head carried FORWARD at about back height, and legs
	# roughly as long as the body is deep.
	_ball(body, 0.150, coat, Vector3(0.0, 0.340, 0.0), Vector3(0.80, 0.78, 2.30)) \
		.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	# A deeper chest at the front, so the back line is level and the profile is
	# not symmetrical front to back.
	_ball(body, 0.115, coat, Vector3(0.0, 0.330, -0.170), Vector3(0.92, 0.98, 1.15))
	_box(body, Vector3(0.090, 0.090, 0.150), coat, Vector3(0.0, 0.375, -0.290),
		Vector3(0.40, 0.0, 0.0))
	var head := Node3D.new()
	head.name = "Head"
	# Forward and only just above the back: a head held high is a cat.
	head.position = Vector3(0.0, 0.410, -0.395)
	body.add_child(head)
	_ball(head, 0.085, coat, Vector3.ZERO, Vector3(0.95, 0.92, 1.15))
	_box(head, Vector3(0.058, 0.050, 0.115), dark, Vector3(0.0, -0.028, -0.105))
	# Ears LAID BACK along the skull. Standing boxes read as two blocks glued on
	# top; folded down they are part of the head's silhouette.
	for side: float in [-1.0, 1.0]:
		_box(head, Vector3(0.030, 0.070, 0.020), coat,
			Vector3(side * 0.058, 0.048, 0.030),
			Vector3(-0.62, 0.0, side * 0.55))
	# Four legs on their own pivots, so front-left and back-right swing
	# together: that diagonal pair is what a trot is. Pivots sit INSIDE the
	# body, and the front pair leans back while the rear pair leans forward —
	# a stance rather than four posts.
	var spots := {"LegFL": [Vector3(-0.070, 0.26, -0.205), 0.12],
		"LegFR": [Vector3(0.070, 0.26, -0.205), 0.12],
		"LegBL": [Vector3(-0.076, 0.26, 0.235), -0.14],
		"LegBR": [Vector3(0.076, 0.26, 0.235), -0.14]}
	for key: String in spots:
		var leg := Node3D.new()
		leg.name = key
		leg.position = spots[key][0]
		leg.rotation.x = float(spots[key][1])
		body.add_child(leg)
		# One piece, no separate paw block: at this size the dark paw read as a
		# brick on the end of a stick.
		_box(leg, Vector3(0.046, 0.28, 0.052), coat, Vector3(0.0, -0.140, 0.0))
	var tail := Node3D.new()
	tail.name = "Tail"
	tail.position = Vector3(0.0, 0.385, 0.300)
	body.add_child(tail)
	_box(tail, Vector3(0.032, 0.032, 0.19), coat, Vector3(0.0, 0.048, 0.078),
		Vector3(-0.72, 0.0, 0.0))
	return body


# ---------------------------------------------------------------- primitives

func _mat(key: String, colour: Color, rough := 0.88) -> StandardMaterial3D:
	if _mats.has(key):
		return _mats[key]
	var mat := StandardMaterial3D.new()
	mat.albedo_color = colour
	mat.roughness = rough
	_mats[key] = mat
	return mat


func _ball(parent: Node3D, radius: float, mat: StandardMaterial3D, pos: Vector3,
		squash := Vector3.ONE) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	# Coarse on purpose: at this size on a phone the whole animal is a few
	# dozen pixels and the extra rings are invisible.
	mesh.radial_segments = 8
	mesh.rings = 4
	node.mesh = mesh
	node.material_override = mat
	node.position = pos
	node.scale = squash
	# NO shadow by default. Measured from directly above the whole yard, six
	# animals cost 105 draw calls with every part casting -- an ear, a paw and
	# a beak each get their own shadow pass, and at this size not one of them
	# is visible in the result. Each animal turns the shadow back ON for its
	# BODY only, which is the blob that actually grounds it.
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(node)
	return node


func _box(parent: Node3D, size: Vector3, mat: StandardMaterial3D, pos: Vector3,
		rot := Vector3.ZERO) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.material_override = mat
	node.position = pos
	node.rotation = rot
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(node)
	return node
