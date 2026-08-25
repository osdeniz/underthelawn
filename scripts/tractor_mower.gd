class_name TractorMower
extends MowerController
## Tractor input — REFERENCE.md §7 "Traktör".
##
## Joystick Y is the throttle (reverse runs at 0.5x, §6); joystick X is the
## steering, and its sign flips in reverse the way a real vehicle behaves.
## The joystick Control lives in the HUD and swallows its own touches.

var joystick: TractorJoystick


## Where the haul rides: the bed, not the driver's back (G12.9).
var carry_anchor: Node3D

var _discs: Array[Node3D] = []


func _ready() -> void:
	_build_bed()
	_build_discs()
	super()


## An open cargo bed behind the seat: a floor and three low walls, built from the
## same boxes as the rest of the tractor.
func _build_bed() -> void:
	var body := get_node_or_null("Body") as Node3D
	if body == null:
		return
	var paint := StandardMaterial3D.new()
	paint.albedo_color = GameConfig.TRACTOR_BODY_COLOR.darkened(0.12)
	paint.roughness = 0.75
	var trim := StandardMaterial3D.new()
	trim.albedo_color = GameConfig.TRACTOR_ACCENT_COLOR
	trim.roughness = 0.6

	var size := GameConfig.TRACTOR_BED_SIZE
	var at := GameConfig.TRACTOR_BED_POS
	_box(body, size, paint, at)
	var wall := GameConfig.TRACTOR_BED_WALL
	# Three walls; the front stays open so the load is visible from the camera.
	_box(body, Vector3(size.x, wall, 0.05), trim,
		at + Vector3(0.0, wall * 0.5, size.z * 0.5))
	for side: float in [-1.0, 1.0]:
		_box(body, Vector3(0.05, wall, size.z), trim,
			at + Vector3(side * size.x * 0.5, wall * 0.5, 0.0))

	carry_anchor = Node3D.new()
	carry_anchor.name = "BedAnchor"
	carry_anchor.position = at + Vector3(0.0, 0.05, 0.0)
	body.add_child(carry_anchor)


## Two cutter discs at the front, spinning while the tractor moves — the same
## read as the Blade, scaled down and doubled.
func _build_discs() -> void:
	var body := get_node_or_null("Body") as Node3D
	if body == null:
		return
	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color(0.72, 0.73, 0.70)
	steel.metallic = 0.7
	steel.roughness = 0.3
	var hub_mat := StandardMaterial3D.new()
	hub_mat.albedo_color = GameConfig.TRACTOR_ACCENT_COLOR
	hub_mat.roughness = 0.5

	for side: float in [-1.0, 1.0]:
		var pivot := Node3D.new()
		pivot.position = Vector3(side * GameConfig.TRACTOR_DISC_OFFSET.x,
			GameConfig.TRACTOR_DISC_OFFSET.y, GameConfig.TRACTOR_DISC_OFFSET.z)
		body.add_child(pivot)
		var plate := CylinderMesh.new()
		plate.top_radius = GameConfig.TRACTOR_DISC_RADIUS
		plate.bottom_radius = GameConfig.TRACTOR_DISC_RADIUS
		plate.height = 0.03
		plate.radial_segments = 18
		_mesh_child(pivot, plate, steel, Vector3.ZERO)
		# Four blades on the plate, so the spin is visible rather than a smear.
		for i in 4:
			var blade := BoxMesh.new()
			blade.size = Vector3(GameConfig.TRACTOR_DISC_RADIUS * 1.9, 0.02, 0.07)
			_mesh_child(pivot, blade, steel, Vector3(0.0, 0.025, 0.0),
				Vector3(0.0, TAU * float(i) / 8.0, 0.0))
		var hub := CylinderMesh.new()
		hub.top_radius = 0.07
		hub.bottom_radius = 0.07
		hub.height = 0.06
		hub.radial_segments = 10
		_mesh_child(pivot, hub, hub_mat, Vector3(0.0, 0.04, 0.0))
		_discs.append(pivot)


func _box(parent: Node3D, size: Vector3, mat: Material, pos: Vector3) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	_mesh_child(parent, mesh, mat, pos)


func _mesh_child(parent: Node3D, mesh: Mesh, mat: Material, pos: Vector3,
		rot := Vector3.ZERO) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)


func _process(delta: float) -> void:
	# The discs idle slowly and spin up with the machine, like the Blade's.
	var rate := deg_to_rad(GameConfig.TRACTOR_DISC_SPIN_DEG)
	var turn := (0.15 + 0.85 * speed_fraction()) * rate * delta
	for i in _discs.size():
		_discs[i].rotation.y += turn * (1.0 if i == 0 else -1.0)


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
