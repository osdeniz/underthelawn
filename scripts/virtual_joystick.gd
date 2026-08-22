class_name TouchJoystick
extends Control
## Dynamic virtual joystick. Touching anywhere inside this Control drops the
## joystick base under the finger; dragging returns a normalised Vector2 where
## +Y means "down the screen". Multi-touch safe, and falls back to arrow keys /
## gamepad (ui_* actions) so the prototype is testable on desktop.

@export var base_radius: float = 108.0
@export var knob_radius: float = 46.0
@export var deadzone: float = 0.16
## Where the joystick idles when untouched, as a fraction of this Control's size.
@export var rest_anchor := Vector2(0.30, 0.66)

var _touch_index: int = -1
var _base_pos := Vector2.ZERO
var _knob_pos := Vector2.ZERO
var _active := false
var _fade: float = 0.0
var _value := Vector2.ZERO


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_reset_positions()
	resized.connect(_reset_positions)


func _reset_positions() -> void:
	_base_pos = size * rest_anchor
	_knob_pos = _base_pos
	queue_redraw()


## Normalised stick vector: x = right, y = down (screen space).
func get_value() -> Vector2:
	var keys := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var v := _value + keys
	if v.length() > 1.0:
		v = v.normalized()
	if v.length() < deadzone:
		return Vector2.ZERO
	return v


func is_active() -> bool:
	return _active


func _gui_input(event: InputEvent) -> void:
	var touch := event as InputEventScreenTouch
	if touch != null:
		if touch.pressed:
			if _touch_index == -1:
				_touch_index = touch.index
				_active = true
				_base_pos = touch.position
				_knob_pos = touch.position
				accept_event()
		elif touch.index == _touch_index:
			_release()
			accept_event()
		queue_redraw()
		return

	var drag := event as InputEventScreenDrag
	if drag != null and drag.index == _touch_index:
		_knob_pos = drag.position
		accept_event()
		queue_redraw()


func _release() -> void:
	_touch_index = -1
	_active = false
	_value = Vector2.ZERO
	_reset_positions()


func _process(delta: float) -> void:
	if _active:
		var offset := _knob_pos - _base_pos
		if offset.length() > base_radius:
			offset = offset.normalized() * base_radius
			_knob_pos = _base_pos + offset
		_value = offset / base_radius
		_fade = minf(_fade + delta * 8.0, 1.0)
	else:
		_fade = maxf(_fade - delta * 5.0, 0.0)
	queue_redraw()


func _draw() -> void:
	var alpha := 0.28 + 0.42 * _fade
	var ring := Color(1.0, 1.0, 1.0, alpha * 0.55)
	var fill := Color(0.05, 0.12, 0.05, alpha * 0.35)
	draw_circle(_base_pos, base_radius, fill)
	draw_arc(_base_pos, base_radius, 0.0, TAU, 48, ring, 4.0, true)
	draw_arc(_base_pos, base_radius * 0.55, 0.0, TAU, 32,
		Color(1.0, 1.0, 1.0, alpha * 0.18), 2.0, true)

	var knob_col := Color(0.72, 0.92, 0.40, 0.45 + 0.45 * _fade)
	draw_circle(_knob_pos, knob_radius, knob_col)
	draw_arc(_knob_pos, knob_radius, 0.0, TAU, 32,
		Color(1.0, 1.0, 1.0, 0.5 + 0.4 * _fade), 3.0, true)
