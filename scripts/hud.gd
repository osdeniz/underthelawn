class_name Hud
extends Control
## Minimal Sprint G1 HUD (§16): mown percentage + green progress capsule, mute
## button, and the LAWN COMPLETE panel with cell count, time and restart.
##
## UI must swallow its own touches so the 3D scene never sees them: this root is
## MOUSE_FILTER_IGNORE and only the buttons stop events.

signal restart_pressed()

@onready var _percent_label: Label = %PercentLabel
@onready var _progress: ProgressBar = %Progress
@onready var _mute_button: Button = %MuteButton
@onready var _complete_panel: Control = %CompletePanel
@onready var _complete_stats: Label = %CompleteStats

var _shown_percent := 0.0
var _target_percent := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_complete_panel.visible = false
	_mute_button.pressed.connect(_on_mute_pressed)
	(%RestartButton as Button).pressed.connect(func(): restart_pressed.emit())
	_refresh_mute_label()
	set_progress(0.0)


func set_progress(ratio: float) -> void:
	_target_percent = clampf(ratio, 0.0, 1.0) * 100.0


func _process(delta: float) -> void:
	# Animated number, as in the SwiftUI original.
	if absf(_target_percent - _shown_percent) > 0.01:
		_shown_percent = lerpf(_shown_percent, _target_percent,
			clampf(delta * 9.0, 0.0, 1.0))
		_apply_percent()


func _apply_percent() -> void:
	_percent_label.text = "%%%d biçildi" % int(round(_shown_percent))
	_progress.value = _shown_percent


func show_complete(cells: int, elapsed: String) -> void:
	_shown_percent = 100.0
	_apply_percent()
	_complete_stats.text = "%d hücre biçildi · süre: %s" % [cells, elapsed]
	_complete_panel.visible = true


func hide_complete() -> void:
	_complete_panel.visible = false
	_shown_percent = 0.0
	_target_percent = 0.0
	_apply_percent()


func _on_mute_pressed() -> void:
	AudioDirector.toggle_mute()
	_refresh_mute_label()


func _refresh_mute_label() -> void:
	_mute_button.text = "🔇" if AudioDirector.muted else "🔊"
