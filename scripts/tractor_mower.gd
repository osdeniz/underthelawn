class_name TractorMower
extends MowerController
## Tractor input — REFERENCE.md §7 "Traktör".
##
## Joystick Y is the throttle (reverse runs at 0.5x, §6); joystick X is the
## steering, and its sign flips in reverse the way a real vehicle behaves.
## The joystick Control lives in the HUD and swallows its own touches.

var joystick: TractorJoystick


func type_index() -> int:
	return GameConfig.MOWER_TRACTOR


## Pure mapping of §7's tractor rules, kept static so it can be unit tested.
## Returns (throttle, desiredOmega). Reverse runs at `reverse` speed and flips
## the steering sign, the way backing up a real vehicle behaves.
static func map_input(stick: Vector2, turn_limit: float, reverse: float,
		current_speed: float) -> Vector2:
	var throttle_out := stick.y if stick.y >= 0.0 else stick.y * reverse
	var steer_sign := -1.0 if current_speed < -0.01 else 1.0
	return Vector2(throttle_out, stick.x * turn_limit * steer_sign)


func _gather_input(_delta: float) -> void:
	if joystick == null:
		throttle = 0.0
		desired_omega = 0.0
		return
	# x = right, y = up (forward)
	var mapped := map_input(joystick.get_value(), max_turn(), reverse_factor(), speed)
	throttle = mapped.x
	desired_omega = mapped.y
