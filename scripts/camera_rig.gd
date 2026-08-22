class_name CameraRig
extends Node3D
## Smoothed top-down chase camera with a little shake for cutting feedback.

@export var target: Node3D
@export var height: float = 13.5
@export var back_offset: float = 8.0
@export var smoothing: float = 6.0
@export var max_shake: float = 0.22

var _shake: float = 0.0
var _cam: Camera3D
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_cam = get_node_or_null("Camera3D") as Camera3D
	_rng.randomize()
	if target:
		global_position = target.global_position + Vector3(0.0, height, back_offset)


func _process(delta: float) -> void:
	if target:
		var desired := target.global_position + Vector3(0.0, height, back_offset)
		var t := 1.0 - exp(-smoothing * delta)
		global_position = global_position.lerp(desired, t)

	_shake = maxf(_shake - delta * 0.9, 0.0)
	if _cam:
		if _shake > 0.0:
			_cam.position = Vector3(
				_rng.randf_range(-1.0, 1.0) * _shake,
				_rng.randf_range(-1.0, 1.0) * _shake,
				0.0)
		elif _cam.position != Vector3.ZERO:
			_cam.position = Vector3.ZERO


## Jump straight to the follow position (used after the target is assigned).
func snap_to_target() -> void:
	if target:
		global_position = target.global_position + Vector3(0.0, height, back_offset)


func add_shake(amount: float) -> void:
	_shake = minf(_shake + amount, max_shake)
