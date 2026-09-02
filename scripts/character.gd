class_name Character
extends Node3D
## The driver — REFERENCE.md §8. No skeleton: every joint is its own Node3D
## pivot and all animation is sine/lerp, exactly like the SceneKit original.
##
## Three modes: walking behind the push mower, riding the tractor, or sitting
## at the edge of the lawn watching the robot. One material set, shadows on.
##
## SIGN NOTE: §8 rotations are SceneKit eulers. In this build limbs hang along
## -Y, so "swing forward" (towards -Z) is POSITIVE rotation.x for limbs and
## NEGATIVE rotation.x for the torso (which points +Y). Magnitudes are §8's;
## signs are adapted to that convention.

enum Mode { PUSH, TRACTOR, SIT }

var mode: Mode = Mode.PUSH
## Active mower, for speed and steering; null while sitting.
var controller: MowerController
## Set by Walker when there is no machine: 0..1, how fast the person is going.
var walk_speed := 0.0

var _torso: Node3D
var _head: Node3D
var _shoulder_l: Node3D
var _shoulder_r: Node3D
var _hip_l: Node3D
var _hip_r: Node3D
var _knee_l: Node3D
var _knee_r: Node3D

var _phase := 0.0
var _breath := 0.0
var _materials := {}
## -1 = the Marshal's own orange. Anything else indexes CHAR_OUTFITS.
var _outfit := -1
var _ao: MeshInstance3D


func _ready() -> void:
	_build()
	set_mode(Mode.PUSH, null)


# ---------------------------------------------------------------- mode API

## Reparents the character and applies the base pose for the mode. For PUSH and
## TRACTOR `anchor` is the mower (local seat offsets from §8); for SIT it is the
## scene root and the bench constants place it near the north edge.
func set_mode(new_mode: Mode, mower: MowerController, anchor: Node3D = null) -> void:
	mode = new_mode
	controller = mower

	if anchor != null and get_parent() != anchor:
		if get_parent() != null:
			get_parent().remove_child(self)
		anchor.add_child(self)

	rotation = Vector3.ZERO
	_reset_joints()
	match mode:
		Mode.PUSH:
			position = GameConfig.CHAR_PUSH_SEAT
			_pose_push()
		Mode.TRACTOR:
			position = GameConfig.CHAR_TRACTOR_SEAT
			_pose_tractor(0.0, 0.0)
		Mode.SIT:
			position = Vector3(GameConfig.CHAR_BENCH_POS.x,
				GameConfig.CHAR_BENCH_WAIST_Y, GameConfig.CHAR_BENCH_POS.z)
			rotation.y = -GameConfig.CHAR_BENCH_YAW
			_pose_sit()


# ---------------------------------------------------------------- animation

func _process(delta: float) -> void:
	# Cleared before the pose runs; a pose that wants the head somewhere sets
	# these and _update_look adds the look on top.
	_look_base_yaw = 0.0
	_look_base_pitch = 0.0
	match mode:
		Mode.PUSH:
			_update_push(delta)
		Mode.TRACTOR:
			_update_tractor(delta)
		Mode.SIT:
			_update_sit(delta)
	# Last, and additive: the poses above own the head's BASE rotation (the
	# tractor's follows the steering), so the look is applied on top of
	# whatever they left rather than fighting them for the same property.
	_update_look(delta)


# ---------------------------------------------------------------- life

## Something worth looking at, in world space, or `false` in "has" if there is
## nothing. Set from outside — Game knows what has just been uncovered and what
## is still lying in the grass; the figure only knows how to turn its head.
var look_target := Vector3.ZERO
var look_has := false
var _look_yaw := 0.0
var _look_pitch := 0.0
var _look_base_yaw := 0.0
var _look_base_pitch := 0.0
var _shade_mat: StandardMaterial3D
var _roll := 0.0
var _shift := 0.0
var _shift_side := 1.0
var _shift_timer := 0.0


## Points the head at `look_target` when there is one, and back to neutral when
## there is not (G14.22). What makes a figure this size read as alive is not
## detail, it is that it NOTICES things.
func _update_look(delta: float) -> void:
	if _head == null:
		return
	var want_yaw := 0.0
	var want_pitch := 0.0
	if look_has:
		# Into the head's own space, so the numbers are "how far to turn from
		# where the body already faces".
		# Measured against the TORSO, not the head: aiming off a transform this
		# function itself rotates is a feedback loop, and the head would chase
		# its own offset.
		var local := _torso.global_transform.affine_inverse() * look_target
		var flat := Vector2(local.x, -local.z)
		if flat.length() > 0.001:
			want_yaw = clampf(atan2(local.x, -local.z),
				-GameConfig.LOOK_YAW_MAX, GameConfig.LOOK_YAW_MAX)
			want_pitch = clampf(atan2(local.y, flat.length()),
				-GameConfig.LOOK_PITCH_MAX, GameConfig.LOOK_PITCH_MAX)
	var w := minf(1.0, GameConfig.LOOK_LERP * delta)
	_look_yaw = lerpf(_look_yaw, want_yaw, w)
	_look_pitch = lerpf(_look_pitch, want_pitch, w)
	# ASSIGNED, not added. Adding integrated the offset every frame: the head
	# wound past five radians in under two seconds, which is four full turns
	# of a neck (G14.22). The pose declares a base and this is the only place
	# that writes the head's rotation.
	_head.rotation.y = _look_base_yaw + _look_yaw
	_head.rotation.x = _look_base_pitch + _look_pitch


## Weight onto one leg, swapping every few seconds. Three joints, a few degrees
## each: a figure standing perfectly level on both feet reads as a mannequin.
func _update_idle_shift(delta: float) -> void:
	_shift_timer += delta
	if _shift_timer >= GameConfig.IDLE_SHIFT_PERIOD:
		_shift_timer = 0.0
		_shift_side = -_shift_side
	var w := minf(1.0, GameConfig.IDLE_SHIFT_LERP * delta)
	_shift = lerpf(_shift, _shift_side, w)
	# The loaded hip rises, the free one drops, and the torso leans over the
	# leg that is carrying — which is what the shift actually looks like.
	_hip_l.position.y = -_shift * GameConfig.IDLE_HIP_DROP
	_hip_r.position.y = _shift * GameConfig.IDLE_HIP_DROP
	# Assigned from the pose's own value plus the shift, never added to what is
	# already on the node.
	_torso.rotation.z = _roll + _shift * GameConfig.IDLE_TORSO_ROLL
	_torso.rotation.y = _shift * GameConfig.IDLE_TORSO_YAW


## Walking behind the mower (§8): legs swing in opposite phase, knees fold only
## on the back swing, the torso rolls and bobs. Idle recovers and breathes.
func _update_push(delta: float) -> void:
	# With no controller the walk is driven directly (G14.16): on foot there is
	# no machine to read a speed off, and the arms are not on a handlebar.
	var sf := controller.speed_fraction() if controller else walk_speed
	_torso.rotation.x = -GameConfig.CHAR_PUSH_LEAN if controller != null \
		else -GameConfig.CHAR_PUSH_LEAN * 0.35

	if sf > GameConfig.WALK_MIN_SPEED:
		_phase += delta * (GameConfig.WALK_PHASE_BASE + GameConfig.WALK_PHASE_GAIN * sf)
		var s := sin(_phase)
		_hip_l.rotation.x = s * GameConfig.WALK_LEG_SWING
		_hip_r.rotation.x = -s * GameConfig.WALK_LEG_SWING
		# Knees fold only while that leg swings back.
		_knee_l.rotation.x = -maxf(0.0, -s) * GameConfig.WALK_KNEE_BEND
		_knee_r.rotation.x = -maxf(0.0, s) * GameConfig.WALK_KNEE_BEND
		_roll = s * GameConfig.WALK_TORSO_ROLL
		_torso.rotation.z = _roll
		_torso.position.y = absf(s) * GameConfig.WALK_BOB
		# Free arms swing opposite the legs; on the handlebar they do not.
		if controller == null:
			_shoulder_l.rotation.x = -s * GameConfig.WALK_LEG_SWING * 0.7
			_shoulder_r.rotation.x = s * GameConfig.WALK_LEG_SWING * 0.7
	else:
		var w := minf(1.0, GameConfig.IDLE_RECOVER_RATE * delta)
		_hip_l.rotation.x = lerpf(_hip_l.rotation.x, 0.0, w)
		_hip_r.rotation.x = lerpf(_hip_r.rotation.x, 0.0, w)
		_knee_l.rotation.x = lerpf(_knee_l.rotation.x, 0.0, w)
		_knee_r.rotation.x = lerpf(_knee_r.rotation.x, 0.0, w)
		# The roll decays in its OWN variable. Reading it back off the node and
		# then adding the weight shift to it every frame amplified a 3 degree
		# lean into a 30 degree one — the same trap the head fell into: a
		# constant added to a value that only decays by a fraction settles at
		# constant/fraction (G14.22).
		_roll = lerpf(_roll, 0.0, w)
		_torso.rotation.z = _roll
		_breath += delta
		_torso.position.y = sin(_breath * GameConfig.BREATH_FREQ) * GameConfig.BREATH_AMP
		_update_idle_shift(delta)


## Riding the tractor (§8): the body answers the steering — torso yaw lags the
## wheel, the head follows at 0.6, the arms shift with it, and the engine adds a
## fine vertical shiver.
func _update_tractor(delta: float) -> void:
	var steer := 0.0
	if controller:
		steer = clampf(controller.omega / controller.max_turn(), -1.0, 1.0)

	var target := -steer * GameConfig.STEER_TORSO_YAW
	_torso.rotation.y = lerpf(_torso.rotation.y, target,
		minf(1.0, GameConfig.STEER_TORSO_LERP * delta))
	_look_base_yaw = _torso.rotation.y * GameConfig.STEER_HEAD_FACTOR

	_pose_tractor(steer, _torso.rotation.y)

	_phase += delta
	_torso.position.y = sin(_phase * GameConfig.ENGINE_VIB_FREQ) * GameConfig.ENGINE_VIB_AMP


## Sitting at the lawn edge, watching the robot: still pose plus breath.
func _update_sit(delta: float) -> void:
	_breath += delta
	_torso.position.y = sin(_breath * GameConfig.BREATH_FREQ) * GameConfig.BREATH_AMP


# ---------------------------------------------------------------- poses

func _pose_push() -> void:
	# On foot there is no handlebar, so the arms hang and the lean comes off
	# (G14.16). Same mode, because the leg cycle is the same walk.
	if controller == null:
		_torso.rotation.x = -GameConfig.CHAR_PUSH_LEAN * 0.35
		_shoulder_l.rotation.x = 0.0
		_shoulder_r.rotation.x = 0.0
		_shoulder_l.rotation.z = GameConfig.CHAR_PUSH_ARM_INWARD * 0.4
		_shoulder_r.rotation.z = -GameConfig.CHAR_PUSH_ARM_INWARD * 0.4
		return
	_torso.rotation.x = -GameConfig.CHAR_PUSH_LEAN
	# Arms forward-down to the handle, slightly inward.
	_shoulder_l.rotation.x = GameConfig.CHAR_PUSH_ARM_X
	_shoulder_r.rotation.x = GameConfig.CHAR_PUSH_ARM_X
	_shoulder_l.rotation.z = GameConfig.CHAR_PUSH_ARM_INWARD
	_shoulder_r.rotation.z = -GameConfig.CHAR_PUSH_ARM_INWARD


func _pose_tractor(steer: float, torso_yaw: float) -> void:
	# Thighs horizontal, shins down.
	_hip_l.rotation.x = GameConfig.CHAR_SIT_THIGH
	_hip_r.rotation.x = GameConfig.CHAR_SIT_THIGH
	_knee_l.rotation.x = -GameConfig.CHAR_SIT_SHIN
	_knee_r.rotation.x = -GameConfig.CHAR_SIT_SHIN
	# Arms up to the wheel, inward, shifting with the steering (§8).
	_shoulder_l.rotation.x = GameConfig.CHAR_WHEEL_ARM_X
	_shoulder_r.rotation.x = GameConfig.CHAR_WHEEL_ARM_X
	_shoulder_l.rotation.y = -GameConfig.CHAR_WHEEL_ARM_INWARD
	_shoulder_r.rotation.y = GameConfig.CHAR_WHEEL_ARM_INWARD
	_shoulder_l.rotation.z = GameConfig.STEER_ARM_Z_BASE + steer * GameConfig.STEER_ARM_Z_GAIN
	_shoulder_r.rotation.z = -GameConfig.STEER_ARM_Z_BASE + steer * GameConfig.STEER_ARM_Z_GAIN
	_torso.rotation.x = 0.0
	_torso.rotation.y = torso_yaw


func _pose_sit() -> void:
	_hip_l.rotation.x = GameConfig.CHAR_SIT_THIGH
	_hip_r.rotation.x = GameConfig.CHAR_SIT_THIGH
	# Feet flat on the ground: shins fold all the way back down.
	_knee_l.rotation.x = -GameConfig.CHAR_SIT_THIGH
	_knee_r.rotation.x = -GameConfig.CHAR_SIT_THIGH
	# Hands resting near the knees.
	_shoulder_l.rotation.x = 0.5
	_shoulder_r.rotation.x = 0.5
	_torso.rotation.x = 0.0


func _reset_joints() -> void:
	for joint in [_torso, _head, _shoulder_l, _shoulder_r,
			_hip_l, _hip_r, _knee_l, _knee_r]:
		joint.rotation = Vector3.ZERO
	_torso.position.y = 0.0


# ---------------------------------------------------------------- build (§8)

## A translucent black form, for shading a seam. Unshaded so the light cannot
## brighten it back out, and never written into _materials by colour key —
## every shade shares one material (G14.24).
func _shade(parent: Node3D, radius: float, height: float, pos: Vector3,
		colour: Color, squash := Vector3.ONE) -> void:
	if _shade_mat == null:
		_shade_mat = StandardMaterial3D.new()
		_shade_mat.albedo_color = colour
		_shade_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_shade_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_shade_mat.disable_receive_shadows = true
	var mat := _shade_mat
	if not is_equal_approx(colour.a, _shade_mat.albedo_color.a):
		mat = StandardMaterial3D.new()
		mat.albedo_color = colour
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.disable_receive_shadows = true
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 10
	mesh.rings = 1
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = mat
	node.position = pos
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if not squash.is_equal_approx(Vector3.ONE):
		node.scale = squash
	parent.add_child(node)


## Hair under the hat (G14.21): a cap on the back of the skull and a tuft at
## each temple, all of it BEHIND the face and BELOW the brim. A sphere the size
## of the head would have covered the eyes, and hair drawn above the brim line
## would have been inside the hat.
func _build_hair(r: float, hair: StandardMaterial3D) -> void:
	var mid := r * 0.6
	# Back of the head: a squashed ball pushed back and down out of the face.
	_sphere(_head, GameConfig.CHAR_HAIR_BACK, hair,
		Vector3(0.0, mid + r * 0.02, r * 0.18),
		Vector3(1.02, 0.94, 0.96))
	for side: float in [-1.0, 1.0]:
		_sphere(_head, GameConfig.CHAR_HAIR_TUFT, hair,
			Vector3(side * r * 0.80, mid + r * 0.26, r * 0.04),
			Vector3(0.7, 1.0, 1.0))


## Eyes, brows and a mouth, as flat boxes on the front of the head (G14.19).
##
## Sunk slightly INTO the sphere rather than floating on it, and kept tiny: at
## the distance the game is played at the face is a handful of pixels, so what
## matters is that the head has a FRONT. A blank ball under a hat reads as a
## mannequin from any distance at all.
func _build_face(r: float) -> void:
	var eye := _mat("eye", GameConfig.CHAR_EYE, 0.6)
	var brow := _mat("brow", GameConfig.CHAR_BROW, 0.9)
	var mouth := _mat("mouth", GameConfig.CHAR_MOUTH, 0.8)
	var front := -r * 0.94
	var mid := r * 0.6
	for side: float in [-1.0, 1.0]:
		_box(_head, GameConfig.CHAR_EYE_SIZE, eye,
			Vector3(side * GameConfig.CHAR_EYE_GAP,
				mid + GameConfig.CHAR_EYE_Y, front))
		_box(_head, GameConfig.CHAR_BROW_SIZE, brow,
			Vector3(side * GameConfig.CHAR_EYE_GAP,
				mid + GameConfig.CHAR_BROW_Y, front))
	_box(_head, GameConfig.CHAR_MOUTH_SIZE, mouth,
		Vector3(0.0, mid + GameConfig.CHAR_MOUTH_Y, front))


## Dresses this figure from CHAR_OUTFITS. Call BEFORE the body is built; the
## Marshal leaves it alone and keeps the orange shirt.
func wear(outfit_index: int) -> void:
	_outfit = outfit_index % GameConfig.CHAR_OUTFITS.size()


func _mat(key: String, color: Color, roughness := 0.85) -> StandardMaterial3D:
	if _materials.has(key):
		return _materials[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	_materials[key] = m
	return m


## A tapered prism, for the one form on this figure that is not a limb.
## `depth` squashes the prism along Z. A CylinderMesh is circular, so without
## it the torso came out as a BARREL — as deep as it was wide — where a chest is
## roughly half as deep as it is broad (G14.20).
func _taper(parent: Node3D, top_radius: float, bottom_radius: float,
		height: float, mat: Material, pos: Vector3, sides := 0,
		depth := 1.0) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top_radius
	mesh.bottom_radius = bottom_radius
	mesh.height = height
	mesh.radial_segments = sides if sides > 0 else GameConfig.CHAR_TORSO_SIDES
	mesh.rings = 1
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = mat
	node.position = pos
	# Turned an eighth so a flat face points at the camera rather than a corner.
	node.rotation.y = PI / float(mesh.radial_segments)
	if not is_equal_approx(depth, 1.0):
		node.scale = Vector3(1.0, 1.0, depth)
	parent.add_child(node)


func _box(parent: Node3D, size: Vector3, mat: StandardMaterial3D,
		pos: Vector3) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi


## `squash` lets one sphere be a skull cap or a temple tuft rather than a ball
## (G14.21): hair is not spherical, and neither is anything else on a person.
func _sphere(parent: Node3D, radius: float, mat: StandardMaterial3D,
		pos: Vector3, squash := Vector3.ONE) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 14
	mesh.rings = 7
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	if not squash.is_equal_approx(Vector3.ONE):
		mi.scale = squash
	parent.add_child(mi)
	return mi


func _cylinder(parent: Node3D, radius: float, height: float,
		mat: StandardMaterial3D, pos: Vector3) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 14
	mesh.rings = 1
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi


func _pivot(parent: Node3D, pivot_name: String, pos: Vector3) -> Node3D:
	var node := Node3D.new()
	node.name = pivot_name
	node.position = pos
	parent.add_child(node)
	return node


func _build() -> void:
	# The Marshal (_outfit < 0) keeps the orange shirt: the player has to be
	# findable in a yard at a glance. Everyone else is dressed from the table.
	var kit: Dictionary = GameConfig.CHAR_OUTFITS[_outfit] if _outfit >= 0 \
		else {"shirt": GameConfig.CHAR_SHIRT, "jeans": GameConfig.CHAR_JEANS,
			"hat": GameConfig.CHAR_HAT, "hair": GameConfig.CHAR_HAIR}
	var hair := _mat("hair", kit.get("hair", GameConfig.CHAR_HAIR), 0.95)
	var shirt := _mat("shirt", kit["shirt"])
	var skin := _mat("skin", GameConfig.CHAR_SKIN)
	var jeans := _mat("jeans", kit["jeans"])
	var hat := _mat("hat", kit["hat"])
	var band := _mat("band", GameConfig.CHAR_BAND)
	var boot := _mat("boot", GameConfig.CHAR_BOOT, 0.82)

	# The pelvis is on the ROOT, not the torso: it belongs to the legs, and a
	# torso roll must not take the hips with it.
	var ps := GameConfig.CHAR_PELVIS_SIZE
	# INSIDE the shirt, not level with it. At the same radius as the torso's
	# waist the two surfaces were coincident, and one facet of the pelvis won
	# the depth test on the back — a crisp grey rectangle in the middle of the
	# shirt, which took a full-resolution crop to identify (G14.21).
	# The hem's own shadow on the jeans below it.
	_shade(self, GameConfig.CHAR_WAIST_RADIUS * 0.98,
		GameConfig.CHAR_SHADE_THIN,
		Vector3(0.0, GameConfig.CHAR_SHIRT_LIFT - 0.012, 0.0),
		GameConfig.CHAR_SHADE, Vector3(1.0, 1.0, GameConfig.CHAR_TORSO_DEPTH))
	_taper(self, GameConfig.CHAR_WAIST_RADIUS * GameConfig.CHAR_PELVIS_INSET,
		GameConfig.CHAR_LEG_TOP * 1.9, ps.y, jeans,
		Vector3(0.0, ps.y * 0.1, 0.0),
		GameConfig.CHAR_TORSO_SIDES, GameConfig.CHAR_TORSO_DEPTH)

	# Torso pivots at the waist; the box sits above it.
	_torso = _pivot(self, "Torso", Vector3.ZERO)
	var ts := GameConfig.CHAR_TORSO_SIZE
	# One tapered prism: shoulders wider than hips, eight sides so the silhouette
	# has shape without going round. See CHAR_CHEST_RADIUS for what this replaced.
	var lift := GameConfig.CHAR_SHIRT_LIFT
	_taper(_torso, GameConfig.CHAR_CHEST_RADIUS, GameConfig.CHAR_WAIST_RADIUS,
		ts.y - lift, shirt, Vector3(0.0, lift + (ts.y - lift) * 0.5, 0.0),
		GameConfig.CHAR_TORSO_SIDES, GameConfig.CHAR_TORSO_DEPTH)
	# And a neck, so the head is attached to something.
	var ns := GameConfig.CHAR_NECK_SIZE
	_box(_torso, ns, skin, Vector3(0.0, ts.y + ns.y * 0.4, 0.0))
	# Nor under the chin, for the same reason: the chest's top is a flat cap
	# and a disc on it reads as a grey square, not as shade.

	# Head on top of the torso: sphere + brow band + sun hat.
	_head = _pivot(_torso, "Head", Vector3(0.0, ts.y + 0.06, 0.0))
	var r := GameConfig.CHAR_HEAD_RADIUS
	_sphere(_head, r, skin, Vector3(0.0, r * 0.6, 0.0))
	_build_face(r)
	_build_hair(r, hair)
	# NO fake shade under the brim, and this is the finding rather than an
	# omission (G14.24): a translucent plate near a CURVED surface always shows
	# its own silhouette. At the brim's radius it stood out past the skull into
	# open air; hugged to the head it still read as a scrim with edges across
	# the forehead. Both were rendered and both were wrong.
	#
	# The seam shades that DO work are the ones on limbs, where the ring and
	# the surface are near-identical cylinders. The brim's shadow is the sun's
	# job, and the sun already casts it.
	# The band belongs to the HAT, around the crown just under the brim. It used
	# to sit at 0.75r on the front of the head — straight across the eyes — so
	# every figure in the game appeared to be wearing sunglasses, and adding a
	# real face only made that read louder (G14.19).
	_cylinder(_head, GameConfig.CHAR_HAT_TOP_RADIUS * 1.06,
		GameConfig.CHAR_BAND_SIZE.y, band,
		Vector3(0.0, r * 1.35 + GameConfig.CHAR_BAND_SIZE.y * 0.7, 0.0))
	_cylinder(_head, GameConfig.CHAR_HAT_BRIM_RADIUS, 0.02, hat,
		Vector3(0.0, r * 1.35, 0.0))
	_cylinder(_head, GameConfig.CHAR_HAT_TOP_RADIUS, 0.09, hat,
		Vector3(0.0, r * 1.35 + 0.055, 0.0))

	# Arms: shoulder pivot -> upper arm (shirt) -> elbow -> lower arm (skin) -> hand.
	for side in [-1.0, 1.0]:
		var shoulder := _pivot(_torso, "Shoulder%s" % ("L" if side < 0 else "R"),
			Vector3(side * GameConfig.CHAR_SHOULDER.x, GameConfig.CHAR_SHOULDER.y, 0.0))
		# A shoulder, so the arm grows out of the body instead of floating
		# beside it.
		_sphere(_torso, GameConfig.CHAR_ARM_TOP * 0.98, shirt,
			Vector3(side * GameConfig.CHAR_SHOULDER.x * 0.92,
				GameConfig.CHAR_SHOULDER.y, 0.0))
		# Tapered, not boxed (G14.20): a square-section limb is the single
		# loudest thing that says "made of bricks", and the arm narrows from
		# shoulder to wrist on a real one.
		_taper(shoulder, GameConfig.CHAR_ARM_TOP, GameConfig.CHAR_ARM_MID,
			GameConfig.CHAR_UPPER_ARM, shirt,
			Vector3(0.0, -GameConfig.CHAR_UPPER_ARM * 0.5, 0.0),
			GameConfig.CHAR_LIMB_SIDES)
		var elbow := _pivot(shoulder, "Elbow", Vector3(0.0, -GameConfig.CHAR_UPPER_ARM, 0.0))
		# A ball in the joint, so the two halves meet in an elbow rather than
		# in a corner.
		_sphere(shoulder, GameConfig.CHAR_ARM_MID * 1.02, skin,
			Vector3(0.0, -GameConfig.CHAR_UPPER_ARM, 0.0))
		_taper(elbow, GameConfig.CHAR_ARM_MID, GameConfig.CHAR_ARM_WRIST,
			GameConfig.CHAR_LOWER_ARM, skin,
			Vector3(0.0, -GameConfig.CHAR_LOWER_ARM * 0.5, 0.0),
			GameConfig.CHAR_LIMB_SIDES)
		# A hand: a flattened palm with a thumb on the inside edge (G14.21).
		# The cube it replaced read as a brick on a stick, and the thumb is the
		# one detail at this size that says which way a hand faces.
		var palm := GameConfig.CHAR_PALM
		var wrist := -GameConfig.CHAR_LOWER_ARM
		_box(elbow, palm, skin, Vector3(0.0, wrist - palm.y * 0.45, 0.0))
		var th := GameConfig.CHAR_THUMB
		_box(elbow, th, skin,
			Vector3(-side * (palm.x * 0.5 + th.x * 0.35),
				wrist - palm.y * 0.30, palm.z * 0.10))
		if side < 0:
			_shoulder_l = shoulder
		else:
			_shoulder_r = shoulder

	# Legs: hip pivot on the ROOT (torso roll must not move them) -> upper leg
	# (jeans) -> knee -> lower leg -> boot pointing forward.
	for side in [-1.0, 1.0]:
		var hip := _pivot(self, "Hip%s" % ("L" if side < 0 else "R"),
			Vector3(side * GameConfig.CHAR_HIP_X, 0.0, 0.0))
		_taper(hip, GameConfig.CHAR_LEG_TOP, GameConfig.CHAR_LEG_KNEE,
			GameConfig.CHAR_UPPER_LEG, jeans,
			Vector3(0.0, -GameConfig.CHAR_UPPER_LEG * 0.5, 0.0),
			GameConfig.CHAR_LIMB_SIDES)
		var knee := _pivot(hip, "Knee", Vector3(0.0, -GameConfig.CHAR_UPPER_LEG, 0.0))
		_sphere(hip, GameConfig.CHAR_LEG_KNEE * 1.02, jeans,
			Vector3(0.0, -GameConfig.CHAR_UPPER_LEG, 0.0))
		_taper(knee, GameConfig.CHAR_LEG_KNEE, GameConfig.CHAR_LEG_ANKLE, 
			GameConfig.CHAR_LOWER_LEG, jeans,
			Vector3(0.0, -GameConfig.CHAR_LOWER_LEG * 0.5, 0.0),
			GameConfig.CHAR_LIMB_SIDES)
		# The foot: an upper that meets the shin, a sole that meets the ground,
		# and a toe box in front of both. The old single box sat inside the
		# bottom of the leg and disappeared at play distance.
		var bs := GameConfig.CHAR_BOOT_SIZE
		var ss := GameConfig.CHAR_BOOT_SOLE
		var ankle := -GameConfig.CHAR_LOWER_LEG
		# Where the trouser ends on the boot.
		_shade(knee, GameConfig.CHAR_LEG_ANKLE * 1.10,
			GameConfig.CHAR_SHADE_THIN, Vector3(0.0, ankle + 0.010, 0.0),
			GameConfig.CHAR_SHADE)
		_box(knee, bs, boot,
			Vector3(0.0, ankle - bs.y * 0.5, -bs.z * 0.16))
		_box(knee, ss, boot,
			Vector3(0.0, ankle - bs.y - ss.y * 0.5, -bs.z * 0.16))
		# Toe cap, forward of the sole: what makes the foot POINT somewhere.
		_box(knee, Vector3(bs.x * 0.9, bs.y * 0.7, GameConfig.CHAR_BOOT_TOE), boot,
			Vector3(0.0, ankle - bs.y * 0.62,
				-bs.z * 0.16 - bs.z * 0.5 - GameConfig.CHAR_BOOT_TOE * 0.4))
		if side < 0:
			_hip_l = hip
			_knee_l = knee
		else:
			_hip_r = hip
			_knee_r = knee

	# Small contact shadow; the character stands ~0.75 above its own origin's
	# parent-ground only in SIT mode, so keep the AO on the root.
	var quad := QuadMesh.new()
	quad.size = Vector2(GameConfig.CHAR_AO_SIZE, GameConfig.CHAR_AO_SIZE)
	var ao_mat := StandardMaterial3D.new()
	ao_mat.albedo_texture = TextureLibrary.ao_radial()
	ao_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ao_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ao_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var ao := MeshInstance3D.new()
	ao.name = "FakeAO"
	ao.mesh = quad
	ao.material_override = ao_mat
	ao.rotation.x = -PI * 0.5
	# The root rides at seat height on the mowers; drop the decal to the ground.
	ao.position = Vector3(0.0, 0.03, 0.0)
	ao.top_level = false
	ao.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ao)
	_ao = ao


## The AO decal must hug the ground whatever height the waist rides at.
func _physics_process(_delta: float) -> void:
	if _ao:
		_ao.global_position = Vector3(global_position.x, 0.03, global_position.z)
