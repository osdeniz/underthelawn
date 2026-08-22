class_name Mower
extends Node3D
## Push mower — REFERENCE.md §6 (parameters) and §7 (movement + control).
##
## COORDINATE NOTE: the spec's convention is yaw = 0 -> north with
## forward = (sin(yaw), 0, -cos(yaw)) and increasing yaw turning right. Godot's
## rotation.y turns the other way, so `yaw` is kept in spec space and applied as
## rotation.y = -yaw. Every formula below is therefore verbatim from the spec.

signal cells_mown(count: int)
signal secret_uncovered(col: int, row: int)

@export var max_speed: float = GameConfig.PUSH_SPEED
@export var deck_radius: float = GameConfig.PUSH_DECK_RADIUS
@export var max_turn: float = GameConfig.PUSH_MAX_TURN
@export var body_radius: float = GameConfig.PUSH_BODY_RADIUS

var model: LawnModel
var tuft_field: TuftField
## Camera yaw in spec space; drag steering is camera-relative (§18 trap 2).
var camera_yaw: float = 0.0

var yaw: float = 0.0
var speed: float = 0.0
var omega: float = 0.0
var throttle: float = 0.0

var _target_yaw: float = 0.0
var _has_target := false
var _touch_index := -1
var _touch_origin := Vector2.ZERO
var _shake_time := 0.0
var _body: Node3D
var _clippings: GPUParticles3D
var _clip_window := 0.0
var _clip_cooldown := 0.0


func _ready() -> void:
	_body = get_node_or_null("Body") as Node3D
	_clippings = get_node_or_null("Clippings") as GPUParticles3D
	_add_fake_ao()
	reset_to_start()


func reset_to_start() -> void:
	yaw = 0.0                       # facing north, towards the house
	speed = 0.0
	omega = 0.0
	throttle = 0.0
	_has_target = false
	_touch_index = -1
	position = Vector3(GameConfig.MOWER_START.x, 0.0, GameConfig.MOWER_START.y)
	_apply_yaw()


func forward() -> Vector3:
	return Vector3(sin(yaw), 0.0, -cos(yaw))


func speed_fraction() -> float:
	return absf(speed) / max_speed


# ---------------------------------------------------------------- input (§7 Push)

func touch_pressed(index: int, screen_pos: Vector2) -> void:
	if _touch_index != -1:
		return
	_touch_index = index
	_touch_origin = screen_pos
	_has_target = false
	throttle = 1.0


func touch_dragged(index: int, screen_pos: Vector2) -> void:
	if index != _touch_index:
		return
	var drag := screen_pos - _touch_origin
	if drag.length() < GameConfig.DRAG_THRESHOLD_PX:
		return
	# Camera-relative: screen up (-y) means "away from the player".
	_target_yaw = camera_yaw + atan2(drag.x, -drag.y)
	_has_target = true


func touch_released(index: int) -> void:
	if index != _touch_index:
		return
	_touch_index = -1
	throttle = 0.0


# ---------------------------------------------------------------- movement (§7)

func _physics_process(delta: float) -> void:
	_update_speed(delta)
	_update_steering(delta)

	position += forward() * speed * delta
	_resolve_walls()
	_resolve_obstacles()
	_apply_yaw()

	_mow(delta)
	_idle_shake(delta)


func _update_speed(delta: float) -> void:
	var target := max_speed * throttle
	# rate = maxSpeed / time, applied per direction (0.4 s up, 0.55 s down).
	var seconds := GameConfig.ACCEL_TIME if target > speed else GameConfig.DECEL_TIME
	var rate := max_speed / seconds
	speed += clampf(target - speed, -rate * delta, rate * delta)


func _update_steering(delta: float) -> void:
	var desired := 0.0
	if _has_target and throttle > 0.0:
		desired = clampf(_shortest_angle(yaw, _target_yaw) * GameConfig.STEER_ERROR_GAIN,
			-max_turn, max_turn)
	omega += (desired - omega) * minf(1.0, GameConfig.STEER_SMOOTHING * delta)
	# Faster travel widens the turning radius by up to 45%.
	yaw += omega * (1.0 - GameConfig.STEER_SPEED_RADIUS_FACTOR * speed_fraction()) * delta


static func _shortest_angle(from_angle: float, to_angle: float) -> float:
	return wrapf(to_angle - from_angle, -PI, PI)


func _apply_yaw() -> void:
	rotation.y = -yaw


## Position is clipped to the lawn; sliding along the wall falls out for free,
## and there is deliberately no auto-turn (§7).
func _resolve_walls() -> void:
	var inset := body_radius * GameConfig.WALL_INSET_FACTOR
	position.x = clampf(position.x, -GameConfig.HALF_X + inset, GameConfig.HALF_X - inset)
	position.z = clampf(position.z, -GameConfig.HALF_Z + inset, GameConfig.HALF_Z - inset)


## Circle vs rectangle closest-point test, pushed out along the normal by the
## penetration depth. No bounce (§7).
func _resolve_obstacles() -> void:
	if model == null:
		return
	for rect in model.collision_rects:
		var p := Vector2(position.x, position.z)
		var closest := Vector2(
			clampf(p.x, rect.position.x, rect.end.x),
			clampf(p.y, rect.position.y, rect.end.y))
		var away := p - closest
		var dist := away.length()
		if dist >= body_radius:
			continue
		if dist < 0.0001:
			# Dead centre: leave along the shallowest axis.
			var to_left := absf(p.x - rect.position.x)
			var to_right := absf(rect.end.x - p.x)
			var to_top := absf(p.y - rect.position.y)
			var to_bottom := absf(rect.end.y - p.y)
			var smallest := minf(minf(to_left, to_right), minf(to_top, to_bottom))
			if smallest == to_left:
				position.x = rect.position.x - body_radius
			elif smallest == to_right:
				position.x = rect.end.x + body_radius
			elif smallest == to_top:
				position.z = rect.position.y - body_radius
			else:
				position.z = rect.end.y + body_radius
			continue
		var push := away / dist * (body_radius - dist)
		position.x += push.x
		position.z += push.y


# ---------------------------------------------------------------- mowing (§4)

## Every cell whose centre falls inside the deck radius is mown. At most one
## haptic and one cut sound per frame, however many cells fall.
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


func _mow(_delta: float) -> void:
	if model == null:
		return
	var stripe := LawnModel.stripe_bucket(forward())
	var center := Vector2(position.x, position.z)
	var origin := LawnModel.cell_at(position - Vector3(deck_radius, 0.0, deck_radius))
	var limit := LawnModel.cell_at(position + Vector3(deck_radius, 0.0, deck_radius))

	var mown := 0
	var revealed: Array[Vector2i] = []
	for row in range(origin.y, limit.y + 1):
		for col in range(origin.x, limit.x + 1):
			if not LawnModel.in_bounds(col, row):
				continue
			var cc := LawnModel.cell_center(col, row)
			if Vector2(cc.x, cc.z).distance_to(center) > deck_radius:
				continue
			var result := model.mow(col, row, stripe)
			if result == LawnModel.MowResult.NONE:
				continue
			mown += 1
			if tuft_field:
				tuft_field.cut_cell(col, row, rotation.y)
			if result == LawnModel.MowResult.SECRET_REVEALED:
				revealed.append(Vector2i(col, row))

	_update_clippings(_delta, mown)

	if mown > 0:
		Haptics.light()
		AudioDirector.play_cut()
		cells_mown.emit(mown)
	for cell in revealed:
		secret_uncovered.emit(cell.x, cell.y)


# ---------------------------------------------------------------- feel (§6)

func _idle_shake(delta: float) -> void:
	if _body == null:
		return
	_shake_time += delta
	var phase := fmod(_shake_time, GameConfig.IDLE_SHAKE_PERIOD) / GameConfig.IDLE_SHAKE_PERIOD
	var wave := sin(phase * TAU)
	_body.position = Vector3(
		GameConfig.IDLE_SHAKE.x * wave, GameConfig.IDLE_SHAKE.y * wave, 0.0)


## Radial dark circle under the mower — contact shading, since SSAO is
## unavailable on the Mobile renderer (§13).
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
