class_name Mower
extends CharacterBody3D
## Arcade lawn mower. The joystick vector is treated as a world-space heading
## (the camera is top-down, so screen up = away from the player); the mower
## turns toward it and drives forward. Cutting is an oriented rectangle in front
## of the chassis handed to the LawnManager every physics tick.

@export_group("Driving")
@export var max_speed: float = 5.6
@export var acceleration: float = 11.0
@export var braking: float = 16.0
@export var turn_speed: float = 5.5
## Speed is scaled down while turning hard, so corners feel weighty.
@export var turn_drag: float = 0.45

@export_group("Cutting")
@export var cut_width: float = 2.0
@export var cut_length: float = 1.0
@export var deck_forward_offset: float = 0.75

@export_group("References")
@export var lawn: LawnManager
@export var joystick: TouchJoystick
@export var camera_rig: CameraRig

var speed: float = 0.0
var cut_rate: float = 0.0            ## Smoothed tiles-per-second being cut.

var _emit_hold: float = 0.0
var _bob_time: float = 0.0
var _turn_signed: float = 0.0

var _chassis: Node3D
var _grass_fx: GPUParticles3D
var _dust_fx: GPUParticles3D
var _engine: MowerEngine


func _ready() -> void:
	_chassis = get_node_or_null("Chassis") as Node3D
	_grass_fx = get_node_or_null("GrassParticles") as GPUParticles3D
	_dust_fx = get_node_or_null("DustParticles") as GPUParticles3D
	_engine = get_node_or_null("Engine") as MowerEngine
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING


func _physics_process(delta: float) -> void:
	var stick := Vector2.ZERO
	if joystick:
		stick = joystick.get_value()

	# Screen down (+y on the stick) maps to world +z under the top-down camera.
	var desired := Vector3(stick.x, 0.0, stick.y)
	var throttle := clampf(desired.length(), 0.0, 1.0)

	if throttle > 0.05:
		var target_yaw := atan2(-desired.x, -desired.z)
		var delta_yaw := wrapf(target_yaw - rotation.y, -PI, PI)
		_turn_signed = clampf(delta_yaw / PI, -1.0, 1.0)
		rotation.y = lerp_angle(rotation.y, target_yaw, clampf(turn_speed * delta, 0.0, 1.0))
		var target_speed := max_speed * throttle * (1.0 - turn_drag * absf(_turn_signed))
		speed = move_toward(speed, target_speed, acceleration * delta)
	else:
		_turn_signed = lerpf(_turn_signed, 0.0, clampf(delta * 6.0, 0.0, 1.0))
		speed = move_toward(speed, 0.0, braking * delta)

	var forward := -global_transform.basis.z
	velocity = forward * speed
	move_and_slide()
	global_position.y = 0.0

	_do_cutting(delta, forward)
	_update_feel(delta, throttle)


func _do_cutting(delta: float, forward: Vector3) -> void:
	var newly := 0
	if lawn:
		lawn.set_mower_position(global_position)
		var deck := global_position + forward * deck_forward_offset
		newly = lawn.cut_rect(deck, forward, cut_width * 0.5, cut_length * 0.5)

	# Smooth the raw per-tick count into a rate so audio/FX do not flicker.
	var instant := float(newly) / maxf(delta, 0.0001)
	cut_rate = lerpf(cut_rate, instant, clampf(delta * 7.0, 0.0, 1.0))

	if newly > 0:
		_emit_hold = 0.16
		if camera_rig:
			camera_rig.add_shake(0.012 * float(newly))
	else:
		_emit_hold = maxf(_emit_hold - delta, 0.0)

	var cutting := _emit_hold > 0.0
	if _grass_fx:
		_grass_fx.emitting = cutting
		_grass_fx.amount_ratio = clampf(0.35 + cut_rate / 22.0, 0.0, 1.0)
	if _dust_fx:
		_dust_fx.emitting = cutting


func _update_feel(delta: float, throttle: float) -> void:
	var speed_ratio := clampf(speed / maxf(max_speed, 0.001), 0.0, 1.0)
	var w := clampf(delta * 5.0, 0.0, 1.0)

	if _engine:
		_engine.throttle = clampf(0.12 + speed_ratio * 0.88 + throttle * 0.1, 0.0, 1.0)
		_engine.cut_load = clampf(cut_rate / 18.0, 0.0, 1.0)

	if _chassis:
		# Engine idle shudder, stronger under load.
		_bob_time += delta * (7.0 + 12.0 * speed_ratio)
		_chassis.position.y = (0.006 + 0.012 * speed_ratio) * sin(_bob_time * 3.1)
		# Nose up under power, roll into the turn.
		_chassis.rotation.x = lerpf(_chassis.rotation.x, -0.05 * speed_ratio, w)
		_chassis.rotation.z = lerpf(_chassis.rotation.z,
			0.18 * _turn_signed * speed_ratio, w)
