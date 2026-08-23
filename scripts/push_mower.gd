class_name PushMower
extends MowerController
## Push mower input — REFERENCE.md §7 "Push", reworked in G6.12.
##
## Uses the shared drag pad from MowerController: press anywhere, then drag —
## up drives forward, down reverses, sideways steers. All movement maths lives
## in MowerController.


func type_index() -> int:
	return GameConfig.MOWER_PUSH


func _gather_input(_delta: float) -> void:
	if not pad_engaged():
		throttle = 0.0
		desired_omega = 0.0
		return
	drive_from_pad()
