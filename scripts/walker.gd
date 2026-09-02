class_name Walker
extends Node3D
## The player on foot (G14.16).
##
## Deliberately NOT a MowerController subclass. It shares the input — the same
## `_pad_stick` the pad and WASD both fill, read camera-relative — but none of
## the driving model: no throttle curve, no turn limit, no reverse, and above
## all no cutting. Inheriting all that to then disable it would have left a
## mower pretending to be a person.
##
## What it is for: reaching a crate the tractor cannot turn into, looking at
## the yard from inside it, and standing next to the machine while it works.

signal remount_requested()

var camera_yaw := 0.0
## The camera reads this off whatever it is following. Kept alongside
## rotation.y rather than derived, because the rig also asks a mower for it.
var yaw := 0.0
## The machine we stepped off, for the walk back.
var machine: Node3D
var character: Character

var _velocity := Vector2.ZERO
var _source: MowerController


func setup(from: MowerController, driver: Character, at: Vector3) -> void:
	machine = from
	_source = from
	character = driver
	position = Vector3(at.x, 0.0, at.z)
	if driver != null:
		# The person comes with us, reparented and set walking — at WAIST
		# height, because the figure's root is its waist and its legs hang
		# below it. At y 0 the legs were underground, which is exactly what
		# "the man has no feet" looked like (G14.17).
		driver.set_mode(Character.Mode.PUSH, null, self)
		driver.position = Vector3(0.0, GameConfig.CHAR_WALK_WAIST_Y, 0.0)


## Where a stick points, on foot. Kept as a static and used by the test that
## compares it against the machine's own answer, because "forward" meaning two
## different things depending on whether you are riding is the bug this exists
## to prevent (G14.17).
static func direction_for(camera_yaw: float, stick: Vector2) -> Vector2:
	var heading := camera_yaw + atan2(stick.x, stick.y)
	# (cos, sin), the same as MowerController._forward(). It was (sin, cos),
	# which is that vector MIRRORED across the 45-degree line: on foot the
	# player went east when the machine would have gone south.
	return Vector2(cos(heading), sin(heading))


## Whether the machine can be climbed back onto from here.
func in_reach() -> bool:
	if machine == null or not is_instance_valid(machine):
		return false
	return Vector2(position.x - machine.position.x,
		position.z - machine.position.z).length() <= GameConfig.WALK_REMOUNT


func _physics_process(delta: float) -> void:
	# The same stick the machine would have read, so walking inherits the pad,
	# the keyboard and the camera-relative rule for free.
	var stick := _source.pad_stick() if _source != null and is_instance_valid(_source) \
		else Vector2.ZERO
	var wanted := Vector2.ZERO
	if stick.length_squared() > 0.0001:
		var strength := minf(stick.length(), 1.0)
		wanted = direction_for(camera_yaw, stick) * strength * GameConfig.WALK_SPEED
	# A person stops and starts much faster than a machine, but not instantly.
	_velocity = _velocity.lerp(wanted, minf(1.0, GameConfig.WALK_TURN * delta))
	position += Vector3(_velocity.x, 0.0, _velocity.y) * delta
	# Inside the fence, like every other body in the yard.
	position.x = clampf(position.x, -GameConfig.HALF_X + 0.4,
		GameConfig.HALF_X - 0.4)
	position.z = clampf(position.z, -GameConfig.HALF_Z + 0.4,
		GameConfig.HALF_Z - 0.4)
	if _velocity.length() > 0.05:
		rotation.y = atan2(_velocity.x, _velocity.y)
		yaw = rotation.y
	# The driver's walk cycle is driven by speed, and it has no controller now,
	# so feed it directly.
	if character != null and is_instance_valid(character):
		character.walk_speed = _velocity.length() / GameConfig.WALK_SPEED


## The camera does NOT swing round behind a walking person: turning on the spot
## would spin the whole yard, and the stick is camera-relative, so a chasing
## yaw would also change what "forward" means while the player holds it.
func camera_yaw_locked() -> bool:
	return true


## How fast we are going, as a fraction, for the camera and the HUD.
func speed_fraction() -> float:
	return _velocity.length() / GameConfig.WALK_SPEED
