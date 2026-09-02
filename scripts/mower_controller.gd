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
## A cut cell held scrap (G9): (col, row, value).
signal scrap_found(col: int, row: int, value: int)
## A crate of produce under the grass (G14.12), banked separately from money.
signal food_found(col: int, row: int, value: int)

## Index into GameConfig.MOWER_TYPES; set by _type_index() in each subclass.
var params: Dictionary = {}

var model: LawnModel
var tuft_field: TuftField
## Camera yaw in spec space; drag/swipe input is camera-relative (§18 trap 2).
var camera_yaw: float = 0.0

# Shared drag pad state (G6.12).
var _pad_index := -1
var _pad_origin := Vector2.ZERO
var _pad_stick := Vector2.ZERO
## Desktop keyboard state (G14): held this frame, and held last frame, so
## releasing the keys can stop the mower without stamping on a live touch.
var _keyboard_active := false
var _keyboard_was_active := false
## Latest drag position, for the HUD's pad ring.
var _pad_now := Vector2.ZERO
# Camera yaw LATCHED when the finger went down. The camera yaw chases the
# mower's own yaw, so a mower that derives its heading from the live camera yaw
# (the blade) feeds back into itself and spirals — every direction but straight
# ahead curved away. Freezing the frame for the duration of the gesture breaks
# the loop.
var _pad_camera_yaw := 0.0

# Previous deck centre, for the swept mow (G6.12).
## Set by Game; holds this chapter's buried salvage (G9).
var scrap_field: ScrapField

var _mow_from := Vector2.ZERO
var _mow_valid := false
## The active Camera3D, for ray picks (robot ground taps).
var camera: Camera3D

var yaw: float = 0.0
var speed: float = 0.0
var omega: float = 0.0
var throttle: float = 0.0
## Set by _gather_input each tick; smoothed into `omega` by the core.
var desired_omega: float = 0.0

var is_active := false
## Stopped where it stands while the player walks (G14.16). Not the same as
## inactive: an inactive mower is hidden and unsimulated, a parked one is still
## in the yard and still reading the controls for whoever needs them.
var is_parked := false

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
	# G10: the workshop's tier bonus rides on top of the §7 base speed.
	return params["speed"] * Garage.speed_multiplier(type_index())


func deck_radius() -> float:
	return params["deck"]


func max_turn() -> float:
	return params["max_turn"]


func body_radius() -> float:
	return params["body"]


## 0 means no reverse gear (§6).
func reverse_factor() -> float:
	return params["reverse"]


## Per-type steering tuning (G6.7); falls back to §7's shared defaults.
func steer_gain() -> float:
	return params.get("steer_gain", GameConfig.STEER_ERROR_GAIN)


func turn_drag() -> float:
	return params.get("turn_drag", GameConfig.STEER_SPEED_RADIUS_FACTOR)


func speed_fraction() -> float:
	return absf(speed) / maxf(max_speed(), 0.001)


func forward() -> Vector3:
	return Vector3(sin(yaw), 0.0, -cos(yaw))


func right() -> Vector3:
	return Vector3(cos(yaw), 0.0, sin(yaw))


## Stopped but still THERE (G14.16). Stepping off the machine must leave it
## standing in the yard to walk back to — set_active(false) also hides it,
## because that is what switching machines wants, and reusing it here made the
## tractor vanish the moment the player got down from it.
func set_parked(value: bool) -> void:
	is_active = not value
	is_parked = value
	# Physics processing stays ON. The input pipeline lives in there — the pad,
	# the keyboard and the camera-relative stick — and the WALKER reads that
	# same stick. Switching it off parked the machine and took the player's
	# controls away with it (G14.17).
	if value:
		speed = 0.0
		omega = 0.0
		throttle = 0.0
		desired_omega = 0.0
		_pad_index = -1
		_pad_stick = Vector2.ZERO
		if _clippings:
			_clippings.emitting = false


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
		_pad_index = -1
		_pad_stick = Vector2.ZERO
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
	# Do NOT sweep from where the previous mower stood.
	_mow_valid = false
	_apply_yaw()


func reset_to_start() -> void:
	yaw = 0.0
	speed = 0.0
	omega = 0.0
	throttle = 0.0
	desired_omega = 0.0
	position = Vector3(GameConfig.mower_start().x, 0.0, GameConfig.mower_start().y)
	_apply_yaw()
	_on_reset()


func _on_reset() -> void:
	pass


# ---------------------------------------------------------------- core loop (§7)

func _physics_process(delta: float) -> void:
	# Input first, always: parked or not, this is the one place the pad and the
	# keyboard are read, and the walker borrows the result.
	_read_keyboard()
	_gather_input(delta)
	if is_parked:
		return
	_update_speed(delta)
	_update_steering(delta)

	position += forward() * speed * delta
	_resolve_walls()
	_resolve_obstacles()
	_apply_yaw()

	_mow(delta)
	_idle_shake(delta)


## WASD / arrow keys, for the desktop build (G14).
##
## The keys feed the SAME `_pad_stick` the touch pad fills, so camera-relative
## steering, the reverse-instead-of-pirouette rule and every per-mower turn
## limit apply unchanged. A desktop input path that drove `throttle` directly
## would have had to re-implement all of it, and would have drifted from the
## phone build the first time either was tuned.
func _read_keyboard() -> void:
	if not keyboard_enabled():
		return
	var keys := Input.get_vector("move_left", "move_right",
		"move_back", "move_forward")
	_keyboard_active = keys.length_squared() > 0.0
	if _keyboard_active:
		# A finger already on the pad wins: never fight the player's thumb.
		if _pad_index < 0:
			_pad_stick = keys
	elif _pad_index < 0 and _keyboard_was_active:
		# Let go of the keys and the mower coasts, exactly as lifting a finger.
		_pad_stick = Vector2.ZERO
	_keyboard_was_active = _keyboard_active


## True while WASD is being held. Subclasses use it the way they use a finger.
func keyboard_active() -> bool:
	return _keyboard_active


## The robot drives itself; a subclass can refuse the keyboard entirely.
func keyboard_enabled() -> bool:
	return true


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
	yaw += omega * (1.0 - turn_drag() * speed_fraction()) * delta


## Distance from `point` to the segment a->b; falls back to the point distance
## when the mower did not move this tick.
static func _segment_distance(point: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var len_sq := ab.length_squared()
	if len_sq < 0.000001:
		return point.distance_to(a)
	var t := clampf((point - a).dot(ab) / len_sq, 0.0, 1.0)
	return point.distance_to(a + ab * t)


static func shortest_angle(from_angle: float, to_angle: float) -> float:
	return wrapf(to_angle - from_angle, -PI, PI)


## Turn towards a world-space heading using the §7 error gain.
func steer_towards(target_yaw: float) -> void:
	desired_omega = clampf(shortest_angle(yaw, target_yaw) * steer_gain(),
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
	# Sweep the deck along the segment travelled since the last tick. A point
	# sample leaves gaps: cells are 1.0 wide, so a deck under 0.708 (half the
	# cell diagonal) can sit on a cell corner and reach no centre at all, and a
	# fast mower can step clean past a centre between two frames.
	var from := _mow_from if _mow_valid else center
	_mow_from = center
	_mow_valid = true
	var box_lo := Vector3(minf(from.x, center.x), 0.0, minf(from.y, center.y))
	var box_hi := Vector3(maxf(from.x, center.x), 0.0, maxf(from.y, center.y))
	var origin := LawnModel.cell_at(box_lo - Vector3(radius, 0.0, radius))
	var limit := LawnModel.cell_at(box_hi + Vector3(radius, 0.0, radius))

	var mown := 0
	var revealed: Array[Vector2i] = []
	var clip_tint := GameConfig.clipping_color()
	for row in range(origin.y, limit.y + 1):
		for col in range(origin.x, limit.x + 1):
			if not LawnModel.in_bounds(col, row):
				continue
			var cc := LawnModel.cell_center(col, row)
			if _segment_distance(Vector2(cc.x, cc.z), from, center) > radius:
				continue
			# Clippings inherit the clump's colour (read before it is cut).
			if mown == 0 and tuft_field:
				clip_tint = tuft_field.clump_tint(col, row)
			var result := model.mow(col, row, stripe)
			if result == LawnModel.MowResult.NONE:
				continue
			mown += 1
			if scrap_field:
				var scrap := scrap_field.take(col, row)
				if scrap > 0:
					scrap_found.emit(col, row, scrap)
				var food := scrap_field.take_food(col, row)
				if food > 0:
					food_found.emit(col, row, food)
			if tuft_field:
				tuft_field.cut_cell(col, row, rotation.y)
			if result == LawnModel.MowResult.SECRET_REVEALED:
				revealed.append(Vector2i(col, row))

	if mown > 0 and _clippings:
		var pm := _clippings.process_material as ParticleProcessMaterial
		if pm:
			# After dark what comes up out of the blades is not grass-coloured:
			# pale, bigger and slower, it reads as moths going up (G14.6). Same
			# particle system, second profile, no extra draw.
			var night := GameConfig.NIGHT_CLIP_HOURS.has(_hour())
			pm.color = GameConfig.NIGHT_CLIP_COLOUR if night else clip_tint
			pm.scale_max = GameConfig.NIGHT_CLIP_SCALE if night else 1.0
			pm.gravity = Vector3(0.0,
				GameConfig.CLIP_GRAVITY * (0.35 if night else 1.0), 0.0)
	_update_clippings(delta, mown)

	if mown > 0:
		Haptics.light()
		AudioDirector.play_cut()
		cells_mown.emit(mown)
	for cell in revealed:
		secret_uncovered.emit(cell.x, cell.y)


## The hour the level is actually being lit by, switch included.
func _hour() -> String:
	return SkyTime.resolve(LevelVariant.current.time_of_day \
		if LevelVariant.current != null else GameConfig.TIME_OF_DAY_DEFAULT)


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

## Game forwards raw touches; each type consumes what it needs. The default is
## the shared drag pad (G6.12): press ANYWHERE on screen, and the drag offset
## from that point becomes a virtual stick — up is forward, down is reverse,
## sideways steers. Every mower type uses it, so the control never changes when
## you switch vehicles.
func on_touch_pressed(index: int, screen_pos: Vector2) -> void:
	pad_press(index, screen_pos)


func on_touch_dragged(index: int, screen_pos: Vector2) -> void:
	pad_drag(index, screen_pos)


func on_touch_released(index: int, _screen_pos: Vector2) -> void:
	pad_release(index)


## True while a finger is down on the pad.
## True when the player is steering: a finger on the pad, OR held keys on the
## desktop build. Every mower gates its driving on this, so counting the
## keyboard here is what makes WASD work for all of them at once (G14).
func pad_engaged() -> bool:
	return _pad_index != -1 or _keyboard_active


## The virtual stick: x = right, y = forward, each -1..1. Zero inside the
## §7 drag threshold so a plain tap does not twitch the mower.
func pad_stick() -> Vector2:
	return _pad_stick


## Camera yaw as it was when this gesture started. See _pad_camera_yaw.
func pad_camera_yaw() -> float:
	return _pad_camera_yaw


func pad_press(index: int, screen_pos: Vector2) -> bool:
	if _pad_index != -1:
		return false
	_pad_index = index
	_pad_origin = screen_pos
	_pad_stick = Vector2.ZERO
	_pad_now = screen_pos
	_pad_camera_yaw = camera_yaw
	return true


func pad_drag(index: int, screen_pos: Vector2) -> bool:
	if index != _pad_index:
		return false
	_pad_now = screen_pos
	var drag := screen_pos - _pad_origin
	var dead := GameConfig.DRAG_THRESHOLD_PT * GameConfig.POINT_SCALE
	if drag.length() <= dead:
		_pad_stick = Vector2.ZERO
		return true
	var full := GameConfig.DRAG_FULL_PT * GameConfig.POINT_SCALE
	# Measure past the dead zone so the stick starts at zero, not at a jump.
	var mag := minf((drag.length() - dead) / maxf(full - dead, 1.0), 1.0)
	var dir := drag.normalized()
	# Screen y grows downward, so up (-y) is forward.
	_pad_stick = Vector2(dir.x, -dir.y) * mag
	return true


func pad_release(index: int) -> bool:
	if index != _pad_index:
		return false
	_pad_index = -1
	_pad_stick = Vector2.ZERO
	return true


## Shared pad -> throttle/steering, using the same §7 rules as the tractor
## joystick (reverse runs at `reverse` speed and flips the steering sign).
## Shared pad -> movement, reworked in G9.2 as HEADING steering: the mower turns
## toward the direction the finger points, instead of the finger's x-axis being
## a steering wheel. Rate steering read as "inconsistent" because the same drag
## produced a different arc depending on the current heading; with heading
## steering the finger direction IS the destination, which is what every
## top-down mobile driver trains players to expect.
func drive_from_pad() -> void:
	var stick := _pad_stick
	if stick == Vector2.ZERO:
		throttle = 0.0
		desired_omega = 0.0
		return
	var target := camera_yaw + atan2(stick.x, stick.y)
	var error := shortest_angle(yaw, target)
	var mag := minf(stick.length(), 1.0)
	if absf(error) > GameConfig.PAD_REVERSE_ANGLE and reverse_factor() > 0.0:
		# The target is behind: back up rather than pirouetting on the spot.
		throttle = -mag
		desired_omega = clampf(-error * steer_gain() * 0.4,
			-max_turn(), max_turn())
		return
	steer_towards(target)
	# Throttle follows alignment, so the mower carves toward the finger instead
	# of driving full speed at the wrong heading while it turns.
	throttle = mag * clampf(cos(error) + GameConfig.PAD_TURN_THROTTLE_FLOOR,
		GameConfig.PAD_TURN_THROTTLE_FLOOR, 1.0)


## True for mowers whose camera must NOT rotate with them (the blade): a
## yaw-free mower spinning the camera makes screen directions drift mid-drag.
func camera_yaw_locked() -> bool:
	return false


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
