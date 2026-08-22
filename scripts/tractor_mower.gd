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


func _gather_input(_delta: float) -> void:
	if joystick == null:
		throttle = 0.0
		desired_omega = 0.0
		return
	# x = right, y = up (forward). MowerMath.tractor_input holds the §7 rules.
	var mapped := MowerMath.tractor_input(
		joystick.get_value(), max_turn(), reverse_factor(), speed)
	throttle = mapped.x
	desired_omega = mapped.y
