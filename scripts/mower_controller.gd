class_name MowerController
extends Node3D
## Movement core shared by all three mowers — REFERENCE.md §7 "ortak hareket
## çekirdeği". The three types differ ONLY in their parameter set (§6), their
## input source and their model; everything below is identical for all of them.
##
## COORDINATE NOTE (§2): yaw = 0 faces north, forward = (sin yaw, 0, -cos yaw),
## and yaw grows clockwise. Godot's rotation.y grows the other way, so `yaw` is
## kept in spec space and applied as rotation.y = -yaw. Every §7 formula below is
## therefore verbatim.
##
## Subclasses override _gather_input() to set `throttle` and `desired_omega`.

signal cells_mown(count: int)
signal secret_uncovered(col: int, row: int)

## Index into GameConfig.MOWER_TYPES; set by _type_index() in each subclass.
var params: Dictionary = {}

var model: LawnModel
var tuft_field: TuftField
## Camera yaw in spec space; drag/swipe input is camera-relative (§18 trap 2).
var camera_yaw: float = 0.0
## The active Camera3D, for ray picks (robot ground taps).
var camera: Camera3D

var yaw: float = 0.0
var speed: float = 0.0
var omega: float = 0.0
var throttle: float = 0.0
## Set by _gather_input each tick; smoothed into `omega` by the core.
var desired_omega: float = 0.0

var is_active := false

var _body: Node3D
var _clippings: GPUParticles3D
var _clip_window := 0.0
var _clip_cooldown := 0.0
var _shake_time := 0.0


# ---------------------------------------------------------------- setup

func _ready() -> void:
	params = GameConfig.MOWER_TYPES[type_index()]
	_body = get_node_or_null("Body") as Node3D
	_clippings = get_node_or_null("Clippings") as GPUParticles3D
	_add_fake_ao()
	set_active(false)


## Subclasses return their index into GameConfig.MOWER_TYPES.
func type_index() -> int:
	return GameConfig.MOWER_PUSH


func max_speed() -> float:
	return params["speed"]


func deck_radius() -> float:
	return params["deck"]


func max_turn() -> float:
	return params["max_turn"]


func body_radius() -> float:
	return params["body"]


## 0 means no reverse gear (§6).
func reverse_factor() -> float:
	return params["reverse"]


func speed_fraction() -> float:
	return absf(speed) / maxf(max_speed(), 0.001)


func forward() -> Vector3:
	return Vector3(sin(yaw), 0.0, -cos(yaw))


func right() -> Vector3:
	return Vector3(cos(yaw), 0.0, sin(yaw))


## Only the active mower is visible and simulated.
func set_active(value: bool) -> void:
	is_active = value
	visible = value
	set_physics_process(value)
	set_process(value)
	if not value:
		speed = 0.0
		omega = 0.0
		throttle = 0.0
		desired_omega = 0.0
		if _clippings:
			_clippings.emitting = false
	_on_active_changed(value)


## Hook for subclasses (route planning, input reset).
func _on_active_changed(_value: bool) -> void:
	pass


## Places this mower where the previous one stood; speed resets (§ selector).
func adopt_state(from_position: Vector3, from_yaw: float) -> void:
	position = Vector3(from_position.x, 0.0, from_position.z)
	yaw = from_yaw
	speed = 0.0
	omega = 0.0
	throttle = 0.0
	desired_omega = 0.0
	_apply_yaw()


func reset_to_start() -> void:
	yaw = 0.0
	speed = 0.0
	omega = 0.0
	throttle = 0.0
	desired_omega = 0.0
	position = Vector3(GameConfig.MOWER_START.x, 0.0, GameConfig.MOWER_START.y)
	_apply_yaw()
	_on_reset()


func _on_reset() -> void:
	pass


# ---------------------------------------------------------------- core loop (§7)

func _physics_process(delta: float) -> void:
	_gather_input(delta)
	_update_speed(delta)
	_update_steering(delta)

	position += forward() * speed * delta
	_resolve_walls()
	_resolve_obstacles()
	_apply_yaw()

	_mow(delta)
	_idle_shake(delta)


## Subclasses set `throttle` (-reverse..1) and `desired_omega` here.
func _gather_input(_delta: float) -> void:
	pass


func _update_speed(delta: float) -> void:
	var target := max_speed() * throttle
	# rate = maxSpeed / time, 0.4 s up and 0.55 s down (§7).
	var seconds := GameConfig.ACCEL_TIME if absf(target) > absf(speed) else GameConfig.DECEL_TIME
	var rate := max_speed() / seconds
	speed += clampf(target - speed, -rate * delta, rate * delta)


func _update_steering(delta: float) -> void:
	omega += (desired_omega - omega) * minf(1.0, GameConfig.STEER_SMOOTHING * delta)
	# Faster travel widens the turning radius by up to 45%.
	yaw += omega * (1.0 - GameConfig.STEER_SPEED_RADIUS_FACTOR * speed_fraction()) * delta


static func shortest_angle(from_angle: float, to_angle: float) -> float:
	return wrapf(to_angle - from_angle, -PI, PI)


## Turn towards a world-space heading using the §7 error gain.
func steer_towards(target_yaw: float) -> void:
	desired_omega = clampf(
		shortest_angle(yaw, target_yaw) * GameConfig.STEER_ERROR_GAIN,
		-max_turn(), max_turn())


func _apply_yaw() -> void:
	rotation.y = -yaw


## Position clipped to the lawn; sliding falls out for free and there is
## deliberately no auto-turn (§7).
func _resolve_walls() -> void:
	var inset := body_radius() * GameConfig.WALL_INSET_FACTOR
	position.x = clampf(position.x, -GameConfig.HALF_X + inset, GameConfig.HALF_X - inset)
	position.z = clampf(position.z, -GameConfig.HALF_Z + inset, GameConfig.HALF_Z - inset)


## Circle vs rectangle closest-point test, pushed out along the normal by the
## penetration depth. No bounce (§7).
func _resolve_obstacles() -> void:
	if model == null:
		return
	var radius := body_radius()
	for rect in model.collision_rects:
		var p := Vector2(position.x, position.z)
		var closest := Vector2(
			clampf(p.x, rect.position.x, rect.end.x),
			clampf(p.y, rect.position.y, rect.end.y))
		var away := p - closest
		var dist := away.length()
		if dist >= radius:
			continue
		if dist < 0.0001:
			var to_left := absf(p.x - rect.position.x)
			var to_right := absf(rect.end.x - p.x)
			var to_top := absf(p.y - rect.position.y)
			var to_bottom := absf(rect.end.y - p.y)
			var smallest := minf(minf(to_left, to_right), minf(to_top, to_bottom))
			if smallest == to_left:
				position.x = rect.position.x - radius
			elif smallest == to_right:
				position.x = rect.end.x + radius
			elif smallest == to_top:
				position.z = rect.position.y - radius
			else:
				position.z = rect.end.y + radius
			continue
		var push := away / dist * (radius - dist)
		position.x += push.x
		position.z += push.y


# ---------------------------------------------------------------- mowing (§4)

## Every cell whose centre falls inside the deck radius is mown, with at most
## one haptic and one cut sound per frame however many cells fall.
func _mow(delta: float) -> void:
	if model == null:
		return
	var radius := deck_radius()
	var stripe := LawnModel.stripe_bucket(forward())
	var center := Vector2(position.x, position.z)
	var origin := LawnModel.cell_at(position - Vector3(radius, 0.0, radius))
	var limit := LawnModel.cell_at(position + Vector3(radius, 0.0, radius))

	var mown := 0
	var revealed: Array[Vector2i] = []
	for row in range(origin.y, limit.y + 1):
		for col in range(origin.x, limit.x + 1):
			if not LawnModel.in_bounds(col, row):
				continue
			var cc := LawnModel.cell_center(col, row)
			if Vector2(cc.x, cc.z).distance_to(center) > radius:
				continue
			var result := model.mow(col, row, stripe)
			if result == LawnModel.MowResult.NONE:
				continue
			mown += 1
			if tuft_field:
				tuft_field.cut_cell(col, row, rotation.y)
			if result == LawnModel.MowResult.SECRET_REVEALED:
				revealed.append(Vector2i(col, row))

	_update_clippings(delta, mown)

	if mown > 0:
		Haptics.light()
		AudioDirector.play_cut()
		cells_mown.emit(mown)
	for cell in revealed:
		secret_uncovered.emit(cell.x, cell.y)


## Leaf clippings spray from the right side only while cells are actually
## falling, in 0.06 s bursts at most every 0.12 s (§9).
func _update_clippings(delta: float, mown: int) -> void:
	if _clippings == null:
		return
	_clip_cooldown = maxf(_clip_cooldown - delta, 0.0)
	if _clip_window > 0.0:
		_clip_window -= delta
		if _clip_window <= 0.0:
			_clippings.emitting = false
	if mown > 0 and _clip_cooldown <= 0.0:
		_clippings.emitting = true
		_clip_window = GameConfig.CLIP_EMIT_TIME
		_clip_cooldown = GameConfig.CLIP_MIN_INTERVAL


# ---------------------------------------------------------------- feel

## Engine idle shudder on the visual group only (§6). Subclasses with no engine
## can override this to do nothing.
func _idle_shake(delta: float) -> void:
	if _body == null:
		return
	_shake_time += delta
	var phase := fmod(_shake_time, GameConfig.IDLE_SHAKE_PERIOD) / GameConfig.IDLE_SHAKE_PERIOD
	var wave := sin(phase * TAU)
	_body.position = Vector3(
		GameConfig.IDLE_SHAKE.x * wave, GameConfig.IDLE_SHAKE.y * wave, 0.0)


## Radial dark circle underneath — contact shading, since SSAO does not work on
## the Mobile renderer (§13).
func _add_fake_ao() -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2(GameConfig.FAKE_AO_MOWER_SIZE, GameConfig.FAKE_AO_MOWER_SIZE)
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = TextureLibrary.ao_radial()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var mi := MeshInstance3D.new()
	mi.name = "FakeAO"
	mi.mesh = quad
	mi.material_override = mat
	mi.rotation.x = -PI * 0.5
	mi.position = Vector3(0.0, 0.02, 0.0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


# ---------------------------------------------------------------- input routing

## Game forwards raw touches; each type consumes what it needs.
func on_touch_pressed(_index: int, _screen_pos: Vector2) -> void:
	pass


func on_touch_dragged(_index: int, _screen_pos: Vector2) -> void:
	pass


func on_touch_released(_index: int, _screen_pos: Vector2) -> void:
	pass


## Ray/plane intersection with the ground, clamped inside the lawn.
func ground_point(screen_pos: Vector2) -> Vector3:
	if camera == null:
		return position
	var origin := camera.project_ray_origin(screen_pos)
	var dir := camera.project_ray_normal(screen_pos)
	if absf(dir.y) < 0.0001:
		return position
	var t := -origin.y / dir.y
	if t < 0.0:
		return position
	var hit := origin + dir * t
	return clamp_to_lawn(hit)


static func clamp_to_lawn(point: Vector3) -> Vector3:
	return Vector3(
		clampf(point.x, -GameConfig.HALF_X + 0.4, GameConfig.HALF_X - 0.4),
		0.0,
		clampf(point.z, -GameConfig.HALF_Z + 0.4, GameConfig.HALF_Z - 0.4))
