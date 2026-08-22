extends Node
## Haptics autoload.
##
## Godot exposes a single primitive, Input.vibrate_handheld(duration_ms), so the
## light / medium / success distinction is imitated with duration, exactly as the
## sprint brief instructs. Hard rule from the brief: at most ONE vibration per
## frame, no matter how many callers ask.
##
## Values from the brief: light = 10 ms, medium = 25 ms, success = two short
## pulses. The gap between the two success pulses is the only number not given;
## SUCCESS_GAP_S below is a placeholder and should be corrected from §15.

const LIGHT_MS := 10
const MEDIUM_MS := 25
const SUCCESS_PULSE_MS := 10
const SUCCESS_GAP_S := 0.08  # TODO §15: not specified in the brief

## Turned off by the mute preference and unavailable on desktop anyway.
var enabled := true

var _claimed_frame: int = -1


func light() -> void:
	if _claim_frame():
		Input.vibrate_handheld(LIGHT_MS)


func medium() -> void:
	if _claim_frame():
		Input.vibrate_handheld(MEDIUM_MS)


## Two short pulses. Awaits internally; callers do not need to await it.
func success() -> void:
	if not _claim_frame():
		return
	Input.vibrate_handheld(SUCCESS_PULSE_MS)
	await get_tree().create_timer(SUCCESS_GAP_S).timeout
	Input.vibrate_handheld(SUCCESS_PULSE_MS)


func _claim_frame() -> bool:
	if not enabled:
		return false
	var frame := Engine.get_process_frames()
	if frame == _claimed_frame:
		return false
	_claimed_frame = frame
	return true
