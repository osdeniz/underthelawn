class_name Surprises
extends Node3D
## Small things that happen once in a yard (G29, gamification sprint 2). None
## of them pay, none of them are announced; a player who looks up sees one and
## a player who does not loses nothing. Each yard plans at most
## SURPRISE_MAX_PER_YARD of the six from its own seed, so the same yard shows
## the same ones and a replay of another shows different ones.
##
##   kite         a kite over the fence on a clear day, gone in half a minute
##   butterflies  two over the cut grass near the machine, then away
##   ball         a ball rolls in from the neighbour's side and stops
##   bird         a bird lands on the mower when it has been left standing
##   cloud        a cloud's shadow crosses the yard
##   window       a window in the house lights up at dusk

const KITE := "kite"
const BUTTERFLIES := "butterflies"
const BALL := "ball"
const BIRD := "bird"
const CLOUD := "cloud"
const WINDOW := "window"
const ALL: Array[String] = [KITE, BUTTERFLIES, BALL, BIRD, CLOUD, WINDOW]

var model: LawnModel
var variant: LevelVariant
var animals: Animals
## Fed by the game each frame.
var player_at := Vector3.ZERO
var mower: Node3D
var parked_seconds := 0.0

var _planned: Array[Dictionary] = []   # {id, at, fired}
var _live: Array[Dictionary] = []      # {id, node, t, ...}
var _fired: Array[String] = []
var _rng := RandomNumberGenerator.new()
var _mats := {}
var _t := 0.0


static func build(parent: Node3D, lawn_model: LawnModel, level: LevelVariant,
		fauna: Animals) -> Surprises:
	if not GameConfig.SURPRISES_ENABLED or level == null or level.vignette or level.is_road():
		return null
	var node := Surprises.new()
	node.name = "Surprises"
	node.model = lawn_model
	node.variant = level
	node.animals = fauna
	parent.add_child(node)
	node.plan(level.decor_seed)
	return node


## Which of the six this yard could show at all.
static func eligible(level: LevelVariant) -> Array[String]:
	var out: Array[String] = []
	var clear := level.weather == "clear"
	var night := level.time_of_day == "night"
	var evening := level.time_of_day in ["dusk", "sunset", "night", "golden"]
	var bare := level.palette_id in ["ASH", "SNOW", "SAND", "LAKE"]
	if clear and not night:
		out.append(KITE)
		out.append(CLOUD)
	if clear and not bare:
		out.append(BUTTERFLIES)
	if not level.is_lake():
		out.append(BALL)
		out.append(BIRD)
	if evening and not level.is_harvest():
		out.append(WINDOW)
	return out


func plan(seed_value: int) -> void:
	set_meta("no_bake", true)
	_rng.seed = seed_value if seed_value != 0 else 20260907
	var pool := eligible(variant)
	# Fisher-Yates with the yard's own numbers.
	for i in range(pool.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var tmp := pool[i]
		pool[i] = pool[j]
		pool[j] = tmp
	_planned.clear()
	for i in mini(GameConfig.SURPRISE_MAX_PER_YARD, pool.size()):
		_planned.append({"id": pool[i], "fired": false,
			"at": _rng.randf_range(GameConfig.SURPRISE_WINDOW.x, GameConfig.SURPRISE_WINDOW.y)})


func planned_ids() -> Array[String]:
	var out: Array[String] = []
	for p: Dictionary in _planned:
		out.append(str(p["id"]))
	return out


func fired_ids() -> Array[String]:
	return _fired


## Start one now, whatever the plan said (tests, and the dev menu).
func force(id: String) -> bool:
	return _start(id)


func _process(delta: float) -> void:
	_t += delta
	if model != null:
		var ratio := model.completion_ratio()
		for p: Dictionary in _planned:
			if bool(p["fired"]) or ratio < float(p["at"]):
				continue
			# The bird waits for a parked machine as well as the moment.
			if str(p["id"]) == BIRD and parked_seconds < GameConfig.SURPRISE_BIRD_PARK_SECONDS:
				continue
			p["fired"] = true
			_start(str(p["id"]))
	for i in range(_live.size() - 1, -1, -1):
		var ev := _live[i]
		ev["t"] = float(ev["t"]) + delta
		var done := false
		match str(ev["id"]):
			KITE: done = _tick_kite(ev, delta)
			BUTTERFLIES: done = _tick_butterflies(ev, delta)
			BALL: done = _tick_ball(ev, delta)
			BIRD: done = _tick_bird(ev, delta)
			CLOUD: done = _tick_cloud(ev, delta)
			WINDOW: done = _tick_window(ev, delta)
		if done:
			var node := ev.get("node") as Node3D
			if node != null and is_instance_valid(node) and not bool(ev.get("keep", false)):
				node.queue_free()
			_live.remove_at(i)


func _start(id: String) -> bool:
	if _fired.has(id):
		return false
	var ev: Dictionary = {}
	match id:
		KITE: ev = _spawn_kite()
		BUTTERFLIES: ev = _spawn_butterflies()
		BALL: ev = _spawn_ball()
		BIRD: ev = _spawn_bird()
		CLOUD: ev = _spawn_cloud()
		WINDOW: ev = _spawn_window()
	if ev.is_empty():
		return false
	ev["id"] = id
	ev["t"] = 0.0
	_live.append(ev)
	_fired.append(id)
	return true


# ---------------------------------------------------------------- kite

func _spawn_kite() -> Dictionary:
	var root := Node3D.new()
	root.name = "Kite"
	add_child(root)
	var sail := _box(root, Vector3(0.9, 0.9, 0.03), _mat("kite", Color(0.86, 0.36, 0.22)),
		Vector3.ZERO, Vector3(0.0, 0.0, PI * 0.25))
	# The one shadow worth paying for: the diamond sliding over the grass is
	# how a player looking at the machine notices the kite at all.
	sail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	_box(root, Vector3(0.9, 0.04, 0.02), _mat("kite_spar", Color(0.35, 0.25, 0.15)), Vector3.ZERO)
	_box(root, Vector3(0.04, 0.9, 0.02), _mats["kite_spar"], Vector3.ZERO)
	for i in 4:
		_box(root, Vector3(0.16, 0.05, 0.02), _mat("kite_bow", Color(0.95, 0.85, 0.40)),
			Vector3(0.0, -0.75 - float(i) * 0.32, 0.0))
	# The string goes down and off towards where a hand would be.
	_box(root, Vector3(0.015, 4.0, 0.015), _mat("kite_string", Color(0.9, 0.9, 0.9)),
		Vector3(-0.8, -2.2, 0.6), Vector3(0.0, 0.0, -0.35))
	var side := 1.0 if _rng.randf() < 0.5 else -1.0
	# Low, and over the yard itself: the play camera looks down, and a kite at
	# height 9 crossed above the top of the frame unseen (measured). At four
	# it dips through the upper third of the picture and its shadow crosses
	# the grass.
	root.position = Vector3(-side * (GameConfig.HALF_X + 7.0), GameConfig.SURPRISE_KITE_HEIGHT,
		_rng.randf_range(-GameConfig.HALF_Z * 0.7, GameConfig.HALF_Z * 0.5))
	return {"node": root, "side": side, "z0": root.position.z}


func _tick_kite(ev: Dictionary, delta: float) -> bool:
	var root := ev["node"] as Node3D
	var t := float(ev["t"])
	var span := (GameConfig.HALF_X + 7.0) * 2.0
	root.position.x += float(ev["side"]) * span / GameConfig.SURPRISE_KITE_SECONDS * delta
	root.position.y = GameConfig.SURPRISE_KITE_HEIGHT + sin(t * 0.9) * 0.8
	root.position.z = float(ev["z0"]) + sin(t * 0.5) * 1.2
	root.rotation.z = sin(t * 1.3) * 0.18
	root.rotation.y = -float(ev["side"]) * 0.5
	return t > GameConfig.SURPRISE_KITE_SECONDS


# ---------------------------------------------------------------- butterflies

func _spawn_butterflies() -> Dictionary:
	var root := Node3D.new()
	root.name = "Butterflies"
	add_child(root)
	var colours := [Color(0.95, 0.80, 0.30), Color(0.92, 0.92, 0.96)]
	var flies: Array = []
	for i in 2:
		var fly := Node3D.new()
		fly.name = "Butterfly%d" % i
		root.add_child(fly)
		var mat := _mat("wing%d" % i, colours[i])
		var l := _box(fly, Vector3(0.22, 0.16, 0.01), mat, Vector3(-0.11, 0.0, 0.0))
		l.name = "WingL"
		var r := _box(fly, Vector3(0.22, 0.16, 0.01), mat, Vector3(0.11, 0.0, 0.0))
		r.name = "WingR"
		fly.position = player_at + Vector3(_rng.randf_range(-1.5, 1.5), 0.6, _rng.randf_range(-1.5, 1.5))
		flies.append({"node": fly, "target": fly.position, "next": 0.0, "phase": _rng.randf() * TAU})
	return {"node": root, "flies": flies}


func _tick_butterflies(ev: Dictionary, delta: float) -> bool:
	var t := float(ev["t"])
	var leaving := t > GameConfig.SURPRISE_BUTTERFLY_SECONDS
	for f: Dictionary in ev["flies"]:
		var fly := f["node"] as Node3D
		var phase := float(f["phase"])
		if t >= float(f["next"]) and not leaving:
			# Over the cut grass near the machine: the flowers are gone, the
			# clippings are what they come for.
			var cell := _cut_cell_near(player_at, 3.5)
			var at := LawnModel.cell_center(cell.x, cell.y) if cell.x >= 0 else player_at
			f["target"] = Vector3(at.x, 0.45 + _rng.randf() * 0.4, at.z)
			f["next"] = t + _rng.randf_range(1.2, 2.6)
		var target: Vector3 = f["target"]
		if leaving:
			target = fly.position + Vector3(0.0, 2.5, -1.0)
		fly.position = fly.position.lerp(target, 1.0 - exp(-1.6 * delta))
		fly.position.y += sin(_t * 7.0 + phase) * 0.004
		var flap := absf(sin(_t * 9.0 + phase)) * 1.1
		(fly.get_node("WingL") as Node3D).rotation.z = flap
		(fly.get_node("WingR") as Node3D).rotation.z = -flap
	return t > GameConfig.SURPRISE_BUTTERFLY_SECONDS + 2.5


# ---------------------------------------------------------------- ball

func _spawn_ball() -> Dictionary:
	var root := Node3D.new()
	root.name = "Ball"
	add_child(root)
	var body := _ball(root, GameConfig.SURPRISE_BALL_RADIUS, _mat("ball", Color(0.85, 0.30, 0.25)),
		Vector3(0.0, GameConfig.SURPRISE_BALL_RADIUS, 0.0))
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	# A pale band so the roll reads.
	_box(body, Vector3(GameConfig.SURPRISE_BALL_RADIUS * 2.02, 0.08, GameConfig.SURPRISE_BALL_RADIUS * 2.02),
		_mat("ball_band", Color(0.95, 0.92, 0.85)), Vector3.ZERO)
	var side := 1.0 if _rng.randf() < 0.5 else -1.0
	root.position = Vector3(side * (GameConfig.HALF_X + 1.2), 0.0,
		_rng.randf_range(-GameConfig.HALF_Z * 0.7, GameConfig.HALF_Z * 0.7))
	return {"node": root, "body": body, "v": -side * GameConfig.SURPRISE_BALL_SPEED, "keep": true}


func _tick_ball(ev: Dictionary, delta: float) -> bool:
	var root := ev["node"] as Node3D
	var body := ev["body"] as Node3D
	var v := float(ev["v"]) * exp(-GameConfig.SURPRISE_BALL_DRAG * delta)
	ev["v"] = v
	root.position.x += v * delta
	body.rotation.z -= v * delta / GameConfig.SURPRISE_BALL_RADIUS
	return absf(v) < 0.05


func ball_speed() -> float:
	for ev: Dictionary in _live:
		if str(ev["id"]) == BALL:
			return absf(float(ev["v"]))
	return 0.0


# ---------------------------------------------------------------- bird on the mower

func _spawn_bird() -> Dictionary:
	if mower == null or not is_instance_valid(mower):
		return {}
	var root := Node3D.new()
	root.name = "MowerBird"
	add_child(root)
	if animals != null and is_instance_valid(animals):
		animals._pecker_body(root)
	else:
		_ball(root, 0.14, _mat("bird", Color(0.35, 0.30, 0.28)), Vector3(0.0, 0.16, 0.0))
	root.position = mower.global_position + Vector3(0.0, GameConfig.SURPRISE_BIRD_PERCH, -0.1)
	root.rotation.y = _rng.randf() * TAU
	return {"node": root, "leaving": false}


func _tick_bird(ev: Dictionary, delta: float) -> bool:
	var root := ev["node"] as Node3D
	if not bool(ev["leaving"]):
		var phase := float(ev["t"])
		# It stays while the machine does. The moment it moves, off.
		if parked_seconds <= 0.0 or mower == null or not is_instance_valid(mower):
			ev["leaving"] = true
			ev["t"] = 0.0
			AudioDirector.play_bird_takeoff()
			return false
		root.rotation.y += sin(phase * 0.8) * delta * 0.5
		return false
	root.position += Vector3(0.0, 2.2, -1.8) * delta
	if animals != null and is_instance_valid(animals):
		animals._flap(root.get_child(0) as Node3D, sin(_t * GameConfig.PECKER_FLAP_FREQ))
	return float(ev["t"]) > 1.6


# ---------------------------------------------------------------- cloud shadow

func _spawn_cloud() -> Dictionary:
	var mi := MeshInstance3D.new()
	mi.name = "CloudShadow"
	var quad := QuadMesh.new()
	quad.size = GameConfig.SURPRISE_CLOUD_SIZE
	var mat := StandardMaterial3D.new()
	var tex := TextureLibrary.find("cloud_billboard")
	if tex != null:
		mat.albedo_texture = tex
	mat.albedo_color = GameConfig.SURPRISE_CLOUD_COLOUR
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.no_depth_test = false
	quad.material = mat
	mi.mesh = quad
	mi.rotation.x = -PI * 0.5
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	var side := 1.0 if _rng.randf() < 0.5 else -1.0
	mi.position = Vector3(-side * (GameConfig.HALF_X + GameConfig.SURPRISE_CLOUD_SIZE.x * 0.6),
		0.06, _rng.randf_range(-GameConfig.HALF_Z * 0.4, GameConfig.HALF_Z * 0.4))
	return {"node": mi, "side": side}


func _tick_cloud(ev: Dictionary, delta: float) -> bool:
	var mi := ev["node"] as Node3D
	var span := (GameConfig.HALF_X + GameConfig.SURPRISE_CLOUD_SIZE.x * 0.6) * 2.0
	mi.position.x += float(ev["side"]) * span / GameConfig.SURPRISE_CLOUD_SECONDS * delta
	return float(ev["t"]) > GameConfig.SURPRISE_CLOUD_SECONDS


# ---------------------------------------------------------------- the window

## The house's glass panes are boxes of one size; one of them gets a warm
## emissive material that fades in. Nothing is added to the scene.
func _spawn_window() -> Dictionary:
	var pane := _find_pane()
	if pane == null:
		return {}
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.98, 0.80, 0.50)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.78, 0.45)
	mat.emission_energy_multiplier = 0.0
	pane.material_override = mat
	return {"node": pane, "mat": mat, "keep": true}


func _tick_window(ev: Dictionary, _delta: float) -> bool:
	var mat := ev["mat"] as StandardMaterial3D
	var k := clampf(float(ev["t"]) / 2.0, 0.0, 1.0)
	mat.emission_energy_multiplier = k * GameConfig.SURPRISE_WINDOW_GLOW
	return k >= 1.0


func window_lit() -> bool:
	var pane := _find_pane_lit()
	return pane != null


## A window anywhere in the scene: the house's glass panes (1.3×1.05) or a
## derelict neighbour's dark window (0.95×0.75). No evening chapter has the
## main house, so in practice it is one of the empty houses across the way
## that lights — which, in a town being resettled, is the right story.
func _find_pane() -> MeshInstance3D:
	var scene := get_parent()
	while scene != null and scene.get_parent() != null and not scene.has_method("select_mower"):
		scene = scene.get_parent()
	if scene == null:
		return null
	var panes: Array[MeshInstance3D] = []
	_collect_panes(scene, panes)
	if panes.is_empty():
		return null
	return panes[_rng.randi_range(0, panes.size() - 1)]


func _collect_panes(node: Node, into: Array[MeshInstance3D]) -> void:
	var mi := node as MeshInstance3D
	if mi != null and mi.mesh is BoxMesh:
		var size := (mi.mesh as BoxMesh).size
		var glass := absf(size.x - 1.3) < 0.01 and absf(size.y - 1.05) < 0.01 and size.z < 0.05
		var derelict := absf(size.x - 0.95) < 0.01 and absf(size.y - 0.75) < 0.01 and size.z < 0.05
		if glass or derelict:
			into.append(mi)
	for child in node.get_children():
		_collect_panes(child, into)


func _find_pane_lit() -> MeshInstance3D:
	for ev: Dictionary in _live:
		if str(ev["id"]) == WINDOW:
			return ev["node"] as MeshInstance3D
	return null


# ---------------------------------------------------------------- helpers

func _cut_cell_near(at: Vector3, radius: float) -> Vector2i:
	if model == null:
		return Vector2i(-1, -1)
	var centre := LawnModel.cell_at(at)
	var best := Vector2i(-1, -1)
	var tries := 12
	while tries > 0:
		tries -= 1
		var c := Vector2i(centre.x + _rng.randi_range(-int(radius), int(radius)),
			centre.y + _rng.randi_range(-int(radius), int(radius)))
		if model.is_cut(c.x, c.y):
			return c
		if best.x < 0 and LawnModel.in_bounds(c.x, c.y):
			best = c
	return best


func _mat(key: String, colour: Color, rough := 0.85) -> StandardMaterial3D:
	if _mats.has(key):
		return _mats[key]
	var mat := StandardMaterial3D.new()
	mat.albedo_color = colour
	mat.roughness = rough
	_mats[key] = mat
	return mat


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


func _ball(parent: Node3D, radius: float, mat: StandardMaterial3D, pos: Vector3) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 10
	mesh.rings = 5
	node.mesh = mesh
	node.material_override = mat
	node.position = pos
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(node)
	return node
