class_name Game
extends Node3D
## Sprint G1 wiring: model -> view -> mower -> camera -> HUD.
##
## Touch input arrives through _unhandled_input, so anything the HUD swallows
## never reaches the mower (§16 "UI dokunuşları 3D sahneye geçmemeli").

@onready var lawn: LawnView = $Lawn
@onready var mower: Mower = $Mower
@onready var cam: CameraRig = $Camera3D
@onready var hud: Hud = $UI/HUD

var model: LawnModel


func _ready() -> void:
	model = LawnModel.new()
	lawn.setup(model)

	mower.model = model
	mower.tuft_field = lawn.tuft_field
	mower.reset_to_start()

	cam.target = mower
	cam.snap_to_target()

	model.completed.connect(_on_completed)
	mower.cells_mown.connect(_on_cells_mown)
	hud.restart_pressed.connect(_restart)

	hud.set_progress(0.0)
	GameState.start_run()
	AudioDirector.start_ambient()


func _process(_delta: float) -> void:
	# Steering is camera-relative, so the mower needs the camera's yaw.
	mower.camera_yaw = cam.yaw
	var turn := clampf(absf(mower.omega) / GameConfig.PUSH_MAX_TURN, 0.0, 1.0)
	AudioDirector.set_engine_state(mower.speed_fraction(), turn)


func _unhandled_input(event: InputEvent) -> void:
	var touch := event as InputEventScreenTouch
	if touch != null:
		if touch.pressed:
			mower.touch_pressed(touch.index, touch.position)
		else:
			mower.touch_released(touch.index)
		return
	var drag := event as InputEventScreenDrag
	if drag != null:
		mower.touch_dragged(drag.index, drag.position)


func _on_cells_mown(_count: int) -> void:
	hud.set_progress(model.completion_ratio())


func _on_completed() -> void:
	GameState.finish_run()
	cam.set_bird_view(true)
	hud.show_complete(model.mowed_count, GameState.format_elapsed())


## Restart: model reset (secrets redistributed), tint map cleared, tufts back up.
func _restart() -> void:
	model.reset()
	lawn.on_model_reset()
	mower.reset_to_start()
	cam.set_bird_view(false)
	cam.snap_to_target()
	hud.hide_complete()
	hud.set_progress(0.0)
	GameState.start_run()
