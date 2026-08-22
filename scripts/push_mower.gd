class_name PushMower
extends MowerController
## Push mower input — REFERENCE.md §7 "Push".
##
## Finger down means throttle 1. Dragging past the 8 pt threshold sets a
## camera-relative target heading; lifting the finger coasts to a stop over
## 0.55 s. All movement maths lives in MowerController.

var _touch_index := -1
var _touch_origin := Vector2.ZERO
var _target_yaw := 0.0
var _has_target := false


func type_index() -> int:
	return GameConfig.MOWER_PUSH


func _on_active_changed(value: bool) -> void:
	if not value:
		_touch_index = -1
		_has_target = false


func on_touch_pressed(index: int, screen_pos: Vector2) -> void:
	if _touch_index != -1:
		return
	_touch_index = index
	_touch_origin = screen_pos
	_has_target = false
	throttle = 1.0


func on_touch_dragged(index: int, screen_pos: Vector2) -> void:
	if index != _touch_index:
		return
	var drag := screen_pos - _touch_origin
	if drag.length() < GameConfig.DRAG_THRESHOLD_PT * GameConfig.POINT_SCALE:
		return
	# Screen up (-y) means away from the player, hence camera-relative.
	_target_yaw = camera_yaw + atan2(drag.x, -drag.y)
	_has_target = true


func on_touch_released(index: int, _screen_pos: Vector2) -> void:
	if index != _touch_index:
		return
	_touch_index = -1
	throttle = 0.0


func _gather_input(_delta: float) -> void:
	if _has_target and throttle > 0.0:
		steer_towards(_target_yaw)
	else:
		desired_omega = 0.0
