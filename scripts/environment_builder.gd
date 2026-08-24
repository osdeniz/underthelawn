class_name Neighborhood
extends Node3D
## The static environment — REFERENCE.md §11 (pool visuals) and §12 (the whole
## neighborhood inventory). Everything is MeshInstance3D primitive combinations
## under this single node; textures come from textures/ via TextureLibrary with
## flat-colour fallbacks. Only the flowers and clouds animate.

var _mats := {}
var _sway: Array = []      # { node, phase }
var _clouds: Array = []    # { node, base_x, phase }
var _canopies: Array = []  # { node, phase } — G6 micro-motion
var _flag: Node3D
var _flag_timer := 0.0
var _bird: AudioStreamPlayer
var _bird_timer := 0.0
var _time := 0.0
var _rng := RandomNumberGenerator.new()
var _variant: LevelVariant
## This chapter's resolved obstacle rects; props and the pool follow it.
var _layout: Array[Dictionary] = []


func _ready() -> void:
	# G9: decor_seed makes every random choice below repeatable per chapter, so a
	# yard looks the same on every visit but different from the next chapter.
	_variant = LevelVariant.current
	_rng.seed = _variant.decor_seed if _variant != null and _variant.decor_seed != 0 \
		else 20260823
	_layout = LawnModel.resolve_layout(LawnModel.layout_id)
	if _variant != null and _variant.vignette:
		_apply_cellar_mood()
	_build_yard()
	if _variant != null and _variant.landmark_id != "":
		_build_landmark(_variant.landmark_id)
	else:
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
	if GameConfig.SKY_HIGH_CLOUDS_ENABLED:
		_build_high_clouds()
	_build_driveways()
	_setup_bird()
	_flag_timer = _rng.randf_range(GameConfig.FLAG_INTERVAL_MIN, GameConfig.FLAG_INTERVAL_MAX)
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
	if GameConfig.MICRO_MOTION_ENABLED:
		_micro_motion(delta)


## G6: slow canopy sway, the occasional mailbox flag salute, a rare single bird.
func _micro_motion(delta: float) -> void:
	for entry in _canopies:
		var node: Node3D = entry["node"]
		node.rotation.z = sin(_time * TAU / GameConfig.CANOPY_SWAY_PERIOD
			+ entry["phase"]) * GameConfig.CANOPY_SWAY_AMP

	if _flag != null:
		_flag_timer -= delta
		if _flag_timer <= 0.0:
			_flag_timer = _rng.randf_range(GameConfig.FLAG_INTERVAL_MIN,
				GameConfig.FLAG_INTERVAL_MAX)
			var tw := create_tween()
			tw.tween_property(_flag, "rotation:z", -PI * 0.5, 1.2) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			tw.tween_interval(4.0)
			tw.tween_property(_flag, "rotation:z", 0.0, 1.2) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	if _bird != null:
		_bird_timer -= delta
		if _bird_timer <= 0.0:
			_bird_timer = _rng.randf_range(GameConfig.BIRD_INTERVAL_MIN,
				GameConfig.BIRD_INTERVAL_MAX)
			_bird.play()


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
	house.position = Vector3(0.0, 0.0, GameConfig.house_pos_z())
	add_child(house)

	# Variant colours tint the SAME textures, so a different house is a data
	# change rather than new art.
	var spec: Dictionary = GameConfig.HOUSE_VARIANTS.get(_house_variant_id(), {})
	if spec.is_empty():
		# house_none: the chapter has no house at all.
		house.queue_free()
		return
	var siding := _tex_mat("siding_" + _house_variant_id(), "siding_albedo",
		spec.get("body", Color(0.78, 0.77, 0.72)), 0.85, Vector3(3.0, 1.0, 1.0))
	var shingles := _tex_mat("shingles_" + _house_variant_id(),
		"roof_shingles_albedo", spec.get("roof", Color(0.42, 0.26, 0.20)), 0.9,
		Vector3(2.0, 2.0, 1.0))
	var has_porch := bool(spec.get("porch", true))
	var has_chimney := bool(spec.get("chimney", true))
	var trim := _flat("trim", Color(0.93, 0.92, 0.88), 0.82)
	var dark_interior := _flat("interior", Color(0.05, 0.05, 0.07), 0.9)
	var curtain := _flat("curtain", Color(0.92, 0.88, 0.78), 0.9)
	var brick := _flat("brick", Color(0.52, 0.28, 0.20), 0.9)
	var door_mat := _flat("door", Color(0.36, 0.22, 0.13), 0.75)
	var bush := _flat("bush", Color(0.14, 0.30, 0.12), 1.0)
	var wood := _tex_mat("wood", "wood_albedo", Color(0.55, 0.42, 0.27), 0.85)

	var body := GameConfig.HOUSE_BODY
	_box(house, body, siding, Vector3(0.0, body.y * 0.5, 0.0))
	_pyramid(house, Vector2(GameConfig.HOUSE_ROOF.x, GameConfig.HOUSE_ROOF.z),
		GameConfig.HOUSE_ROOF.y, shingles, Vector3(0.0, body.y, 0.0))

	# Chimney: brick stack + cap, poking through the east roof slope.
	if has_chimney:
		_box(house, Vector3(0.5, 1.6, 0.5), brick, Vector3(3.4, body.y + 1.1, 0.0))
		_box(house, Vector3(0.66, 0.12, 0.66), trim, Vector3(3.4, body.y + 1.96, 0.0))

	var wall_z := body.z * 0.5 + 0.01   # south face, toward the lawn

	# Door: frame + two recessed panels + doormat on the porch.
	_box(house, Vector3(1.16, 2.16, 0.06), trim, Vector3(0.0, 1.08, wall_z))
	_box(house, Vector3(1.0, 2.0, 0.06), door_mat, Vector3(0.0, 1.0, wall_z + 0.03))
	_box(house, Vector3(0.68, 0.7, 0.03), _flat("door_panel", Color(0.30, 0.18, 0.10), 0.75),
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
	# Only the layouts that actually place a pool get one (G9).
	var rect := _layout_rect("pool")
	if rect == Rect2():
		return
	var pool := Node3D.new()
	pool.name = "Pool"
	add_child(pool)
	var center := Vector3(rect.position.x + rect.size.x * 0.5, 0.0,
		rect.position.y + rect.size.y * 0.5)
	var size := rect.size
	var hx := size.x * 0.5
	var hz := size.y * 0.5

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
	water_mat.set_shader_parameter("fancy", GameConfig.WATER_FANCY_ENABLED)
	water_mat.set_shader_parameter("wave2_speed", GameConfig.WATER_WAVE2_SPEED)
	water_mat.set_shader_parameter("wave2_freq", GameConfig.WATER_WAVE2_FREQ)
	water_mat.set_shader_parameter("wave2_amp", GameConfig.WATER_WAVE2_AMP)
	water_mat.set_shader_parameter("fresnel_power", GameConfig.WATER_FRESNEL_POWER)
	water_mat.set_shader_parameter("alpha_facing", GameConfig.WATER_ALPHA_FACING)
	water_mat.set_shader_parameter("alpha_grazing", GameConfig.WATER_ALPHA_GRAZING)
	var water := _mesh(pool, water_mesh, water_mat, center + Vector3(0.0, 0.07, 0.0))
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	# Tiled pool bottom with a refraction wobble, just above the lawn tint (G6).
	var floor_mesh := PlaneMesh.new()
	floor_mesh.size = size - Vector2(0.2, 0.2)
	var floor_mat := ShaderMaterial.new()
	floor_mat.shader = load("res://shaders/pool_floor.gdshader")
	floor_mat.set_shader_parameter("fancy", GameConfig.WATER_FANCY_ENABLED)
	var floor := _mesh(pool, floor_mesh, floor_mat, center + Vector3(0.0, 0.012, 0.0))
	floor.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	# Dark wet band on the border's inner lip (G6).
	var wet := _flat("wet_band", Color(0.55, 0.55, 0.52), 0.35)
	var wb := 0.06
	_box(pool, Vector3(size.x, 0.1, wb), wet, center + Vector3(0.0, 0.055, -hz + wb * 0.5))
	_box(pool, Vector3(size.x, 0.1, wb), wet, center + Vector3(0.0, 0.055, hz - wb * 0.5))
	_box(pool, Vector3(wb, 0.1, size.y), wet, center + Vector3(-hx + wb * 0.5, 0.055, 0.0))
	_box(pool, Vector3(wb, 0.1, size.y), wet, center + Vector3(hx - wb * 0.5, 0.055, 0.0))

	# Cream stone border on all four edges (§11).
	var border := _flat("pool_border", GameConfig.POOL_BORDER_COLOR, 0.8)
	var bt := GameConfig.POOL_BORDER_SIZE.x
	var bh := GameConfig.POOL_BORDER_SIZE.y
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
	var wood := _tex_mat("wood", "wood_albedo", Color(0.55, 0.42, 0.27), 0.85)
	var stone_mat := _flat("stone", Color(0.55, 0.54, 0.52), 0.95)
	var dirt := _tex_mat("dirt", "dirt_albedo", Color(0.38, 0.28, 0.18), 1.0)

	# One prop per obstacle the LAYOUT placed, at the rect the model will collide
	# against — so a chapter never shows a prop it can drive through, or collides
	# with something invisible.
	for ob: Dictionary in _layout:
		var rect := LawnModel.grid_rect_to_world(ob["grid"])
		var centre := Vector3(rect.position.x + rect.size.x * 0.5, 0.0,
			rect.position.y + rect.size.y * 0.5)
		match str(ob["name"]):
			"stone":
				_ball(self, 0.42, stone_mat, centre + Vector3(0.0, 0.16, 0.0),
					Vector3(1.15, 0.55, 0.9))
			"flowerbed":
				_box(self, Vector3(rect.size.x, 0.12, rect.size.y), dirt,
					centre + Vector3(0.0, 0.06, 0.0))
			"sunbed":
				_build_lounger(centre, wood)


## Sun lounger, facing west, nudged east so its frame clears the pool border.
func _build_lounger(centre: Vector3, wood: Material) -> void:
	var lounger := Node3D.new()
	lounger.name = "Lounger"
	lounger.position = centre + Vector3(0.45, 0.0, 0.0)
	lounger.rotation.y = PI * 0.5   # -Z model faces west
	add_child(lounger)
	_box(lounger, Vector3(0.6, 0.05, 1.0), wood, Vector3(0.0, 0.28, 0.15))
	_box(lounger, Vector3(0.6, 0.05, 0.55), wood, Vector3(0.0, 0.47, -0.53),
		Vector3(-0.7, 0.0, 0.0))
	for leg in [Vector3(-0.26, 0.14, -0.3), Vector3(0.26, 0.14, -0.3),
			Vector3(-0.26, 0.14, 0.55), Vector3(0.26, 0.14, 0.55)]:
		_box(lounger, Vector3(0.05, 0.28, 0.05), wood, leg)
	_box(lounger, Vector3(0.4, 0.08, 0.3),
		_flat("towel", Color(0.95, 0.55, 0.15), 0.95), Vector3(0.0, 0.34, 0.35))


## World rect of the first obstacle with this name, or an empty Rect2.
func _layout_rect(obstacle_name: String) -> Rect2:
	for ob: Dictionary in _layout:
		if str(ob["name"]) == obstacle_name:
			return LawnModel.grid_rect_to_world(ob["grid"])
	return Rect2()


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
		[Vector3(-GameConfig.fence_side_x(), 0, GameConfig.fence_north_z()), Vector3(-GameConfig.fence_side_x(), 0, GameConfig.fence_south_z())],
		[Vector3(GameConfig.fence_side_x(), 0, GameConfig.fence_north_z()), Vector3(GameConfig.fence_side_x(), 0, GameConfig.fence_south_z())],
		[Vector3(-GameConfig.fence_side_x(), 0, GameConfig.fence_south_z()), Vector3(GameConfig.fence_side_x(), 0, GameConfig.fence_south_z())],
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
		tree.position = GameConfig.tree_pos(spec)
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
		# random per-axis scale (§12). All under one canopy pivot so G6 can sway
		# the whole crown cheaply.
		var canopy := Node3D.new()
		canopy.name = "Canopy"
		canopy.position = Vector3(0.0, 0.0, 0.0)
		tree.add_child(canopy)
		_canopies.append({ "node": canopy, "phase": _rng.randf() * TAU })
		for i in 9:
			var a := TAU * float(i) / 9.0
			var ring_r := 0.55 + _rng.randf_range(-0.15, 0.25)
			var y := 2.6 + (0.9 if i % 3 == 0 else 0.35) + _rng.randf_range(-0.15, 0.2)
			var mat: StandardMaterial3D = leaf_light if y > 3.2 else leaf_dark
			_ball(canopy, 0.55, mat,
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
		concrete, Vector3(0.0, -0.02, GameConfig.sidewalk_z()))
	# Sidewalk joints every 2 units.
	var joints := int(GameConfig.ROAD_WIDTH / 2.0)
	for i in joints:
		var x := -GameConfig.ROAD_WIDTH * 0.5 + 1.0 + float(i) * 2.0
		_box(self, Vector3(0.05, 0.012, GameConfig.SIDEWALK_DEPTH), joint,
			Vector3(x, -0.012, GameConfig.sidewalk_z()))

	_ground_quad(self, Vector2(GameConfig.ROAD_WIDTH, GameConfig.ROAD_DEPTH),
		asphalt, Vector3(0.0, -0.03, GameConfig.road_z()))
	# Dashed centre line, 1.6 x 0.14 dashes every 4 units (§12).
	var dashes := int(GameConfig.ROAD_WIDTH / GameConfig.ROAD_DASH_GAP)
	for i in dashes:
		var x := -GameConfig.ROAD_WIDTH * 0.5 + 2.0 + float(i) * GameConfig.ROAD_DASH_GAP
		_box(self, Vector3(GameConfig.ROAD_DASH.x, 0.012, GameConfig.ROAD_DASH.y),
			dash_mat, Vector3(x, -0.018, GameConfig.road_z()))


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
	var trim := _flat("trim", Color(0.93, 0.92, 0.88), 0.82)
	var dark := _flat("interior", Color(0.05, 0.05, 0.07), 0.9)

	for i in GameConfig.NEIGHBOR_X.size():
		var h := Node3D.new()
		h.position = Vector3(GameConfig.NEIGHBOR_X[i], 0.0, GameConfig.neighbor_z())
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
	# Flag on a hinge pivot so G6 can raise and lower it now and then.
	_flag = Node3D.new()
	_flag.name = "FlagHinge"
	_flag.position = Vector3(0.15, 1.22, -0.12)
	mailbox.add_child(_flag)
	_box(_flag, Vector3(0.03, 0.16, 0.05), _flat("flag", Color(0.85, 0.12, 0.10), 0.6),
		Vector3(0.0, 0.08, 0.0))

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

## Thin, wide, static cirrus far above the billboard clouds (G6).
func _build_high_clouds() -> void:
	var tex := TextureLibrary.find("cloud_billboard")
	var mat := StandardMaterial3D.new()
	if tex != null:
		mat.albedo_texture = tex
	mat.albedo_color = Color(1, 1, 1, 0.35)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	for i in GameConfig.HIGH_CLOUD_COUNT:
		var quad := QuadMesh.new()
		quad.size = Vector2(34.0, 7.0)
		quad.material = mat
		var mi := MeshInstance3D.new()
		mi.mesh = quad
		mi.position = Vector3(-26.0 + float(i) * 26.0, GameConfig.HIGH_CLOUD_Y,
			_rng.randf_range(-46.0, -20.0))
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)


## Concrete driveways from the road up to each neighbour house (G6 traffic).
func _build_driveways() -> void:
	var concrete := _flat("concrete", Color(0.62, 0.61, 0.58), 0.95)
	for x in GameConfig.NEIGHBOR_X:
		_ground_quad(self, Vector2(2.6, 3.8), concrete,
			Vector3(x + 2.4, -0.015, GameConfig.road_z() + 5.3))


## Rare single bird chirp over the ambient loop (G6).
func _setup_bird() -> void:
	var base := "res://audio/bird_single"
	for ext in [".ogg", ".wav", ".mp3"]:
		if ResourceLoader.exists(base + ext):
			var stream := load(base + ext) as AudioStream
			if stream != null:
				_bird = AudioStreamPlayer.new()
				_bird.stream = stream
				_bird.volume_db = -14.0
				add_child(_bird)
				break
	if _bird == null:
		print("[Neighborhood] audio/bird_single.ogg yok - tekil kus sesi devre disi")
	_bird_timer = _rng.randf_range(GameConfig.BIRD_INTERVAL_MIN, GameConfig.BIRD_INTERVAL_MAX)


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


# ---------------------------------------------------------------- G9 variants

func _house_variant_id() -> String:
	if _variant == null or _variant.house_variant == "":
		return "house_v1"
	return _variant.house_variant


## Landmarks stand where the house would, at the same distance, so the camera
## framing and the fence line need no special case. One low-detail composition
## each, from the same primitives as the house, all casting shadow.
func _build_landmark(landmark_id: String) -> void:
	var root := Node3D.new()
	root.name = "Landmark_" + landmark_id
	root.position = Vector3(0.0, 0.0, GameConfig.house_pos_z() + 1.6)
	add_child(root)
	match landmark_id:
		"playground": _landmark_playground(root)
		"greenhouse": _landmark_greenhouse(root)
		"water_tower": _landmark_water_tower(root)
		"mill": _landmark_mill(root)
		_:
			push_warning("[Env] bilinmeyen landmark: %s" % landmark_id)
			root.queue_free()


## Rusted swing set, slide and sandpit. The rust colour is what dates it.
func _landmark_playground(root: Node3D) -> void:
	var rust := _flat("rust", Color(0.48, 0.26, 0.16), 0.9, 0.25)
	var pole := _flat("pg_pole", Color(0.42, 0.44, 0.46), 0.7, 0.4)
	var seat := _flat("pg_seat", Color(0.22, 0.24, 0.30), 0.8)
	var slide_mat := _flat("pg_slide", Color(0.62, 0.52, 0.22), 0.55, 0.3)
	var sand := _flat("pg_sand", Color(0.78, 0.70, 0.50), 0.95)

	# Swing set: two A-frames and a top bar, with two hanging seats.
	for side: float in [-1.0, 1.0]:
		for lean: float in [-1.0, 1.0]:
			_cyl(root, 0.09, 0.09, 3.1, rust,
				Vector3(side * 2.6 + lean * 0.5, 1.55, 0.0),
				Vector3(0.0, 0.0, -lean * 0.16))
	_cyl(root, 0.08, 0.08, 5.4, rust, Vector3(0.0, 3.05, 0.0),
		Vector3(0.0, 0.0, PI * 0.5))
	for x: float in [-1.1, 1.1]:
		for chain: float in [-0.22, 0.22]:
			_cyl(root, 0.02, 0.02, 1.9, pole, Vector3(x + chain, 2.1, 0.0))
		_box(root, Vector3(0.7, 0.07, 0.28), seat, Vector3(x, 1.15, 0.0))

	# Slide: ladder, platform, and a sloped chute.
	_box(root, Vector3(1.1, 0.1, 1.1), pole, Vector3(5.4, 1.7, 0.4))
	for side: float in [-1.0, 1.0]:
		_cyl(root, 0.07, 0.07, 1.7, rust, Vector3(5.4 + side * 0.45, 0.85, 0.85))
	for step in 4:
		_box(root, Vector3(0.9, 0.06, 0.14), rust,
			Vector3(5.4, 0.42 + float(step) * 0.42, 0.86))
	_box(root, Vector3(0.9, 0.08, 3.1), slide_mat, Vector3(5.4, 0.95, -1.3),
		Vector3(-0.52, 0.0, 0.0))
	for side: float in [-1.0, 1.0]:
		_box(root, Vector3(0.08, 0.34, 3.1), slide_mat,
			Vector3(5.4 + side * 0.45, 1.08, -1.3), Vector3(-0.52, 0.0, 0.0))

	# Sandpit: a shallow pad with a timber kerb, half taken back by grass.
	_ground_quad(root, Vector2(4.0, 3.0), sand, Vector3(-5.2, 0.03, 0.2))
	for edge: Array in [[-5.2, 1.6, 4.0, 0.24], [-5.2, -1.2, 4.0, 0.24],
			[-7.1, 0.2, 0.24, 2.9], [-3.3, 0.2, 0.24, 2.9]]:
		_box(root, Vector3(edge[2], 0.22, edge[3]), rust,
			Vector3(edge[0], 0.11, edge[1]))
	_ao_blob(root, Vector2(13.0, 7.0), Vector3(0.0, 0.02, 0.2), 0.5)


## Broken-glass greenhouse: a frame with panes, plants inside, one wall open.
func _landmark_greenhouse(root: Node3D) -> void:
	var frame := _flat("gh_frame", Color(0.72, 0.71, 0.66), 0.6, 0.2)
	var glass := _flat("gh_glass", Color(0.72, 0.86, 0.82, 0.34), 0.15, 0.1)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	# Seen from both sides: the far panes have to draw through the near ones.
	glass.cull_mode = BaseMaterial3D.CULL_DISABLED
	var plant := _flat("gh_plant", Color(0.16, 0.42, 0.14), 1.0)
	var pot := _flat("gh_pot", Color(0.46, 0.28, 0.20), 0.9)
	var base := _flat("gh_base", Color(0.50, 0.48, 0.44), 0.9)

	var w := 8.0
	var d := 4.4
	var h := 2.7
	_box(root, Vector3(w + 0.4, 0.22, d + 0.4), base, Vector3(0.0, 0.11, 0.0))
	# Corner posts and eaves.
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			_cyl(root, 0.09, 0.09, h, frame,
				Vector3(sx * w * 0.5, h * 0.5, sz * d * 0.5))
	for sz: float in [-1.0, 1.0]:
		_box(root, Vector3(w, 0.14, 0.14), frame, Vector3(0.0, h, sz * d * 0.5))
	_box(root, Vector3(0.14, 0.14, d), frame, Vector3(0.0, h + 0.55, 0.0))
	# Pitched roof panes.
	for sz: float in [-1.0, 1.0]:
		_box(root, Vector3(w, 0.05, d * 0.62), glass,
			Vector3(0.0, h + 0.28, sz * d * 0.26),
			Vector3(sz * 0.42, 0.0, 0.0))
	# Wall panes: the south wall is missing, and two panes are gone elsewhere.
	var missing := [2, 5]
	for i in 6:
		var px := -w * 0.5 + w * (float(i) + 0.5) / 6.0
		if i in missing:
			continue
		_box(root, Vector3(w / 6.0 - 0.12, h - 0.3, 0.05), glass,
			Vector3(px, h * 0.5, -d * 0.5))
	for sx: float in [-1.0, 1.0]:
		for j in 3:
			var pz := -d * 0.5 + d * (float(j) + 0.5) / 3.0
			_box(root, Vector3(0.05, h - 0.3, d / 3.0 - 0.12), glass,
				Vector3(sx * w * 0.5, h * 0.5, pz))
	# Benches of potted plants inside, visible through the glass.
	for sz: float in [-1.0, 1.0]:
		_box(root, Vector3(w - 1.2, 0.12, 0.9), pot,
			Vector3(0.0, 0.78, sz * d * 0.26))
		for i in 5:
			var px := -w * 0.5 + 1.1 + float(i) * 1.5
			_box(root, Vector3(0.34, 0.3, 0.34), pot,
				Vector3(px, 0.99, sz * d * 0.26))
			_ball(root, 0.36, plant, Vector3(px, 1.42, sz * d * 0.26))
	_ao_blob(root, Vector2(w + 2.0, d + 2.0), Vector3(0.0, 0.02, 0.0), 0.55)


## Water tower: four braced legs, a tank, a conical cap and a ladder.
func _landmark_water_tower(root: Node3D) -> void:
	var steel := _flat("wt_steel", Color(0.50, 0.52, 0.54), 0.6, 0.45)
	var tank := _flat("wt_tank", Color(0.60, 0.42, 0.30), 0.75, 0.2)
	var dark := _flat("wt_dark", Color(0.30, 0.28, 0.26), 0.8)

	var spread := 2.3
	var leg_h := 6.4
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			_cyl(root, 0.14, 0.20, leg_h, steel,
				Vector3(sx * spread, leg_h * 0.5, sz * spread),
				Vector3(sz * 0.05, 0.0, -sx * 0.05))
	# Cross bracing at two heights, both diagonals per face.
	for level: float in [0.32, 0.68]:
		var y := leg_h * level
		for face in 4:
			var angle := TAU * float(face) / 4.0
			var cx := sin(angle) * spread
			var cz := cos(angle) * spread
			for tilt: float in [-1.0, 1.0]:
				_box(root, Vector3(spread * 2.05, 0.07, 0.07), steel,
					Vector3(cx, y, cz),
					Vector3(0.0, angle, tilt * 0.62))
	_box(root, Vector3(spread * 2.4, 0.16, spread * 2.4), dark,
		Vector3(0.0, leg_h, 0.0))
	_cyl(root, 2.5, 2.5, 3.2, tank, Vector3(0.0, leg_h + 1.7, 0.0))
	for band: float in [0.6, 2.4]:
		_cyl(root, 2.56, 2.56, 0.14, dark, Vector3(0.0, leg_h + band, 0.0))
	# Conical cap and a vent pipe.
	var cap := CylinderMesh.new()
	cap.top_radius = 0.1
	cap.bottom_radius = 2.6
	cap.height = 1.0
	cap.radial_segments = 16
	_mesh(root, cap, dark, Vector3(0.0, leg_h + 3.8, 0.0))
	_cyl(root, 0.12, 0.12, 0.9, steel, Vector3(0.0, leg_h + 4.6, 0.0))
	# Ladder up one leg.
	for rung in 14:
		_box(root, Vector3(0.5, 0.05, 0.05), steel,
			Vector3(spread + 0.28, 0.5 + float(rung) * 0.42, spread + 0.28))
	_ao_blob(root, Vector2(8.0, 8.0), Vector3(0.0, 0.02, 0.0), 0.6)


## Timber mill: a barn with a shingled gable, a sack hoist and a broken wheel.
func _landmark_mill(root: Node3D) -> void:
	var plank := _tex_mat("mill_plank", "wood_albedo", Color(0.44, 0.32, 0.22), 0.9)
	var shingle := _tex_mat("mill_roof", "roof_shingles_albedo",
		Color(0.32, 0.28, 0.26), 0.9, Vector3(2.0, 2.0, 1.0))
	var dark := _flat("mill_dark", Color(0.10, 0.09, 0.09), 0.9)
	var iron := _flat("mill_iron", Color(0.34, 0.32, 0.30), 0.7, 0.4)

	var body := Vector3(9.0, 4.6, 5.2)
	_box(root, body, plank, Vector3(0.0, body.y * 0.5, 0.0))
	# Gable roof from two slabs, plus the ridge.
	for sz: float in [-1.0, 1.0]:
		_box(root, Vector3(body.x + 0.7, 0.24, body.z * 0.66), shingle,
			Vector3(0.0, body.y + 0.72, sz * body.z * 0.28),
			Vector3(sz * 0.46, 0.0, 0.0))
	_box(root, Vector3(body.x + 0.8, 0.2, 0.4), shingle,
		Vector3(0.0, body.y + 1.42, 0.0))
	# Big sliding door, dark inside.
	_box(root, Vector3(3.0, 3.2, 0.16), dark, Vector3(-1.0, 1.6, body.z * 0.5))
	_box(root, Vector3(0.26, 3.4, 0.22), plank, Vector3(0.7, 1.7, body.z * 0.5))
	_box(root, Vector3(3.4, 0.18, 0.22), iron,
		Vector3(-1.0, 3.35, body.z * 0.5 + 0.04))
	# Loft opening and the sack hoist beam sticking out over it.
	_box(root, Vector3(1.4, 1.3, 0.16), dark,
		Vector3(2.6, body.y - 0.4, body.z * 0.5))
	_box(root, Vector3(0.3, 0.3, 2.2), plank,
		Vector3(2.6, body.y + 0.5, body.z * 0.5 + 0.9))
	_cyl(root, 0.03, 0.03, 1.5, iron,
		Vector3(2.6, body.y - 0.25, body.z * 0.5 + 1.85))
	_box(root, Vector3(0.5, 0.5, 0.4), plank,
		Vector3(2.6, body.y - 1.1, body.z * 0.5 + 1.85))
	# A broken mill wheel leaning on the west wall.
	var wheel := TorusMesh.new()
	wheel.inner_radius = 1.35
	wheel.outer_radius = 1.7
	wheel.rings = 20
	wheel.ring_segments = 8
	_mesh(root, wheel, plank, Vector3(-body.x * 0.5 - 0.6, 1.7, 1.2),
		Vector3(PI * 0.5, 0.0, 0.28))
	for spoke in 6:
		_box(root, Vector3(0.16, 0.16, 3.0), plank,
			Vector3(-body.x * 0.5 - 0.6, 1.7, 1.2),
			Vector3(0.28, 0.0, TAU * float(spoke) / 6.0))
	_ao_blob(root, Vector2(12.0, 8.0), Vector3(0.0, 0.02, 0.0), 0.6)


## B8 only: turn the yard into a cellar garden without a second light rig. The
## existing sun becomes a steep, dim, cool shaft, ambient drops, and a ring of
## dark quads closes the edges so the lawn reads as lit from a hole above.
func _apply_cellar_mood() -> void:
	var sun := get_node_or_null("../Sun") as DirectionalLight3D
	if sun != null:
		sun.rotation = GameConfig.CELLAR_SUN_EULER
		sun.light_color = GameConfig.CELLAR_SUN_COLOR
		sun.light_energy = GameConfig.CELLAR_SUN_ENERGY
	var world := get_node_or_null("../WorldEnvironment") as WorldEnvironment
	if world != null and world.environment != null:
		# Duplicated: the Environment is a shared sub-resource, and editing it in
		# place would leak the cellar mood into every other chapter this session.
		var env: Environment = world.environment.duplicate()
		env.ambient_light_color = GameConfig.CELLAR_AMBIENT_COLOR
		env.ambient_light_energy = GameConfig.CELLAR_AMBIENT_ENERGY
		world.environment = env

	var dark := _flat("cellar_dark", Color(0.01, 0.012, 0.01), 1.0)
	dark.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dark.albedo_color.a = GameConfig.CELLAR_VIGNETTE_ALPHA
	dark.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var margin := GameConfig.CELLAR_VIGNETTE_MARGIN
	var hx := GameConfig.HALF_X
	var hz := GameConfig.HALF_Z
	# Four slabs just above the ground, ringing the playable area.
	var ring := Node3D.new()
	ring.name = "CellarVignette"
	add_child(ring)
	for band: Array in [
			[Vector2(hx * 2.0 + margin * 2.0, margin), Vector3(0.0, 0.0, -hz - margin * 0.5)],
			[Vector2(hx * 2.0 + margin * 2.0, margin), Vector3(0.0, 0.0, hz + margin * 0.5)],
			[Vector2(margin, hz * 2.0), Vector3(-hx - margin * 0.5, 0.0, 0.0)],
			[Vector2(margin, hz * 2.0), Vector3(hx + margin * 0.5, 0.0, 0.0)]]:
		var quad := _ground_quad(ring, band[0], dark,
			(band[1] as Vector3) + Vector3(0.0, 0.06, 0.0))
		quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
