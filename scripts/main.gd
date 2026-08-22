class_name Game
extends Node3D
## Wires the prototype together: joystick -> mower -> lawn -> HUD -> secrets.

@onready var lawn: LawnManager = $Lawn
@onready var mower: Mower = $Mower
@onready var rig: CameraRig = $CameraRig
@onready var joystick: TouchJoystick = $UI/Joystick
@onready var hud: Hud = $UI/HUD

var _hint_dismissed := false


func _ready() -> void:
	mower.lawn = lawn
	mower.joystick = joystick
	mower.camera_rig = rig

	rig.target = mower
	rig.snap_to_target()

	lawn.completion_changed.connect(_on_completion_changed)
	lawn.lawn_completed.connect(hud.show_complete)

	for child in $Secrets.get_children():
		if child is SecretObject:
			(child as SecretObject).discovered.connect(_on_secret_discovered)

	hud.set_completion(0.0, 0, lawn.total_tiles)


func _process(_delta: float) -> void:
	if not _hint_dismissed and joystick.get_value().length() > 0.0:
		_hint_dismissed = true
		hud.hide_hint()


func _on_completion_changed(percent: float, cut_tiles: int, total_tiles: int) -> void:
	hud.set_completion(percent, cut_tiles, total_tiles)


func _on_secret_discovered(display_name: String) -> void:
	hud.show_secret(display_name)
	if rig:
		rig.add_shake(0.18)
