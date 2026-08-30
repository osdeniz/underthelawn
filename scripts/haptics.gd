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

const LIGHT_MS := GameConfig.HAPTIC_LIGHT_MS
const MEDIUM_MS := GameConfig.HAPTIC_MEDIUM_MS
const SUCCESS_PULSE_MS := GameConfig.HAPTIC_MEDIUM_MS
const SUCCESS_GAP_S := GameConfig.HAPTIC_SUCCESS_GAP

## Master switch (GameConfig.HAPTIC_ENABLED). Also a no-op on desktop.
var enabled := GameConfig.HAPTIC_ENABLED

var _claimed_frame: int = -1


func _ready() -> void:
	# The player's own choice from Settings, if they made one — the default
	# above otherwise. GameState loads first (project.godot autoload order), so
	# its saved value is already on disk by the time this runs.
	enabled = bool(GameState.get_setting("meta", "haptics_enabled", enabled))


func light() -> void:
	if _claim_frame():
		Input.vibrate_handheld(LIGHT_MS)


func medium() -> void:
	if _claim_frame():
		Input.vibrate_handheld(MEDIUM_MS)


## Two medium pulses 80 ms apart: secret collected, and 100% complete (§15).
## Awaits internally; callers do not need to await it.
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
