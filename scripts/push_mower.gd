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


## The punt (G21): the same node drives, the body is a boat. Every original
## part is hidden rather than freed, so a later yard gets its mower back.
var _hull: Node3D
func set_boat(on: bool) -> void:
	var body := get_node_or_null("Body") as Node3D
	if body == null:
		return
	for child in body.get_children():
		if child != _hull and child is MeshInstance3D:
			(child as MeshInstance3D).visible = not on
	if on:
		params = GameConfig.BOAT.duplicate()
		if _hull == null:
			_hull = _build_hull()
			body.add_child(_hull)
		_hull.visible = true
	else:
		params = GameConfig.MOWER_TYPES[type_index()]
		if _hull != null:
			_hull.visible = false


## A flat-bottomed punt: planked hull, a pointed bow, two thwarts, a scythe
## bar across the bow where the mower's deck would be, and the pole laid along
## the gunwale.
func _build_hull() -> Node3D:
	var hull := Node3D.new()
	hull.name = "Hull"
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.46, 0.34, 0.22)
	wood.roughness = 0.85
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.30, 0.22, 0.15)
	dark.roughness = 0.9
	var iron := StandardMaterial3D.new()
	iron.albedo_color = Color(0.36, 0.37, 0.40)
	iron.roughness = 0.5
	iron.metallic = 0.4
	var mk := func(mesh: Mesh, mat: Material, pos: Vector3, rot := Vector3.ZERO) -> void:
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.material_override = mat
		mi.position = pos
		mi.rotation = rot
		hull.add_child(mi)
	var floor := BoxMesh.new()
	floor.size = Vector3(0.62, 0.08, 1.50)
	mk.call(floor, dark, Vector3(0.0, 0.10, 0.10))
	for side: float in [-1.0, 1.0]:
		var plank := BoxMesh.new()
		plank.size = Vector3(0.06, 0.30, 1.50)
		mk.call(plank, wood, Vector3(side * 0.30, 0.25, 0.10))
	var stern := BoxMesh.new()
	stern.size = Vector3(0.66, 0.30, 0.06)
	mk.call(stern, wood, Vector3(0.0, 0.25, 0.85))
	# The bow: a prism lying on its side, point forward (-Z).
	var bow := PrismMesh.new()
	bow.size = Vector3(0.66, 0.70, 0.30)
	mk.call(bow, wood, Vector3(0.0, 0.25, -1.0), Vector3(-PI * 0.5, 0.0, 0.0))
	for z: float in [-0.30, 0.45]:
		var thwart := BoxMesh.new()
		thwart.size = Vector3(0.60, 0.05, 0.16)
		mk.call(thwart, wood, Vector3(0.0, 0.34, z))
	# The scythe bar: where the deck cuts, an iron edge just above the water.
	var bar := BoxMesh.new()
	bar.size = Vector3(1.40, 0.04, 0.06)
	mk.call(bar, iron, Vector3(0.0, 0.14, -1.30))
	for side2: float in [-1.0, 1.0]:
		var arm := BoxMesh.new()
		arm.size = Vector3(0.04, 0.04, 0.42)
		mk.call(arm, iron, Vector3(side2 * 0.28, 0.16, -1.10))
	# The pole along the starboard gunwale.
	var pole := CylinderMesh.new()
	pole.top_radius = 0.025
	pole.bottom_radius = 0.025
	pole.height = 2.2
	pole.radial_segments = 6
	mk.call(pole, wood, Vector3(0.36, 0.42, 0.0), Vector3(PI * 0.5, 0.0, 0.0))
	return hull


## The plough sled (G23): runners, a frame, a wide blade angled forward, and
## the handlebar the push pose already holds. Same rule as the punt: every
## mower part hidden, not freed.
var _sled: Node3D
func set_sled(on: bool) -> void:
	var body := get_node_or_null("Body") as Node3D
	if body == null:
		return
	for child in body.get_children():
		if child != _sled and child != _hull and child is MeshInstance3D:
			(child as MeshInstance3D).visible = not on
	if on:
		params = GameConfig.SLED.duplicate()
		if _sled == null:
			_sled = _build_sled()
			body.add_child(_sled)
		_sled.visible = true
	else:
		params = GameConfig.MOWER_TYPES[type_index()]
		if _sled != null:
			_sled.visible = false


func _build_sled() -> Node3D:
	var sled := Node3D.new()
	sled.name = "Sled"
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.44, 0.33, 0.22)
	wood.roughness = 0.85
	var iron := StandardMaterial3D.new()
	iron.albedo_color = Color(0.34, 0.35, 0.38)
	iron.roughness = 0.45
	iron.metallic = 0.5
	var mk := func(mesh: Mesh, mat: Material, pos: Vector3, rot := Vector3.ZERO) -> void:
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.material_override = mat
		mi.position = pos
		mi.rotation = rot
		sled.add_child(mi)
	for side: float in [-1.0, 1.0]:
		var runner := BoxMesh.new()
		runner.size = Vector3(0.06, 0.06, 1.5)
		mk.call(runner, iron, Vector3(side * 0.34, 0.03, 0.05))
		var post := BoxMesh.new()
		post.size = Vector3(0.05, 0.22, 0.05)
		mk.call(post, wood, Vector3(side * 0.34, 0.17, -0.4))
		mk.call(post, wood, Vector3(side * 0.34, 0.17, 0.5))
	var frame := BoxMesh.new()
	frame.size = Vector3(0.74, 0.05, 1.2)
	mk.call(frame, wood, Vector3(0.0, 0.30, 0.05))
	# The blade: wide, leaning forward, iron, just off the ground.
	var blade := BoxMesh.new()
	blade.size = Vector3(1.5, 0.42, 0.05)
	mk.call(blade, iron, Vector3(0.0, 0.24, -0.78), Vector3(deg_to_rad(-22.0), 0.0, 0.0))
	var lip := BoxMesh.new()
	lip.size = Vector3(1.5, 0.04, 0.10)
	mk.call(lip, iron, Vector3(0.0, 0.05, -0.86))
	# The handlebar, where the hands go.
	for side2: float in [-1.0, 1.0]:
		var bar := CylinderMesh.new()
		bar.top_radius = 0.02
		bar.bottom_radius = 0.02
		bar.height = 0.9
		bar.radial_segments = 6
		mk.call(bar, wood, Vector3(side2 * 0.30, 0.62, 0.95), Vector3(deg_to_rad(-62.0), 0.0, 0.0))
	var grip := CylinderMesh.new()
	grip.top_radius = 0.025
	grip.bottom_radius = 0.025
	grip.height = 0.66
	grip.radial_segments = 6
	mk.call(grip, wood, Vector3(0.0, 1.0, 1.32), Vector3(0.0, 0.0, PI * 0.5))
	return sled

