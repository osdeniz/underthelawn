class_name Neighborhood
extends Node3D
## The static environment — REFERENCE.md §11 (pool visuals) and §12 (the whole
## neighborhood inventory). Everything is MeshInstance3D primitive combinations
## under this single node; textures come from textures/ via TextureLibrary with
## flat-colour fallbacks. Only the flowers and clouds animate.

var _mats := {}
var _sway: Array = []      # { node, phase }
var _clouds: Array = []    # { node, base_x, phase }
var _time := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = 20260823
	_build_yard()
	_build_house()
	_build_pool()
	_build_obstacle_props()
	_build_fence()
	_build_trees()
	_build_road()
	_build_cars()
	_build_neighbors()
	_build_smalls()
	_build_clouds()
	# LawnView builds its grey placeholders in Game._ready, after this node's
	# _ready — hide them once the real props exist.
	_hide_placeholders.call_deferred()


func _hide_placeholders() -> void:
	var ph := get_node_or_null("../Lawn/ObstaclePlaceholders") as Node3D
	if ph:
		ph.visible = false


func _process(delta: float) -> void:
	_time += delta
	for entry in _sway:
		var node: Node3D = entry["node"]
		node.rotation.z = sin(_time * TAU / GameConfig.FLOWER_SWAY_PERIOD
			+ entry["phase"]) * GameConfig.FLOWER_SWAY_AMP
	for entry in _clouds:
		var node: Node3D = entry["node"]
		node.position.x = entry["base_x"] + sin(_time * TAU / GameConfig.CLOUD_PERIOD
			+ entry["phase"]) * GameConfig.CLOUD_DRIFT


# ---------------------------------------------------------------- materials

## Texture-backed material with a flat-colour fallback and a console warning.
func _tex_mat(key: String, tex_name: String, fallback: Color, rough := 0.9,
		uv_scale := Vector3.ONE) -> StandardMaterial3D:
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	var tex := TextureLibrary.find(tex_name)
	if tex != null:
		m.albedo_texture = tex
		m.uv1_scale = uv_scale
	else:
		TextureLibrary.warn_missing(tex_name, "duz renk kullaniliyor")
		m.albedo_color = fallback
	m.roughness = rough
	_mats[key] = m
	return m


func _flat(key: String, color: Color, rough := 0.85, metal := 0.0) -> StandardMaterial3D:
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	m.metallic = metal
	_mats[key] = m
	return m


# ---------------------------------------------------------------- mesh helpers

func _box(parent: Node3D, size: Vector3, mat: Material, pos: Vector3,
		rot := Vector3.ZERO) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return _mesh(parent, mesh, mat, pos, rot)


func _cyl(parent: Node3D, r_top: float, r_bottom: float, height: float,
		mat: Material, pos: Vector3, rot := Vector3.ZERO, segs := 12) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = r_top
	mesh.bottom_radius = r_bottom
	mesh.height = height
	mesh.radial_segments = segs
	mesh.rings = 1
	return _mesh(parent, mesh, mat, pos, rot)


func _ball(parent: Node3D, radius: float, mat: Material, pos: Vector3,
		scale := Vector3.ONE) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 12
	mesh.rings = 6
	var mi := _mesh(parent, mesh, mat, pos)
	mi.scale = scale
	return mi


func _mesh(parent: Node3D, mesh: Mesh, mat: Material, pos: Vector3,
		rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	return mi


## Flat ground rectangle (no shadow casting).
func _ground_quad(parent: Node3D, size: Vector2, mat: Material, pos: Vector3) -> MeshInstance3D:
	var mesh := PlaneMesh.new()
	mesh.size = size
	var mi := _mesh(parent, mesh, mat, pos)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


## Four-face pyramid roof (§12 "piramit çatı"), UV-mapped per face.
func _pyramid(parent: Node3D, base: Vector2, height: float, mat: Material,
		pos: Vector3) -> MeshInstance3D:
	var hw := base.x * 0.5
	var hd := base.y * 0.5
	var apex := Vector3(0.0, height, 0.0)
	var c := [Vector3(-hw, 0, -hd), Vector3(hw, 0, -hd),
		Vector3(hw, 0, hd), Vector3(-hw, 0, hd)]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 4:
		var a: Vector3 = c[i]
		var b: Vector3 = c[(i + 1) % 4]
		var normal := (b - a).cross(apex - a).normalized()
		st.set_normal(normal)
		st.set_uv(Vector2(0, 1)); st.add_vertex(a)
		st.set_normal(normal)
		st.set_uv(Vector2(2, 1)); st.add_vertex(b)
		st.set_normal(normal)
		st.set_uv(Vector2(1, 0)); st.add_vertex(apex)
	return _mesh(parent, st.commit(), mat, pos)


func _ao_blob(parent: Node3D, size: Vector2, pos: Vector3, alpha := 1.0) -> MeshInstance3D:
	var quad := QuadMesh.new()
	quad.size = size
	var m := StandardMaterial3D.new()
	m.albedo_texture = TextureLibrary.ao_radial()
	m.albedo_color = Color(1, 1, 1, alpha)
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var mi := _mesh(parent, quad, m, pos, Vector3(-PI * 0.5, 0, 0))
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


# ---------------------------------------------------------------- yard

## Dirt apron under everything that is not lawn — without it the house, road
## and porch float over the sky.
func _build_yard() -> void:
	var dirt := _tex_mat("dirt", "dirt_albedo", Color(0.38, 0.28, 0.18), 1.0,
		Vector3(14.0, 12.0, 1.0))
	_ground_quad(self, Vector2(90.0, 76.0), dirt, Vector3(0.0, -0.04, 6.0))


# ---------------------------------------------------------------- house (§12)

func _build_house() -> void:
	var house := Node3D.new()
	house.name = "House"
	house.position = Vector3(0.0, 0.0, GameConfig.HOUSE_POS_Z)
	add_child(house)

	var siding := _tex_mat("siding", "siding_albedo", Color(0.78, 0.77, 0.72), 0.85,
		Vector3(3.0, 1.0, 1.0))
	var shingles := _tex_mat("shingles", "roof_shingles_albedo",
		Color(0.42, 0.26, 0.20), 0.9, Vector3(2.0, 2.0, 1.0))
	var trim := _flat("trim", Color(0.93, 0.92, 0.88), 0.7)
	var dark_interior := _flat("interior", Color(0.05, 0.05, 0.07), 0.9)
	var curtain := _flat("curtain", Color(0.92, 0.88, 0.78), 0.9)
	var brick := _flat("brick", Color(0.52, 0.28, 0.20), 0.9)
	var door_mat := _flat("door", Color(0.36, 0.22, 0.13), 0.6)
	var bush := _flat("bush", Color(0.14, 0.30, 0.12), 1.0)
	var wood := _tex_mat("wood", "wood_albedo", Color(0.55, 0.42, 0.27), 0.85)

	var body := GameConfig.HOUSE_BODY
	_box(house, body, siding, Vector3(0.0, body.y * 0.5, 0.0))
	_pyramid(house, Vector2(GameConfig.HOUSE_ROOF.x, GameConfig.HOUSE_ROOF.z),
		GameConfig.HOUSE_ROOF.y, shingles, Vector3(0.0, body.y, 0.0))

	# Chimney: brick stack + cap, poking through the east roof slope.
	_box(house, Vector3(0.5, 1.6, 0.5), brick, Vector3(3.4, body.y + 1.1, 0.0))
	_box(house, Vector3(0.66, 0.12, 0.66), trim, Vector3(3.4, body.y + 1.96, 0.0))

	var wall_z := body.z * 0.5 + 0.01   # south face, toward the lawn

	# Door: frame + two recessed panels + doormat on the porch.
	_box(house, Vector3(1.16, 2.16, 0.06), trim, Vector3(0.0, 1.08, wall_z))
	_box(house, Vector3(1.0, 2.0, 0.06), door_mat, Vector3(0.0, 1.0, wall_z + 0.03))
	_box(house, Vector3(0.68, 0.7, 0.03), _flat("door_panel", Color(0.30, 0.18, 0.10), 0.6),
		Vector3(0.0, 1.42, wall_z + 0.065))
	_box(house, Vector3(0.68, 0.7, 0.03), _mats["door_panel"], Vector3(0.0, 0.58, wall_z + 0.065))
	_box(house, Vector3(0.9, 0.02, 0.55), _flat("mat", Color(0.42, 0.32, 0.22), 1.0),
		Vector3(0.0, 0.30, wall_z + 0.42))

	# Two windows: frame, dark interior, curtains, glass, cross muntin, sill.
	var glass := _flat("glass", Color(0.65, 0.78, 0.88, 0.35), 0.1, 0.85)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	for wx: float in [-3.4, 3.4]:
		_box(house, Vector3(1.5, 1.25, 0.05), trim, Vector3(wx, 1.7, wall_z))
		_box(house, Vector3(1.3, 1.05, 0.02), dark_interior, Vector3(wx, 1.7, wall_z + 0.02))
		_box(house, Vector3(0.28, 1.05, 0.03), curtain, Vector3(wx - 0.51, 1.7, wall_z + 0.03))
		_box(house, Vector3(0.28, 1.05, 0.03), curtain, Vector3(wx + 0.51, 1.7, wall_z + 0.03))
		var pane := _box(house, Vector3(1.3, 1.05, 0.02), glass, Vector3(wx, 1.7, wall_z + 0.045))
		pane.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_box(house, Vector3(0.05, 1.05, 0.03), trim, Vector3(wx, 1.7, wall_z + 0.05))
		_box(house, Vector3(1.3, 0.05, 0.03), trim, Vector3(wx, 1.7, wall_z + 0.05))
		_box(house, Vector3(1.6, 0.08, 0.16), trim, Vector3(wx, 1.03, wall_z + 0.06))

	# Porch: platform + decking texture + posts + railing + eave + step (§12).
	var porch_z := wall_z + 0.8   # platform centre, house-local
	_box(house, Vector3(5.0, 0.28, 1.6), wood, Vector3(0.0, 0.14, porch_z))
	for px: float in [-2.3, 2.3]:
		_box(house, Vector3(0.12, 2.3, 0.12), trim, Vector3(px, 1.43, porch_z + 0.6))
	_box(house, Vector3(5.4, 0.12, 2.0), shingles, Vector3(0.0, 2.64, porch_z))
	# Railing: top rail on both sides of the step gap, plus balusters.
	for side: float in [-1.0, 1.0]:
		_box(house, Vector3(1.55, 0.07, 0.07), trim,
			Vector3(side * 1.65, 0.78, porch_z + 0.76))
		for i in 4:
			var bx := side * (0.95 + float(i) * 0.45)
			_box(house, Vector3(0.05, 0.42, 0.05), trim, Vector3(bx, 0.55, porch_z + 0.76))
	_box(house, Vector3(1.4, 0.14, 0.5), wood, Vector3(0.0, 0.07, porch_z + 1.03))

	# Five bushes along the wall, none in front of the door.
	for bx: float in [-5.4, -3.1, 2.9, 4.7, 6.1]:
		_ball(house, 0.42, bush, Vector3(bx, 0.30, wall_z + 0.25),
			Vector3(1.0, 0.72, 1.0))

	# Contact-shadow band along the wall base (§12).
	var band := _ao_blob(house, Vector2(13.0, 1.4), Vector3(0.0, 0.015, wall_z + 0.3), 0.5)
	band.scale = Vector3(1.0, 0.22, 1.0)


# ---------------------------------------------------------------- pool (§11)

func _build_pool() -> void:
	var pool := Node3D.new()
	pool.name = "Pool"
	add_child(pool)
	# Grid rect (10,17,4,3) -> world x 2..6, z 5..8.
	var center := Vector3(4.0, 0.0, 6.5)
	var size := Vector2(4.0, 3.0)

	var water_mesh := PlaneMesh.new()
	water_mesh.size = size - Vector2(0.2, 0.2)
	water_mesh.subdivide_width = 16
	water_mesh.subdivide_depth = 12
	var water_mat := ShaderMaterial.new()
	water_mat.shader = load("res://shaders/pool_water.gdshader")
	water_mat.set_shader_parameter("water_color", GameConfig.POOL_WATER_COLOR)
	water_mat.set_shader_parameter("water_roughness", GameConfig.POOL_WATER_ROUGHNESS)
	water_mat.set_shader_parameter("wave_speed", GameConfig.POOL_WAVE_SPEED)
	water_mat.set_shader_parameter("wave_amp", GameConfig.POOL_WAVE_AMP)
	var water := _mesh(pool, water_mesh, water_mat, center + Vector3(0.0, 0.07, 0.0))
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	# Cream stone border on all four edges (§11).
	var border := _flat("pool_border", GameConfig.POOL_BORDER_COLOR, 0.8)
	var bt := GameConfig.POOL_BORDER_SIZE.x
	var bh := GameConfig.POOL_BORDER_SIZE.y
	var hx := size.x * 0.5
	var hz := size.y * 0.5
	_box(pool, Vector3(size.x + bt * 2.0, bh, bt), border,
		center + Vector3(0.0, bh * 0.5, -hz - bt * 0.5))
	_box(pool, Vector3(size.x + bt * 2.0, bh, bt), border,
		center + Vector3(0.0, bh * 0.5, hz + bt * 0.5))
	_box(pool, Vector3(bt, bh, size.y), border,
		center + Vector3(-hx - bt * 0.5, bh * 0.5, 0.0))
	_box(pool, Vector3(bt, bh, size.y), border,
		center + Vector3(hx + bt * 0.5, bh * 0.5, 0.0))


## Real props on the obstacle cells the model already blocks: the lounger east
## of the pool (§11), the stone, and the flowerbed soil (flowers come later).
func _build_obstacle_props() -> void:
	# Sun lounger at cell (14,18) = world (6.5, 6.5), facing west (§11).
	var lounger := Node3D.new()
	lounger.name = "Lounger"
	lounger.position = Vector3(6.5, 0.0, 6.5)
	lounger.rotation.y = PI * 0.5   # -Z model faces west
	add_child(lounger)
	var wood := _tex_mat("wood", "wood_albedo", Color(0.55, 0.42, 0.27), 0.85)
	_box(lounger, Vector3(0.6, 0.05, 1.0), wood, Vector3(0.0, 0.28, 0.15))
	_box(lounger, Vector3(0.6, 0.05, 0.55), wood, Vector3(0.0, 0.47, -0.53),
		Vector3(-0.7, 0.0, 0.0))
	for leg in [Vector3(-0.26, 0.14, -0.3), Vector3(0.26, 0.14, -0.3),
			Vector3(-0.26, 0.14, 0.55), Vector3(0.26, 0.14, 0.55)]:
		_box(lounger, Vector3(0.05, 0.28, 0.05), wood, leg)
	_box(lounger, Vector3(0.4, 0.08, 0.3), _flat("towel", Color(0.95, 0.55, 0.15), 0.95),
		Vector3(0.0, 0.34, 0.35))

	# The stone at cell (11,9) = world (3.5, -2.5).
	_ball(self, 0.42, _flat("stone", Color(0.55, 0.54, 0.52), 0.95),
		Vector3(3.5, 0.16, -2.5), Vector3(1.15, 0.55, 0.9))

	# Flowerbed soil at cells (4-5,14) = world x -4..-2, z 2..3.
	var dirt := _tex_mat("dirt", "dirt_albedo", Color(0.38, 0.28, 0.18), 1.0)
	_box(self, Vector3(2.0, 0.12, 1.0), dirt, Vector3(-3.0, 0.06, 2.5))


# ---------------------------------------------------------------- fence (§12)

## Posts as ONE MultiMesh (a hundred-plus instances, one draw call) plus three
## long beam boxes. Each post gets ±0.05 height and ±0.025 rad tilt jitter.
func _build_fence() -> void:
	var wood := _tex_mat("wood", "wood_albedo", Color(0.55, 0.42, 0.27), 0.85)
	var post_size := GameConfig.FENCE_POST
	var mesh := BoxMesh.new()
	mesh.size = post_size

	var transforms: Array[Transform3D] = []
	var runs := [
		# [start, end] — west side, east side, south side. No fence up north (§2).
		[Vector3(-GameConfig.FENCE_SIDE_X, 0, -13.0), Vector3(-GameConfig.FENCE_SIDE_X, 0, GameConfig.FENCE_SOUTH_Z)],
		[Vector3(GameConfig.FENCE_SIDE_X, 0, -13.0), Vector3(GameConfig.FENCE_SIDE_X, 0, GameConfig.FENCE_SOUTH_Z)],
		[Vector3(-GameConfig.FENCE_SIDE_X, 0, GameConfig.FENCE_SOUTH_Z), Vector3(GameConfig.FENCE_SIDE_X, 0, GameConfig.FENCE_SOUTH_Z)],
	]
	for run in runs:
		var a: Vector3 = run[0]
		var b: Vector3 = run[1]
		var dir := (b - a).normalized()
		var length := (b - a).length()
		var count := int(length / GameConfig.FENCE_SPACING)
		var along_x := absf(dir.x) > absf(dir.z)
		for i in count + 1:
			var pos := a + dir * (float(i) * GameConfig.FENCE_SPACING)
			var h := post_size.y + _rng.randf_range(
				-GameConfig.FENCE_HEIGHT_JITTER, GameConfig.FENCE_HEIGHT_JITTER)
			var tilt := _rng.randf_range(
				-GameConfig.FENCE_ANGLE_JITTER, GameConfig.FENCE_ANGLE_JITTER)
			var basis := Basis(Vector3.FORWARD if along_x else Vector3.RIGHT, tilt)
			# Boards face along the run.
			if not along_x:
				basis = Basis(Vector3.UP, PI * 0.5) * basis
			basis = basis.scaled(Vector3(1.0, h / post_size.y, 1.0))
			transforms.append(Transform3D(basis, pos + Vector3(0.0, h * 0.5, 0.0)))

		# One horizontal beam per run.
		var mid := (a + b) * 0.5 + Vector3(0.0, 0.62, 0.0)
		var beam_size := Vector3(length, 0.07, 0.05) if along_x \
			else Vector3(0.05, 0.07, length)
		_box(self, beam_size, wood, mid)

	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = transforms.size()
	for i in transforms.size():
		mm.set_instance_transform(i, transforms[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "FencePosts"
	mmi.multimesh = mm
	mmi.material_override = wood
	add_child(mmi)


# ---------------------------------------------------------------- trees (§12)

func _build_trees() -> void:
	var bark := _tex_mat("bark", "bark_albedo", Color(0.34, 0.25, 0.16), 0.95)
	var leaf_dark := _flat("leaf_dark", GameConfig.TREE_LEAF_DARK, 1.0)
	var leaf_light := _flat("leaf_light", GameConfig.TREE_LEAF_LIGHT, 1.0)

	for spec in GameConfig.TREES:
		var tree := Node3D.new()
		tree.position = Vector3(spec.x, 0.0, spec.y)
		tree.scale = Vector3.ONE * spec.z
		add_child(tree)

		# Slightly leaning trunk plus two angled branches.
		_cyl(tree, 0.14, 0.20, 2.4, bark, Vector3(0.0, 1.2, 0.0),
			Vector3(0.0, 0.0, 0.06))
		_cyl(tree, 0.06, 0.09, 1.1, bark, Vector3(0.35, 2.35, 0.1),
			Vector3(0.0, 0.0, -0.55))
		_cyl(tree, 0.05, 0.08, 0.9, bark, Vector3(-0.3, 2.2, -0.1),
			Vector3(0.35, 0.0, 0.5))

		# Nine deformed leaf clumps in a ring: lower ones dark, upper light,
		# random per-axis scale (§12).
		for i in 9:
			var a := TAU * float(i) / 9.0
			var ring_r := 0.55 + _rng.randf_range(-0.15, 0.25)
			var y := 2.6 + (0.9 if i % 3 == 0 else 0.35) + _rng.randf_range(-0.15, 0.2)
			var mat: StandardMaterial3D = leaf_light if y > 3.2 else leaf_dark
			_ball(tree, 0.55, mat,
				Vector3(cos(a) * ring_r, y, sin(a) * ring_r),
				Vector3(_rng.randf_range(0.8, 1.3), _rng.randf_range(0.6, 1.0),
					_rng.randf_range(0.8, 1.3)))

		# Leaf shadow blot, offset away from the §13 sun (upper-left).
		_ao_blob(tree, Vector2(3.2, 2.6), Vector3(0.9, 0.02, 0.5), 0.6)


# ---------------------------------------------------------------- road (§2, §12)

func _build_road() -> void:
	var concrete := _flat("concrete", Color(0.62, 0.61, 0.58), 0.95)
	var joint := _flat("joint", Color(0.48, 0.47, 0.45), 0.95)
	var asphalt := _tex_mat("asphalt", "asphalt_albedo", Color(0.16, 0.16, 0.17), 0.95,
		Vector3(10.0, 2.0, 1.0))
	var dash_mat := _flat("dash", Color(0.85, 0.75, 0.35), 0.8)

	_ground_quad(self, Vector2(GameConfig.ROAD_WIDTH, GameConfig.SIDEWALK_DEPTH),
		concrete, Vector3(0.0, -0.02, GameConfig.SIDEWALK_Z))
	# Sidewalk joints every 2 units.
	var joints := int(GameConfig.ROAD_WIDTH / 2.0)
	for i in joints:
		var x := -GameConfig.ROAD_WIDTH * 0.5 + 1.0 + float(i) * 2.0
		_box(self, Vector3(0.05, 0.012, GameConfig.SIDEWALK_DEPTH), joint,
			Vector3(x, -0.012, GameConfig.SIDEWALK_Z))

	_ground_quad(self, Vector2(GameConfig.ROAD_WIDTH, GameConfig.ROAD_DEPTH),
		asphalt, Vector3(0.0, -0.03, GameConfig.ROAD_Z))
	# Dashed centre line, 1.6 x 0.14 dashes every 4 units (§12).
	var dashes := int(GameConfig.ROAD_WIDTH / GameConfig.ROAD_DASH_GAP)
	for i in dashes:
		var x := -GameConfig.ROAD_WIDTH * 0.5 + 2.0 + float(i) * GameConfig.ROAD_DASH_GAP
		_box(self, Vector3(GameConfig.ROAD_DASH.x, 0.012, GameConfig.ROAD_DASH.y),
			dash_mat, Vector3(x, -0.018, GameConfig.ROAD_Z))


# ---------------------------------------------------------------- cars (§12)

func _build_cars() -> void:
	_car(GameConfig.CAR_SEDAN_COLOR, false, Vector3(-5.5, 0.0, 18.6), -PI * 0.5)
	_car(GameConfig.CAR_PICKUP_COLOR, true, Vector3(6.5, 0.0, 18.6), PI * 0.5)


func _car(paint_color: Color, is_pickup: bool, pos: Vector3, yaw: float) -> void:
	var car := Node3D.new()
	car.position = pos
	car.rotation.y = yaw
	add_child(car)

	var paint := StandardMaterial3D.new()
	paint.albedo_color = paint_color
	paint.metallic = GameConfig.CAR_PAINT_METALLIC
	paint.roughness = GameConfig.CAR_PAINT_ROUGHNESS
	var glass := _flat("car_glass", Color(0.08, 0.10, 0.13), 0.08, 0.9)
	var tire := _flat("car_tire", Color(0.06, 0.06, 0.07), 0.9)
	var rim := _flat("car_rim", Color(0.72, 0.73, 0.75), 0.3, 0.85)
	var plate := _flat("plate", Color(0.92, 0.92, 0.88), 0.6)
	var seam := _flat("seam", Color(0.05, 0.05, 0.06), 0.6)

	var head := _flat("headlight", Color(1.0, 0.95, 0.75), 0.3)
	if head.emission_enabled == false:
		head.emission_enabled = true
		head.emission = Color(1.0, 0.9, 0.6)
		head.emission_energy_multiplier = 1.2
	var tail := _flat("taillight", Color(0.9, 0.1, 0.08), 0.4)
	if tail.emission_enabled == false:
		tail.emission_enabled = true
		tail.emission = Color(0.9, 0.08, 0.05)
		tail.emission_energy_multiplier = 1.0

	# Lower body; cabin sits centred on the sedan, forward on the pickup.
	_box(car, Vector3(1.7, 0.5, 4.0), paint, Vector3(0.0, 0.5, 0.0))
	var cab_z := -0.7 if is_pickup else 0.1
	_box(car, Vector3(1.5, 0.55, 1.7), paint, Vector3(0.0, 1.0, cab_z))
	# Dark reflective glasshouse block + side windows.
	_box(car, Vector3(1.36, 0.42, 1.5), glass, Vector3(0.0, 1.03, cab_z))
	for side: float in [-1.0, 1.0]:
		var win := _box(car, Vector3(0.02, 0.32, 1.2), glass,
			Vector3(side * 0.765, 1.02, cab_z))
		win.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# Door seam + mirror.
		_box(car, Vector3(0.02, 0.42, 0.02), seam, Vector3(side * 0.86, 0.52, cab_z + 0.5))
		_box(car, Vector3(0.16, 0.09, 0.06), paint, Vector3(side * 0.93, 1.06, cab_z - 0.75))
	if is_pickup:
		# Open bed: floor + three thin walls.
		_box(car, Vector3(1.5, 0.06, 1.7), seam, Vector3(0.0, 0.78, 1.0))
		_box(car, Vector3(1.5, 0.3, 0.06), paint, Vector3(0.0, 0.92, 1.85))
		for side: float in [-1.0, 1.0]:
			_box(car, Vector3(0.06, 0.3, 1.7), paint, Vector3(side * 0.72, 0.92, 1.0))

	# Lights and plates (front is -Z).
	for side: float in [-1.0, 1.0]:
		_box(car, Vector3(0.32, 0.14, 0.04), head, Vector3(side * 0.55, 0.62, -2.01))
		_box(car, Vector3(0.28, 0.12, 0.04), tail, Vector3(side * 0.55, 0.62, 2.01))
	_box(car, Vector3(0.44, 0.14, 0.03), plate, Vector3(0.0, 0.38, -2.02))
	_box(car, Vector3(0.44, 0.14, 0.03), plate, Vector3(0.0, 0.38, 2.02))

	# Wheels: tire + rim + hub, four corners.
	for wz: float in [-1.35, 1.35]:
		for side: float in [-1.0, 1.0]:
			var wheel_pos := Vector3(side * 0.85, 0.32, wz)
			_cyl(car, 0.32, 0.32, 0.22, tire, wheel_pos, Vector3(0.0, 0.0, PI * 0.5), 14)
			_cyl(car, 0.19, 0.19, 0.24, rim, wheel_pos, Vector3(0.0, 0.0, PI * 0.5), 10)
			_ball(car, 0.06, seam, wheel_pos + Vector3(side * 0.13, 0.0, 0.0))

	_ao_blob(car, Vector2(2.4, 4.6), Vector3(0.0, 0.02, 0.0), 0.55)


# ---------------------------------------------------------------- neighbors (§12)

func _build_neighbors() -> void:
	var bodies := [
		_flat("nb_cream", Color(0.88, 0.84, 0.72), 0.9),
		_flat("nb_sage", Color(0.62, 0.70, 0.58), 0.9),
		_flat("nb_pink", Color(0.80, 0.58, 0.52), 0.9),
	]
	var shingles := _tex_mat("shingles", "roof_shingles_albedo",
		Color(0.42, 0.26, 0.20), 0.9)
	var trim := _flat("trim", Color(0.93, 0.92, 0.88), 0.7)
	var dark := _flat("interior", Color(0.05, 0.05, 0.07), 0.9)

	for i in GameConfig.NEIGHBOR_X.size():
		var h := Node3D.new()
		h.position = Vector3(GameConfig.NEIGHBOR_X[i], 0.0, GameConfig.NEIGHBOR_Z)
		add_child(h)
		_box(h, Vector3(7.5, 2.8, 4.0), bodies[i], Vector3(0.0, 1.4, 0.0))
		_pyramid(h, Vector2(8.3, 4.8), 1.9, shingles, Vector3(0.0, 2.8, 0.0))
		_box(h, Vector3(0.9, 1.9, 0.06), dark, Vector3(0.0, 0.95, -2.01))
		for wx: float in [-2.2, 2.2]:
			_box(h, Vector3(1.1, 0.9, 0.06), trim, Vector3(wx, 1.5, -2.01))
			_box(h, Vector3(0.95, 0.75, 0.04), dark, Vector3(wx, 1.5, -2.04))
		# Mini porch.
		_box(h, Vector3(2.2, 0.18, 0.9), trim, Vector3(0.0, 0.09, -2.5))


# ---------------------------------------------------------------- smalls (§12)

func _build_smalls() -> void:
	var bark := _tex_mat("bark", "bark_albedo", Color(0.34, 0.25, 0.16), 0.95)

	# Mailbox by the sidewalk: post + navy box + red flag.
	var mailbox := Node3D.new()
	mailbox.position = Vector3(7.2, 0.0, 14.1)
	add_child(mailbox)
	_cyl(mailbox, 0.045, 0.055, 1.05, bark, Vector3(0.0, 0.52, 0.0))
	_box(mailbox, Vector3(0.26, 0.22, 0.42), _flat("mailbox", Color(0.14, 0.20, 0.42), 0.5),
		Vector3(0.0, 1.15, 0.0))
	_box(mailbox, Vector3(0.03, 0.16, 0.05), _flat("flag", Color(0.85, 0.12, 0.10), 0.6),
		Vector3(0.15, 1.3, -0.12))

	# Garden hose: three green tori stacked by the east house wall.
	var hose_mat := _flat("hose", Color(0.16, 0.42, 0.16), 0.6)
	for i in 3:
		var torus := TorusMesh.new()
		torus.inner_radius = 0.16
		torus.outer_radius = 0.24
		torus.rings = 20
		torus.ring_segments = 8
		_mesh(self, torus, hose_mat,
			Vector3(5.7 + float(i) * 0.02, 0.05 + float(i) * 0.05, -14.35),
			Vector3(0.0, float(i) * 0.5, 0.0))

	# Flowerbed: 6 mixed flowers on the soil; two garden clusters of 5 (§12).
	for i in 6:
		_flower(i % 3, Vector3(-3.75 + float(i) * 0.32, 0.12, 2.5
			+ (0.22 if i % 2 == 0 else -0.22)))
	for cluster in [Vector3(-8.7, 0.0, 12.8), Vector3(8.5, 0.0, -13.3)]:
		for i in 5:
			var a := TAU * float(i) / 5.0
			_flower(_rng.randi_range(0, 2), cluster
				+ Vector3(cos(a) * 0.35, 0.0, sin(a) * 0.35))


## One flower: stem + head, pivoted at the ground so the §12 wind sway can
## rotate the whole plant. kind 0 = daisy, 1 = tulip, 2 = lavender.
func _flower(kind: int, pos: Vector3) -> void:
	var pivot := Node3D.new()
	pivot.position = pos
	add_child(pivot)
	var stem := _flat("stem", Color(0.20, 0.45, 0.16), 0.9)
	var height := _rng.randf_range(0.24, 0.34)
	_cyl(pivot, 0.012, 0.016, height, stem, Vector3(0.0, height * 0.5, 0.0), Vector3.ZERO, 6)

	match kind:
		0:   # Daisy: 6 white petals + yellow centre.
			var petal := _flat("petal", Color(0.95, 0.95, 0.92), 0.9)
			for i in 6:
				var a := TAU * float(i) / 6.0
				_ball(pivot, 0.035, petal,
					Vector3(cos(a) * 0.05, height, sin(a) * 0.05),
					Vector3(1.4, 0.5, 1.4))
			_ball(pivot, 0.03, _flat("daisy_core", Color(0.95, 0.78, 0.15), 0.8),
				Vector3(0.0, height + 0.01, 0.0))
		1:   # Tulip: cup-shaped oval, random colour.
			var palette := [Color(0.85, 0.25, 0.30), Color(0.90, 0.55, 0.20),
				Color(0.80, 0.35, 0.60), Color(0.95, 0.80, 0.30)]
			var tulip := StandardMaterial3D.new()
			tulip.albedo_color = palette[_rng.randi_range(0, palette.size() - 1)]
			tulip.roughness = 0.8
			_ball(pivot, 0.05, tulip, Vector3(0.0, height + 0.04, 0.0),
				Vector3(0.85, 1.4, 0.85))
		_:   # Lavender: 4 purple beads up a spike.
			var lav := _flat("lavender", Color(0.55, 0.40, 0.80), 0.9)
			for i in 4:
				_ball(pivot, 0.022, lav,
					Vector3(0.0, height + 0.02 + float(i) * 0.045, 0.0))

	_sway.append({ "node": pivot, "phase": _rng.randf() * TAU })


# ---------------------------------------------------------------- clouds (§12)

func _build_clouds() -> void:
	var tex := TextureLibrary.find("cloud_billboard")
	var mat := StandardMaterial3D.new()
	if tex != null:
		mat.albedo_texture = tex
	else:
		TextureLibrary.warn_missing("cloud_billboard", "duz beyaz bulut")
		mat.albedo_color = Color(1, 1, 1, 0.5)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED

	for i in GameConfig.CLOUD_COUNT:
		var size := _rng.randf_range(GameConfig.CLOUD_SIZE_MIN, GameConfig.CLOUD_SIZE_MAX)
		var quad := QuadMesh.new()
		quad.size = Vector2(size, size * 0.5)
		quad.material = mat
		var mi := MeshInstance3D.new()
		mi.mesh = quad
		var base_x := -24.0 + float(i) * 16.0
		mi.position = Vector3(base_x,
			_rng.randf_range(GameConfig.CLOUD_Y_MIN, GameConfig.CLOUD_Y_MAX),
			_rng.randf_range(-34.0, -6.0))
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
		_clouds.append({ "node": mi, "base_x": base_x, "phase": _rng.randf() * TAU })
