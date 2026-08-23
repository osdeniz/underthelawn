class_name TrafficController
extends Node3D
## G6 street traffic: a purely decorative layer on the §12 road. A fixed pool
## of vehicles (sedan / pickup / SUV / van, random colours) crosses the road in
## both directions at random intervals; every 90-120 s one pulls into a
## neighbour's driveway, kills its lights, waits, backs out and leaves. Cars
## never enter the play area and never collide with anything.

enum State { IDLE, DRIVING, SLOWING, PULLING_IN, PARKED, BACKING_OUT, LEAVING }

const VARIANT_SEDAN := 0
const VARIANT_PICKUP := 1
const VARIANT_SUV := 2
const VARIANT_VAN := 3

var _pool: Array = []          # { root, state, dir, speed, lane_z, head_mat, ... }
var _spawn_timer := 0.0
var _driveway_timer := 0.0
var _rng := RandomNumberGenerator.new()
var _car_stream: AudioStream


func _ready() -> void:
	if not GameConfig.TRAFFIC_ENABLED:
		set_process(false)
		return
	_rng.seed = 20260824
	_car_stream = _find_audio("res://audio/car_pass")
	if _car_stream == null:
		print("[Traffic] audio/car_pass.ogg yok - arac sesi sessiz")
	for i in GameConfig.TRAFFIC_POOL_SIZE:
		_pool.append(_make_car(i % 4))
	_spawn_timer = _rng.randf_range(1.0, 4.0)
	_driveway_timer = _rng.randf_range(GameConfig.TRAFFIC_DRIVEWAY_MIN,
		GameConfig.TRAFFIC_DRIVEWAY_MAX)


static func _find_audio(base: String) -> AudioStream:
	for ext in [".ogg", ".wav", ".mp3"]:
		if ResourceLoader.exists(base + ext):
			return load(base + ext) as AudioStream
	return null


func _process(delta: float) -> void:
	_spawn_timer -= delta
	_driveway_timer -= delta
	if _spawn_timer <= 0.0:
		_spawn_timer = _rng.randf_range(GameConfig.TRAFFIC_INTERVAL_MIN,
			GameConfig.TRAFFIC_INTERVAL_MAX)
		_spawn()

	for car in _pool:
		_update_car(car, delta)


func _spawn() -> void:
	for car in _pool:
		if car["state"] != State.IDLE:
			continue
		var eastbound := _rng.randf() < 0.5
		car["dir"] = 1.0 if eastbound else -1.0
		car["lane_z"] = GameConfig.TRAFFIC_LANE_EAST_Z if eastbound \
			else GameConfig.TRAFFIC_LANE_WEST_Z
		car["speed"] = _rng.randf_range(GameConfig.TRAFFIC_SPEED_MIN,
			GameConfig.TRAFFIC_SPEED_MAX)
		# Every 90-120 s the next car runs the driveway routine instead.
		car["errand"] = _driveway_timer <= 0.0
		if car["errand"]:
			_driveway_timer = _rng.randf_range(GameConfig.TRAFFIC_DRIVEWAY_MIN,
				GameConfig.TRAFFIC_DRIVEWAY_MAX)
			var nx: float = GameConfig.NEIGHBOR_X[_rng.randi_range(0,
				GameConfig.NEIGHBOR_X.size() - 1)]
			car["driveway_x"] = nx + 2.4
		var root: Node3D = car["root"]
		root.position = Vector3(-GameConfig.TRAFFIC_SPAWN_X * car["dir"], 0.0, car["lane_z"])
		# Model faces -Z; eastbound (+X) is yaw -PI/2 in Godot terms.
		root.rotation.y = -PI * 0.5 * car["dir"]
		root.visible = true
		_set_lights(car, true)
		car["state"] = State.DRIVING
		var audio: AudioStreamPlayer3D = car["audio"]
		if audio.stream != null:
			audio.play()
		return


func _update_car(car: Dictionary, delta: float) -> void:
	var root: Node3D = car["root"]
	match car["state"]:
		State.IDLE:
			return
		State.DRIVING:
			root.position.x += car["dir"] * car["speed"] * delta
			if car["errand"] and absf(root.position.x - car["driveway_x"]) \
					< car["speed"] * 1.2:
				car["state"] = State.SLOWING
			elif absf(root.position.x) > GameConfig.TRAFFIC_SPAWN_X:
				_park_in_pool(car)
		State.SLOWING:
			car["speed"] = maxf(car["speed"] - 5.0 * delta, 0.8)
			root.position.x = move_toward(root.position.x, car["driveway_x"],
				car["speed"] * delta)
			if absf(root.position.x - car["driveway_x"]) < 0.05:
				car["state"] = State.PULLING_IN
		State.PULLING_IN:
			# Nose south into the driveway, creep forward.
			root.rotation.y = lerp_angle(root.rotation.y, PI, minf(1.0, 2.5 * delta))
			root.position.z = move_toward(root.position.z, 24.6, 2.2 * delta)
			if root.position.z >= 24.55:
				car["state"] = State.PARKED
				car["wait"] = GameConfig.TRAFFIC_DRIVEWAY_WAIT
				_set_lights(car, false)
		State.PARKED:
			car["wait"] -= delta
			if car["wait"] <= 0.0:
				_set_lights(car, true)
				car["state"] = State.BACKING_OUT
		State.BACKING_OUT:
			root.position.z = move_toward(root.position.z, car["lane_z"], 2.2 * delta)
			if root.position.z <= car["lane_z"] + 0.05:
				root.rotation.y = -PI * 0.5 * car["dir"]
				car["speed"] = GameConfig.TRAFFIC_SPEED_MIN
				car["errand"] = false
				car["state"] = State.LEAVING
		State.LEAVING:
			car["speed"] = minf(car["speed"] + 3.0 * delta, GameConfig.TRAFFIC_SPEED_MAX)
			root.position.x += car["dir"] * car["speed"] * delta
			if absf(root.position.x) > GameConfig.TRAFFIC_SPAWN_X:
				_park_in_pool(car)


func _park_in_pool(car: Dictionary) -> void:
	car["state"] = State.IDLE
	var root: Node3D = car["root"]
	root.visible = false
	var audio: AudioStreamPlayer3D = car["audio"]
	if audio.playing:
		audio.stop()


func _set_lights(car: Dictionary, on: bool) -> void:
	var head: StandardMaterial3D = car["head_mat"]
	var tail: StandardMaterial3D = car["tail_mat"]
	head.emission_energy_multiplier = 1.2 if on else 0.0
	tail.emission_energy_multiplier = 1.0 if on else 0.0


# ---------------------------------------------------------------- build

## G5's car construction technique, parameterised per variant. Every car owns
## its light materials so the driveway routine can switch them off.
func _make_car(variant: int) -> Dictionary:
	var colors: Array = GameConfig.TRAFFIC_COLORS[variant]
	var color: Color = colors[_rng.randi_range(0, colors.size() - 1)]

	var root := Node3D.new()
	root.name = "TrafficCar%d" % _pool.size()
	root.visible = false
	add_child(root)

	var paint := StandardMaterial3D.new()
	paint.albedo_color = color
	paint.metallic = GameConfig.CAR_PAINT_METALLIC
	paint.roughness = GameConfig.CAR_PAINT_ROUGHNESS
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.08, 0.10, 0.13)
	glass.metallic = 0.9
	glass.roughness = 0.08
	var tire := StandardMaterial3D.new()
	tire.albedo_color = Color(0.06, 0.06, 0.07)
	tire.roughness = 0.9
	var head := StandardMaterial3D.new()
	head.albedo_color = Color(1.0, 0.95, 0.75)
	head.emission_enabled = true
	head.emission = Color(1.0, 0.9, 0.6)
	head.emission_energy_multiplier = 1.2
	var tail := StandardMaterial3D.new()
	tail.albedo_color = Color(0.9, 0.1, 0.08)
	tail.emission_enabled = true
	tail.emission = Color(0.9, 0.08, 0.05)
	tail.emission_energy_multiplier = 1.0

	# Variant silhouettes: body height/length and cabin shape differ.
	var body_size := Vector3(1.7, 0.5, 4.0)
	var cabin_size := Vector3(1.5, 0.55, 1.7)
	var cab_z := 0.1
	match variant:
		VARIANT_PICKUP:
			cab_z = -0.7
		VARIANT_SUV:
			body_size = Vector3(1.75, 0.65, 4.1)
			cabin_size = Vector3(1.6, 0.7, 2.5)
			cab_z = 0.2
		VARIANT_VAN:
			body_size = Vector3(1.75, 0.7, 4.3)
			cabin_size = Vector3(1.65, 0.85, 3.0)
			cab_z = 0.35

	_piece(root, body_size, paint, Vector3(0.0, 0.3 + body_size.y * 0.5, 0.0))
	var cab_y := 0.3 + body_size.y + cabin_size.y * 0.5 - 0.05
	_piece(root, cabin_size, paint, Vector3(0.0, cab_y, cab_z))
	_piece(root, Vector3(cabin_size.x - 0.14, cabin_size.y - 0.14, cabin_size.z - 0.2),
		glass, Vector3(0.0, cab_y + 0.03, cab_z))
	if variant == VARIANT_PICKUP:
		_piece(root, Vector3(1.5, 0.06, 1.7), tire, Vector3(0.0, 0.78, 1.0))
		_piece(root, Vector3(1.5, 0.3, 0.06), paint, Vector3(0.0, 0.92, 1.85))

	for side: float in [-1.0, 1.0]:
		_piece(root, Vector3(0.32, 0.14, 0.04), head,
			Vector3(side * 0.55, 0.62, -body_size.z * 0.5 - 0.01))
		_piece(root, Vector3(0.28, 0.12, 0.04), tail,
			Vector3(side * 0.55, 0.62, body_size.z * 0.5 + 0.01))
		for wz: float in [-1.35, 1.35]:
			var wheel := CylinderMesh.new()
			wheel.top_radius = 0.32
			wheel.bottom_radius = 0.32
			wheel.height = 0.22
			wheel.radial_segments = 12
			var mi := MeshInstance3D.new()
			mi.mesh = wheel
			mi.material_override = tire
			mi.position = Vector3(side * 0.85, 0.32, wz)
			mi.rotation.z = PI * 0.5
			root.add_child(mi)

	var audio := AudioStreamPlayer3D.new()
	audio.stream = _car_stream
	audio.unit_size = 8.0
	audio.max_distance = 40.0
	audio.volume_db = -8.0
	root.add_child(audio)

	return {
		"root": root, "state": State.IDLE, "dir": 1.0, "speed": 7.0,
		"lane_z": GameConfig.TRAFFIC_LANE_EAST_Z, "errand": false,
		"driveway_x": 0.0, "wait": 0.0,
		"head_mat": head, "tail_mat": tail, "audio": audio,
	}


func _piece(parent: Node3D, size: Vector3, mat: Material, pos: Vector3) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
