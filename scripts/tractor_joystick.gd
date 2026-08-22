class_name TractorJoystick
extends Control
## Virtual joystick for the tractor — REFERENCE.md §7 "Traktör".
##
## Base r55 pt, knob r24 pt, deadzone 0.25, spring return on release. Only
## visible while the tractor is selected. This Control STOPS input, so its
## touches never reach the lawn; everything outside its rect passes through.

var _base_radius := 0.0
var _knob_radius := 0.0
var _center := Vector2.ZERO
var _knob := Vector2.ZERO      # offset from centre, in pixels
var _touch_index := -1
var _return_tween: Tween


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_base_radius = GameConfig.JOYSTICK_BASE_RADIUS_PT * GameConfig.POINT_SCALE
	_knob_radius = GameConfig.JOYSTICK_KNOB_RADIUS_PT * GameConfig.POINT_SCALE
	custom_minimum_size = Vector2.ONE * (_base_radius + _knob_radius) * 2.0
	size = custom_minimum_size
	_center = size * 0.5
	resized.connect(func() -> void: _center = size * 0.5)


## x = right, y = up (forward). Zero inside the deadzone (§7).
func get_value() -> Vector2:
	var v := _knob / _base_radius
	if v.length() < GameConfig.JOYSTICK_DEADZONE:
		return Vector2.ZERO
	# Screen y grows downwards; the tractor wants forward positive.
	return Vector2(v.x, -v.y)


func _gui_input(event: InputEvent) -> void:
	var touch := event as InputEventScreenTouch
	if touch != null:
		if touch.pressed and _touch_index == -1:
			_touch_index = touch.index
			_kill_return()
			_set_knob(touch.position - _center)
			accept_event()
		elif not touch.pressed and touch.index == _touch_index:
			_release()
			accept_event()
		return
	var drag := event as InputEventScreenDrag
	if drag != null and drag.index == _touch_index:
		_set_knob(drag.position - _center)
		accept_event()


func _set_knob(offset: Vector2) -> void:
	if offset.length() > _base_radius:
		offset = offset.normalized() * _base_radius
	_knob = offset
	queue_redraw()


func _release() -> void:
	_touch_index = -1
	_kill_return()
	# Spring back to centre.
	_return_tween = create_tween()
	_return_tween.tween_method(func(value: Vector2) -> void:
		_knob = value
		queue_redraw(), _knob, Vector2.ZERO, GameConfig.JOYSTICK_RETURN_TIME) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _kill_return() -> void:
	if _return_tween and _return_tween.is_valid():
		_return_tween.kill()


func _draw() -> void:
	var active := _touch_index != -1
	draw_circle(_center, _base_radius, Color(0.05, 0.12, 0.05, 0.30))
	draw_arc(_center, _base_radius, 0.0, TAU, 56,
		Color(1.0, 1.0, 1.0, 0.34 if active else 0.22), 5.0, true)
	draw_arc(_center, _base_radius * GameConfig.JOYSTICK_DEADZONE, 0.0, TAU, 24,
		Color(1.0, 1.0, 1.0, 0.14), 3.0, true)
	var knob_pos := _center + _knob
	draw_circle(knob_pos, _knob_radius, Color(0.95, 0.78, 0.15, 0.55 if active else 0.42))
	draw_arc(knob_pos, _knob_radius, 0.0, TAU, 32,
		Color(1.0, 1.0, 1.0, 0.75 if active else 0.5), 4.0, true)
