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
	# The HUD joystick keeps its §7 wheel mapping; a drag anywhere else drives
	# the shared heading steering, same as the other three mowers (G9.2).
	var stick := joystick.get_value() if joystick != null else Vector2.ZERO
	if stick != Vector2.ZERO:
		var mapped := MowerMath.tractor_input(
			stick, max_turn(), reverse_factor(), speed)
		throttle = mapped.x
		desired_omega = mapped.y
		return
	if pad_engaged():
		drive_from_pad()
		return
	throttle = 0.0
	desired_omega = 0.0
