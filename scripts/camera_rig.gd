class_name CameraRig
extends Camera3D
## Chase camera — REFERENCE.md §10. Mid zoom preset is the active one.
##
## Uses the spec yaw convention: forward(yaw) = (sin(yaw), 0, -cos(yaw)).

@export var back: float = GameConfig.CAMERA_BACK
@export var height: float = GameConfig.CAMERA_HEIGHT
@export var look_ahead: float = GameConfig.CAMERA_LOOK_AHEAD

var target: Mower
## Camera yaw in spec space — the mower reads this so drag steering stays
## camera-relative (§18 trap 2).
var yaw: float = 0.0

var _focus := Vector3.ZERO
var _bird_view := false


func _ready() -> void:
	fov = GameConfig.CAMERA_FOV
	if target:
		snap_to_target()


func snap_to_target() -> void:
	if target == null:
		return
	_focus = target.position
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
	yaw += wrapf(target.yaw - yaw, -PI, PI) * (1.0 - exp(-GameConfig.CAMERA_YAW_LERP * delta))
	_place()


func _place() -> void:
	var fwd := Vector3(sin(yaw), 0.0, -cos(yaw))
	position = _focus - fwd * back + Vector3(0.0, height, 0.0)
	_look(_focus + fwd * look_ahead + Vector3(0.0, GameConfig.CAMERA_LOOK_UP, 0.0))


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
