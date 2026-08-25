class_name CameraRig
extends Camera3D
## Chase camera — REFERENCE.md §10. Mid zoom preset is the active one.
##
## Uses the spec yaw convention: forward(yaw) = (sin(yaw), 0, -cos(yaw)).

@export var back: float = GameConfig.CAMERA_BACK
@export var height: float = GameConfig.CAMERA_HEIGHT
@export var look_ahead: float = GameConfig.CAMERA_LOOK_AHEAD
## Extra lookAhead per unit of speed fraction — the tractor is fast enough that
## the road needs to show (§ sprint G3 item 5).
var look_ahead_speed_gain: float = 0.0

var target: MowerController
## Camera yaw in spec space — the mower reads this so drag steering stays
## camera-relative (§18 trap 2).
var yaw: float = 0.0

var _focus := Vector3.ZERO
var _bird_view := false
## Held still while a gesture is in progress; see BladeMower.camera_yaw_locked.
var freeze_yaw := false
var _glance_point := Vector3.ZERO
var _glance_weight := 0.0


func _ready() -> void:
	fov = GameConfig.CAMERA_FOV
	if target:
		snap_to_target()


func snap_to_target() -> void:
	if target == null:
		return
	_focus = target.position
	if not target.camera_yaw_locked():
		yaw = target.yaw
	_place()


func set_bird_view(enabled: bool) -> void:
	_bird_view = enabled


func _process(delta: float) -> void:
	if _bird_view:
		var t := 1.0 - exp(-GameConfig.CAMERA_WIN_LERP * delta)
		position = position.lerp(GameConfig.CAMERA_WIN_POS, t)
		_look(Vector3.ZERO)
		return

	if target == null:
		return
	# Focus follows at 4.0/s, camera yaw lags the mower at 2.6/s.
	_focus = _focus.lerp(target.position, 1.0 - exp(-GameConfig.CAMERA_FOCUS_LERP * delta))
	if _glance_weight > 0.0:
		_focus = _focus.lerp(_glance_point, _glance_weight * 0.65)
	if not target.camera_yaw_locked() and not freeze_yaw:
		yaw += wrapf(target.yaw - yaw, -PI, PI) * (1.0 - exp(-GameConfig.CAMERA_YAW_LERP * delta))
	_place()


## G12.6: a brief look at a point, then back to the mower. The rig keeps
## following its target throughout — this only biases the focus, so the player
## never loses control of the machine.
func glance_at(at: Vector3, duration: float) -> void:
	var tw := create_tween()
	tw.tween_method(func(weight: float) -> void: _glance_weight = weight,
		0.0, 1.0, duration * 0.4).set_trans(Tween.TRANS_SINE)
	tw.tween_interval(duration * 0.2)
	tw.tween_method(func(weight: float) -> void: _glance_weight = weight,
		1.0, 0.0, duration * 0.4).set_trans(Tween.TRANS_SINE)
	_glance_point = at


## G7 opening: glide down from high above onto the mower's own preset while the
## case title holds on screen. Purely cosmetic — the rig keeps following the
## target throughout, so gameplay is unaffected if the player taps early.
func descend_to(preset: Vector3, duration: float, from_height := 26.0,
		from_back := 3.0) -> void:
	back = from_back
	height = from_height
	look_ahead = preset.z
	var tw := create_tween()
	tw.tween_property(self, "back", preset.x, duration) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.parallel().tween_property(self, "height", preset.y, duration) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


## Applies one of the §10 zoom presets (back, height, lookAhead) per mower type.
func set_preset(preset: Vector3, speed_gain := 0.0) -> void:
	back = preset.x
	height = preset.y
	look_ahead = preset.z
	look_ahead_speed_gain = speed_gain


func _place() -> void:
	var fwd := Vector3(sin(yaw), 0.0, -cos(yaw))
	var ahead := look_ahead
	if target and look_ahead_speed_gain != 0.0:
		ahead += look_ahead_speed_gain * target.speed_fraction()
	position = _focus - fwd * back + Vector3(0.0, height, 0.0)
	_look(_focus + fwd * ahead + Vector3(0.0, GameConfig.CAMERA_LOOK_UP, 0.0))


func _look(at: Vector3) -> void:
	var dir := at - position
	if dir.length_squared() < 0.0001:
		return
	# A near-vertical view makes up parallel to the look direction and look_at
	# degenerates (the bird's-eye reward shot rolled over). North is up there.
	# The chase camera's dot is about 0.64, so this never fires during play.
	var up := Vector3.UP
	if absf(dir.normalized().dot(Vector3.UP)) > 0.9:
		up = Vector3(0.0, 0.0, -1.0)
	look_at(at, up)
