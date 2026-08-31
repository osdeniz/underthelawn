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
	# A harvest field stands in farmland, not on a street. The neighbours, the
	# road and the parked cars belong to a suburb, and around a wheat field they
	# read as somebody's cul-de-sac with a crop dropped into it. Skipping them
	# is also the cheapest thing in this file: they are most of the yard's mesh
	# count and none of them are load-bearing here.
	var farmland := _variant != null and _variant.is_harvest()
	if farmland:
		_build_open_country()
	else:
		_build_road()
		_build_cars()
		_build_neighbors()
	_build_smalls()
	_build_clouds()
	# G13.1: distant hills and rooftops in EVERY yard, not just the hub's
	# diorama. Every chapter used to end at a fog wall with nothing behind it.
	# The country between the fence and the hills is the horizon's job now, and
	# it takes the palette's colour so a wheat yard is not ringed in green.
	Horizon.build(self, GameConfig.HORIZON_RADIUS, _rng.randi(), true,
		_country_tint())
	# NO crop border around a harvest. Seven rows of corn and sunflowers on
	# three sides came to about seven hundred plants, each its own tree of
	# nineteen meshes: 10,034 mesh nodes and 8,620 draw calls a frame against
	# 807 and 484 for an ordinary chapter, which is what made the level stutter.
	#
	# The land around the three harvest fields is open now. That is also the
	# truer picture — this is farmland, not a walled garden — and the play area
	# stays legible without it, because _build_fence already rings the mowable
	# ground on three sides and the horizon fills everything past it.
	if GameConfig.SKY_HIGH_CLOUDS_ENABLED:
		_build_high_clouds()
	# No driveways on a farm field either: they are the aprons in front of the
	# neighbours' garages, and with the houses gone they were two pale slabs
	# lying in the middle of ploughed land.
	if not farmland:
		_build_driveways()
	_build_traces()
	# G9.4: random bird chirps are gone from gameplay along with the ambient
	# loop; birdsong lives on the opening cards only.
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
		if _bird == null:
			pass
		elif _bird_timer <= 0.0:
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
	# G9.2: the has_porch flag existed since G9 but nothing read it, so every
	# house variant grew the same porch. Now the whole block is gated.
	var porch_z := wall_z + 0.8   # platform centre, house-local
	if has_porch:
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
	else:
		# A bare doorstep where the porch would be.
		_box(house, Vector3(1.6, 0.16, 0.9), wood, Vector3(0.0, 0.08, wall_z + 0.55))

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


## What sits beyond the fence of a harvest field.
##
## Open land, but not a flat brown plane — bare ground out to the horizon reads
## as missing geometry rather than as farmland, which is exactly how the first
## attempt looked. What sells it is that real farmland is WORKED: ploughed in
## strips, with a track running through it, and the strips lie at an angle to
## whatever you happen to be standing in.
##
## Everything here is a flat quad lying on the dirt: about a dozen draw calls
## for the whole countryside, which matters, because the crop border this
## replaces cost eight thousand.
##
## Height is the thing to get right. The yard's dirt apron sits at y = -0.04
## and the lawn is drawn above that, so these go at -0.035: over the dirt,
## under the grass. The first version used -0.06 and the strips were buried
## under the apron — only the two corners that reached past its edge were
## visible, as a pair of pale slabs sitting in a brown field.
func _build_open_country() -> void:
	var country := Node3D.new()
	country.name = "OpenCountry"
	add_child(country)

	var rng := RandomNumberGenerator.new()
	rng.seed = (_variant.decor_seed if _variant != null else 4242) + 5150
	# Tones taken from the DIRT, not from the grass: these are furrows in the
	# same soil the apron is made of, and a grass-derived tint read as grey
	# rectangles dropped on brown.
	var soil := Color(0.38, 0.28, 0.18)
	# Blended toward the crop the level grows. A field seen from mower height is
	# standing crop nearly all the way out; leaving the distance bare soil made
	# the land stop at the last row of geometry and become dirt, which is the
	# one thing it must not do when the crop is supposed to reach the horizon.
	var crop_variants: Array = GameConfig.clump_variants()
	var crop_tone: Color = soil
	if not crop_variants.is_empty():
		var top: Color = (crop_variants[0] as Dictionary)["tip"]
		var root: Color = (crop_variants[0] as Dictionary)["base"]
		crop_tone = soil.lerp(root.lerp(top, 0.55), 0.72)
	var ploughed := _flat("country_dark", crop_tone.darkened(0.20), 1.0)
	var stubble := _flat("country_light", crop_tone.lightened(0.12), 1.0)

	# Strips run the depth of the apron, angled a few degrees so they do not
	# line up with the fence and give the trick away.
	var depth := 88.0
	var lean := rng.randf_range(0.09, 0.16)
	var x := -52.0
	var band := 0
	while x < 52.0:
		var width := rng.randf_range(3.4, 7.5)
		var strip := _ground_quad(country, Vector2(width, depth),
			ploughed if band % 2 == 0 else stubble,
			Vector3(x + width * 0.5, -0.035, 6.0))
		strip.rotation.y = lean
		x += width
		band += 1

	# One track across the land: a farm has a way in, and a single lighter line
	# breaks the corduroy so it stops reading as a rug.
	var track := _ground_quad(country, Vector2(96.0, 2.6),
		stubble, Vector3(0.0, -0.03, 6.0 + rng.randf_range(-16.0, -26.0)))
	track.rotation.y = rng.randf_range(-0.05, 0.05)

	_build_neighbour_crop(country, rng)


## The next field along, standing uncut, all the way out.
##
## The ring outside the fence grows the SAME plant the yard does — wheat around
## wheat, corn around corn — from TuftField.cluster_mesh, the very mesh the
## mowable field is built from. Not an impostor, not a cheaper stand-in: the
## same clump, so there is no line in the world where the crop changes into
## something that only resembles it.
##
## What makes that affordable to the horizon is DENSITY, not detail. Close to
## the fence the rows are packed; by sixty metres out perhaps one candidate in
## twenty is planted, and each of those is nearly three times the size. A clump
## that far away is a few pixels tall, so what it costs is real and what it
## shows is a silhouette — thinning is invisible there and it is the whole
## saving.
##
## Two things keep the cost off the CPU entirely:
##   - MultiMesh: the whole field is one draw call per palette variant, however
##     many thousand clumps are in it.
##   - NO WIND. The mowable crop sways; this does not. Same shader with its
##     amplitude at zero, so it is static geometry with no per-frame work.
## How far the neighbour's field reaches, and how finely it is sampled. These
## two are the dial: REACH is how much world there is, STEP is how much of it
## is paid for. Halving STEP roughly quadruples the clump count, so if a device
## says no, raise STEP before shortening REACH — the horizon is the point.
const CROP_REACH := 62.0
const CROP_STEP := 1.35
## How deep the solid band past the fence is, in metres.
const CROP_SOLID := 5.0


func _build_neighbour_crop(parent: Node3D, rng: RandomNumberGenerator) -> void:
	var variants: Array = GameConfig.clump_variants()
	if variants.is_empty():
		return
	var still := ShaderMaterial.new()
	still.shader = load("res://shaders/grass_clump.gdshader")
	still.set_shader_parameter("wind_amplitude", 0.0)
	still.set_shader_parameter("wind_speed", 0.0)

	# One MultiMesh per palette variant, and no finer than that.
	#
	# Splitting the ring into quadrants so the engine could frustum-cull three
	# of them was worth trying and did not pay: the triangle count did not move
	# — from a camera this low the far rows of every quadrant are in frame —
	# and it cost twenty-one extra draw calls. Measured, reverted.
	var meshes: Array[Mesh] = []
	for v in variants.size():
		var mesh_rng := RandomNumberGenerator.new()
		mesh_rng.seed = 4400 + v * 7919
		meshes.append(TuftField.cluster_mesh(mesh_rng, v))
	var spots: Array[Array] = []
	for v in variants.size():
		spots.append([])

	var keep_out_x := GameConfig.HALF_X + 1.6
	var keep_out_z := GameConfig.HALF_Z + 1.6
	var ix := 0
	var x := -(GameConfig.HALF_X + CROP_REACH)
	while x <= GameConfig.HALF_X + CROP_REACH:
		var iz := 0
		var z := -(GameConfig.HALF_Z + CROP_REACH)
		while z <= GameConfig.HALF_Z + CROP_REACH:
			if absf(x) > keep_out_x or absf(z) > keep_out_z:
				var out_by := maxf(absf(x) - keep_out_x, absf(z) - keep_out_z)
				# The first few metres are SOLID, whatever the step is.
				#
				# Letting the falloff start at the fence thinned the one part of
				# the field the player actually looks at: at a coarse step there
				# was bare ground just past the rail, and "the crop continues"
				# broke exactly where it is read. Everything past this band is
				# distance, and distance is where the saving is taken.
				var keep := 1.0
				if out_by > CROP_SOLID:
					# Past the solid band the grid itself is read at half
					# resolution — a checkerboard — before the falloff is even
					# applied. Doubling the step out here is free in a way that
					# doubling it everywhere is not, because the near rows keep
					# their own spacing.
					if (ix + iz) % 2 == 1:
						z += CROP_STEP
						iz += 1
						continue
					var far := clampf((out_by - CROP_SOLID)
						/ (CROP_REACH - CROP_SOLID), 0.0, 1.0)
					keep = pow(1.0 - far, 2.4) * 0.95 + 0.03
				if rng.randf() > keep:
					z += CROP_STEP
					iz += 1
					continue
				# Bigger further out: fewer clumps each covering more ground,
				# which is what lets the thinning go unnoticed.
				var grow := 1.3 + clampf(out_by / CROP_REACH, 0.0, 1.0) * 2.4
				var at := Vector3(x + rng.randf_range(-0.4, 0.4), 0.0,
					z + rng.randf_range(-0.4, 0.4))
				var basis := Basis(Vector3.UP, rng.randf() * TAU)
				basis = basis.scaled(Vector3.ONE * grow * rng.randf_range(0.9, 1.15))
				(spots[rng.randi() % variants.size()] as Array).append(
					Transform3D(basis, at))
			z += CROP_STEP
			iz += 1
		x += CROP_STEP
		ix += 1

	var planted := 0
	for v in variants.size():
		if (spots[v] as Array).is_empty() or meshes[v] == null:
			continue
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = meshes[v]
		mm.instance_count = (spots[v] as Array).size()
		for i in (spots[v] as Array).size():
			mm.set_instance_transform(i, (spots[v] as Array)[i] as Transform3D)
		planted += mm.instance_count
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "NeighbourCrop%d" % v
		mmi.multimesh = mm
		mmi.material_override = still
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(mmi)
	if GameConfig.PERF_LOG:
		print("[tarla] komsu ekin: %d kume, %d cizim" % [planted, variants.size()])


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

## G12.5: houses on BOTH sides and across, all of them derelict. A lawn floating
## in empty dirt read as a test level; a street of boarded, faded houses reads as
## a neighbourhood that emptied out and never refilled. None are enterable —
## they are silhouette and mood, built from the same primitives as everything
## else, and seeded so a yard looks the same on every visit.
func _build_neighbors() -> void:
	var shingles := _tex_mat("shingles", "roof_shingles_albedo",
		Color(0.42, 0.26, 0.20), 0.9)
	var trim := _flat("trim", Color(0.93, 0.92, 0.88), 0.82)
	var dark := _flat("interior", Color(0.05, 0.05, 0.07), 0.9)
	var plank := _tex_mat("wood", "wood_albedo", Color(0.55, 0.42, 0.27), 0.85)

	# Across the road.
	for i in GameConfig.NEIGHBOR_X.size():
		_derelict_house(Vector3(GameConfig.NEIGHBOR_X[i], 0.0,
			GameConfig.neighbor_z()), 0.0, shingles, trim, dark, plank)

	# Both side streets, running the depth of the yard. They face the lawn, so
	# the player always sees a front elevation rather than a blank flank.
	var span := GameConfig.HALF_Z * 2.0
	var count := maxi(2, int(span / GameConfig.SIDE_HOUSE_SPACING))
	for side: float in [-1.0, 1.0]:
		var x := side * (GameConfig.fence_side_x() + GameConfig.SIDE_HOUSE_MARGIN)
		for i in count:
			var z := -GameConfig.HALF_Z + (float(i) + 0.5) * (span / float(count))
			_derelict_house(Vector3(x, 0.0, z + _rng.randf_range(-0.8, 0.8)),
				-side * PI * 0.5, shingles, trim, dark, plank)
		# A yard strip between our fence and theirs: from directly above this is
		# what actually reads as "somebody's garden", more than the house does.
		_side_yard(side, span)


## The neighbour's plot: dry grass, a low fence line, and the odd shed. Seen
## from overhead this ground-level dressing does more for the sense of a street
## than the buildings behind it.
func _side_yard(side: float, span: float) -> void:
	var dry := _flat("side_dry", Color(0.38, 0.36, 0.24), 1.0)
	var post := _tex_mat("wood", "wood_albedo", Color(0.55, 0.42, 0.27), 0.85)
	var shed := _flat("side_shed", Color(0.44, 0.40, 0.34), 0.95)
	var x := side * (GameConfig.fence_side_x() + 1.4)
	_ground_quad(self, Vector2(2.4, span), dry, Vector3(x, -0.015, 0.0))
	# Their own fence, a sagging line of posts facing ours.
	var count := int(span / 1.6)
	for i in count:
		var z := -span * 0.5 + (float(i) + 0.5) * (span / float(count))
		_box(self, Vector3(0.09, _rng.randf_range(0.7, 1.0), 0.09), post,
			Vector3(side * (GameConfig.fence_side_x() + 2.5), 0.45, z),
			Vector3(0.0, 0.0, _rng.randf_range(-0.09, 0.09)))
	# One or two sheds per side, low enough to read as objects from above.
	for _s in _rng.randi_range(1, 2):
		var sz := _rng.randf_range(-span * 0.4, span * 0.4)
		_box(self, Vector3(2.0, 1.5, 1.6), shed, Vector3(x, 0.75, sz))
		_box(self, Vector3(2.3, 0.16, 1.9), post, Vector3(x, 1.55, sz))
		_ao_blob(self, Vector2(2.8, 2.4), Vector3(x, 0.02, sz), 0.5)


## One abandoned house: body, roof, dark windows, and — often — boards nailed
## over them. Colour and damage are drawn from the chapter's seeded rng.
func _derelict_house(at: Vector3, yaw: float, shingles: Material,
		trim: Material, dark: Material, plank: Material) -> void:
	var h := Node3D.new()
	h.position = at
	h.rotation.y = yaw
	add_child(h)

	var body_color: Color = GameConfig.DERELICT_BODIES[
		_rng.randi_range(0, GameConfig.DERELICT_BODIES.size() - 1)]
	var roof_color: Color = GameConfig.DERELICT_ROOFS[
		_rng.randi_range(0, GameConfig.DERELICT_ROOFS.size() - 1)]
	var body_mat := _flat("nb_%d" % _rng.randi(), body_color, 0.95)
	var roof_mat := _flat("nr_%d" % _rng.randi(), roof_color, 0.95)

	var width := _rng.randf_range(6.8, 8.4)
	var height := _rng.randf_range(2.5, 3.2)
	_box(h, Vector3(width, height, 4.0), body_mat, Vector3(0.0, height * 0.5, 0.0))
	_pyramid(h, Vector2(width + 0.8, 4.8), _rng.randf_range(1.5, 2.1), roof_mat,
		Vector3(0.0, height, 0.0))
	# Doorway, always dark: nobody has opened it in years.
	_box(h, Vector3(0.9, 1.9, 0.06), dark, Vector3(0.0, 0.95, -2.01))
	for wx: float in [-2.2, 2.2]:
		_box(h, Vector3(1.1, 0.9, 0.06), trim, Vector3(wx, 1.5, -2.01))
		_box(h, Vector3(0.95, 0.75, 0.04), dark, Vector3(wx, 1.5, -2.04))
		# Two crossed boards over most windows — the outbreak's own signature.
		if _rng.randf() < 0.65:
			for tilt: float in [0.42, -0.38]:
				_box(h, Vector3(1.35, 0.16, 0.05), plank,
					Vector3(wx, 1.5, -2.06), Vector3(0.0, 0.0, tilt))
	_box(h, Vector3(2.2, 0.18, 0.9), trim, Vector3(0.0, 0.09, -2.5))
	# A missing roof corner on some of them, so the row is not a stamp.
	if _rng.randf() < 0.35:
		_box(h, Vector3(1.6, 0.5, 1.6), dark,
			Vector3(width * 0.32, height + 0.35, 0.9))
	_ao_blob(self, Vector2(width + 2.0, 6.0), at + Vector3(0.0, 0.02, 0.0), 0.5)


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

	# On a ring, not in a strip: the four clouds used to sit north of the house
	# between z -34 and -6, so every other direction was empty sky (G14.2).
	for i in GameConfig.CLOUD_RING_COUNT:
		var size := _rng.randf_range(GameConfig.CLOUD_SIZE_MIN, GameConfig.CLOUD_SIZE_MAX)
		var quad := QuadMesh.new()
		quad.size = Vector2(size, size * 0.5)
		quad.material = mat
		var mi := MeshInstance3D.new()
		mi.mesh = quad
		var a := TAU * (float(i) + _rng.randf_range(-0.3, 0.3)) \
			/ float(GameConfig.CLOUD_RING_COUNT)
		var ring := GameConfig.CLOUD_RING_RADIUS * _rng.randf_range(0.7, 1.25)
		var base_x := cos(a) * ring
		mi.position = Vector3(base_x,
			_rng.randf_range(GameConfig.CLOUD_Y_MIN, GameConfig.CLOUD_Y_MAX),
			sin(a) * ring)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
		_clouds.append({ "node": mi, "base_x": base_x, "phase": _rng.randf() * TAU })


## Duller and greyer than the lawn: the country is not a second garden.
func _country_tint() -> Color:
	var pal := GameConfig.grass_palette()
	var far: Color = (pal["ground_mowed"] as Array)[0]
	return far.lerp(GameConfig.MEADOW_GREY, GameConfig.MEADOW_FADE)


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
		"barn": _landmark_barn(root)
		"antenna_mast": _landmark_antenna_mast(root)
		"orchard": _landmark_orchard(root)
		"crossing": _landmark_crossing(root)
		"roadside_camp": _landmark_roadside_camp(root)
		"listening_post": _landmark_listening_post(root)
		"old_clinic": _landmark_old_clinic(root)
		"meeting_stone": _landmark_meeting_stone(root)
		"signal_garden": _landmark_signal_garden(root)
		_:
			push_warning("[Env] bilinmeyen landmark: %s" % landmark_id)
			root.queue_free()


## The farm's barn: the harvest level's anchor. Red boards, a gambrel roof, a
## white-framed door, and one hay bale per harvest already brought in, up to the
## cap — so the field visibly repays the work (G13.6).
func _landmark_barn(root: Node3D) -> void:
	var board := _flat("barn_board", Color(0.52, 0.17, 0.14), 0.95)
	var trim := _flat("barn_trim", Color(0.88, 0.86, 0.80), 0.9)
	var roof := _flat("barn_roof", Color(0.30, 0.28, 0.27), 0.9)
	var hay := _flat("barn_hay", Color(0.82, 0.70, 0.34), 1.0)
	var stone := _flat("barn_stone", Color(0.52, 0.50, 0.46), 0.95)

	var w := 9.0
	var d := 6.0
	var h := 4.2
	_box(root, Vector3(w + 0.5, 0.3, d + 0.5), stone, Vector3(0.0, 0.15, 0.0))
	_box(root, Vector3(w, h, d), board, Vector3(0.0, h * 0.5 + 0.3, 0.0))
	# Gambrel: a shallow upper pitch over a steep lower one, both sides.
	for sx: float in [-1.0, 1.0]:
		_box(root, Vector3(w * 0.30, 0.22, d + 0.5), roof,
			Vector3(sx * w * 0.22, h + 1.35, 0.0), Vector3(0.0, 0.0, sx * 0.52))
		_box(root, Vector3(w * 0.34, 0.22, d + 0.5), roof,
			Vector3(sx * w * 0.42, h + 0.62, 0.0), Vector3(0.0, 0.0, sx * 1.02))
	_box(root, Vector3(0.3, 0.3, d + 0.7), roof, Vector3(0.0, h + 1.72, 0.0))
	# The big south door, framed in white, with its cross-brace boards.
	_box(root, Vector3(3.4, 3.1, 0.12), trim, Vector3(0.0, 1.85, -d * 0.5 - 0.06))
	_box(root, Vector3(3.0, 2.8, 0.10), board, Vector3(0.0, 1.80, -d * 0.5 - 0.13))
	for sx2: float in [-1.0, 1.0]:
		_box(root, Vector3(3.2, 0.16, 0.06), trim,
			Vector3(0.0, 1.80, -d * 0.5 - 0.19), Vector3(0.0, 0.0, sx2 * 0.72))
	# Hay loft opening up in the gable, with straw spilling from it.
	_box(root, Vector3(1.3, 1.2, 0.12), trim,
		Vector3(0.0, h - 0.3, -d * 0.5 - 0.06))
	_box(root, Vector3(1.0, 0.9, 0.10), hay, Vector3(0.0, h - 0.35, -d * 0.5 - 0.13))

	var bales := HarvestLog.bales()
	for i in bales:
		var col := i % 2
		var row := i / 2
		_cyl(root, 0.62, 0.62, 1.1, hay,
			Vector3(w * 0.5 + 1.6 + float(col) * 1.5, 0.62 + float(row) * 1.2,
				d * 0.20),
			Vector3(0.0, 0.0, PI * 0.5))
	_ao_blob(root, Vector2(w + 2.4, d + 2.4),
		Vector3(0.0, 0.02, 0.0), 0.6)


## Case 02 opens under this: a lattice mast with a shed at its foot, guy wires
## running out to their anchors, and one dish still pointed east.
##
## The dish is the whole landmark. Everything else has weathered into the same
## grey, but somebody has kept that one thing aimed — and it aims the way the
## chapter is about to send the player (G13).
func _landmark_antenna_mast(root: Node3D) -> void:
	var steel := _flat("mast_steel", Color(0.46, 0.47, 0.49), 0.65, 0.35)
	var rust := _flat("mast_rust", Color(0.44, 0.26, 0.18), 0.9, 0.1)
	var board := _flat("mast_board", Color(0.40, 0.38, 0.34), 0.95)
	var roof := _flat("mast_roof", Color(0.26, 0.26, 0.27), 0.9)
	var dish := _flat("mast_dish", Color(0.74, 0.73, 0.68), 0.55, 0.2)
	var wire := _flat("mast_wire", Color(0.32, 0.32, 0.33), 0.8, 0.5)

	var height := 9.4
	# Four legs drawing in towards the top, cross-braced: a lattice reads as a
	# lattice from the diagonals, not from the uprights.
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			_cyl(root, 0.055, 0.085, height, steel,
				Vector3(sx * 0.52, height * 0.5, sz * 0.52),
				Vector3(sz * 0.035, 0.0, -sx * 0.035))
	# Rungs all the way round plus one diagonal per face per level. A lattice
	# reads as a lattice from the diagonals; with only the uprights and a rung
	# on one face it reads as a ladder, which is what the first pass drew.
	for level in 7:
		var y := 0.8 + float(level) * 1.28
		var span := lerpf(1.10, 0.70, float(level) / 6.0)
		var lean := 1.0 if level % 2 == 0 else -1.0
		for face in 4:
			var a := TAU * float(face) / 4.0
			var mid := Vector3(cos(a), 0.0, sin(a)) * span * 0.5
			_cyl(root, 0.026, 0.026, span, steel, mid + Vector3(0.0, y, 0.0),
				Vector3(0.0, -a, PI * 0.5))
			var diag := sqrt(span * span + 1.28 * 1.28)
			_cyl(root, 0.021, 0.021, diag, steel,
				mid + Vector3(0.0, y + 0.64, 0.0),
				Vector3(0.0, -a, lean * atan2(span, 1.28)))

	# Guy wires out to three ground anchors. Thick enough to read at the
	# camera's distance: a hairline cylinder came out looking like a scratch on
	# the lens rather than a cable.
	for i in 3:
		var angle := TAU * float(i) / 3.0 + 0.4
		var reach := 4.2
		var top := Vector3(0.0, height * 0.74, 0.0)
		var anchor := Vector3(cos(angle) * reach, 0.25, sin(angle) * reach)
		var mid := (anchor + top) * 0.5
		var line := _cyl(root, 0.032, 0.032, anchor.distance_to(top), wire, mid,
			Vector3.ZERO, 6)
		line.look_at_from_position(mid, anchor, Vector3.UP)
		line.rotate_object_local(Vector3.RIGHT, PI * 0.5)
		_box(root, Vector3(0.30, 0.42, 0.30), rust,
			anchor + Vector3(0.0, -0.04, 0.0))

	# The dish, still aimed east, and its little counterweight arm.
	var arm := Vector3(0.0, height * 0.86, 0.0)
	_cyl(root, 0.05, 0.05, 1.5, steel, arm + Vector3(0.62, 0.0, 0.0),
		Vector3(0.0, 0.0, PI * 0.5))
	_cyl(root, 0.92, 0.92, 0.10, dish, arm + Vector3(1.34, 0.0, 0.0),
		Vector3(0.0, 0.0, PI * 0.5))
	_cyl(root, 0.06, 0.06, 0.46, rust, arm + Vector3(1.62, 0.0, 0.0),
		Vector3(0.0, 0.0, PI * 0.5))

	# The shed at its foot: where the receiver and the log were found.
	var shed := Node3D.new()
	shed.position = Vector3(2.9, 0.0, 1.1)
	shed.rotation.y = -0.24
	root.add_child(shed)
	_box(shed, Vector3(2.6, 2.1, 2.2), board, Vector3(0.0, 1.05, 0.0))
	_box(shed, Vector3(2.9, 0.14, 2.5), roof, Vector3(0.0, 2.16, 0.0),
		Vector3(0.10, 0.0, 0.0))
	_box(shed, Vector3(0.9, 1.7, 0.08), rust, Vector3(-0.5, 0.85, -1.12))
	_box(shed, Vector3(0.5, 0.5, 0.06), steel, Vector3(0.7, 1.45, -1.12))
	_ao_blob(shed, Vector2(3.4, 3.0), Vector3(0.0, 0.02, 0.0), 0.55)
	_ao_blob(root, Vector2(3.2, 3.2), Vector3(0.0, 0.02, 0.0), 0.5)


## Four rows of old apple trees, and a low dry-stone wall along the back.
##
## The rows are the evidence: they are EVEN. Trees planted by a person who
## expected to come back and pick them, standing in the country that stopped
## coming back for anything (G13).
func _landmark_orchard(root: Node3D) -> void:
	var bark := _flat("orch_bark", Color(0.32, 0.26, 0.20), 0.95)
	var leaf := _flat("orch_leaf", Color(0.24, 0.42, 0.20), 0.9)
	var fruit := _flat("orch_fruit", Color(0.58, 0.15, 0.14), 0.5)
	var stone := _flat("orch_stone", Color(0.55, 0.53, 0.48), 0.95)
	var crate := _flat("orch_crate", Color(0.68, 0.58, 0.42), 0.9)

	var rng := RandomNumberGenerator.new()
	rng.seed = 111101
	for row in 4:
		for col in 5:
			var tree := Node3D.new()
			tree.position = Vector3((float(col) - 2.0) * 2.9 + rng.randf_range(-0.12, 0.12),
				0.0, (float(row) - 1.5) * 2.5 + rng.randf_range(-0.10, 0.10))
			root.add_child(tree)
			var h := rng.randf_range(2.1, 2.7)
			_cyl(tree, 0.13, 0.20, h, bark, Vector3(0.0, h * 0.5, 0.0))
			# Three crowns rather than one ball: an apple tree is wide and open.
			for i in 3:
				var a := TAU * float(i) / 3.0 + rng.randf_range(0.0, 1.0)
				var r := rng.randf_range(0.62, 0.86)
				_ball(tree, r, leaf,
					Vector3(cos(a) * 0.46, h + rng.randf_range(-0.10, 0.22),
						sin(a) * 0.46), Vector3(1.0, 0.78, 1.0))
			# A few apples still up, because nobody stripped these trees bare.
			for i in 3:
				var a2 := rng.randf_range(0.0, TAU)
				_ball(tree, 0.075, fruit,
					Vector3(cos(a2) * rng.randf_range(0.45, 0.85),
						h + rng.randf_range(-0.25, 0.25),
						sin(a2) * rng.randf_range(0.45, 0.85)))
			_ao_blob(tree, Vector2(1.9, 1.9), Vector3(0.0, 0.02, 0.0), 0.5)

	# The dry-stone wall the crate lid was leaning against.
	for i in 16:
		var x := (float(i) - 7.5) * 0.86
		var y := 0.22 + (0.0 if i % 3 else 0.14)
		_box(root, Vector3(0.84, 0.44 + (0.18 if i % 3 == 0 else 0.0), 0.46),
			stone, Vector3(x, y, 5.4), Vector3(0.0, rng.randf_range(-0.1, 0.1), 0.0))
	_box(root, Vector3(0.62, 0.42, 0.46), crate, Vector3(2.1, 0.21, 4.85),
		Vector3(0.0, 0.34, 0.0))
	_box(root, Vector3(0.66, 0.03, 0.50), crate, Vector3(1.4, 0.02, 4.9),
		Vector3(0.0, 0.12, 0.0))


## The far bank: two anchor posts, a rope walkway and the planks somebody has
## been maintaining. It sits at the FAR edge because the chapter is about
## getting to it — the reeds are between the player and this (G13).
func _landmark_crossing(root: Node3D) -> void:
	var post := _flat("cr_post", Color(0.35, 0.28, 0.20), 0.95)
	var rope := _flat("cr_rope", Color(0.72, 0.64, 0.44), 0.9)
	var plank := _flat("cr_plank", Color(0.48, 0.42, 0.33), 0.95)
	var water := _flat("cr_water", Color(0.24, 0.36, 0.38), 0.35, 0.1)
	var stone := _flat("cr_stone", Color(0.52, 0.51, 0.47), 0.95)

	# The water itself, a flat band running across behind the bank.
	_box(root, Vector3(30.0, 0.06, 5.2), water, Vector3(0.0, 0.03, 3.2))
	for i in 14:
		_box(root, Vector3(0.9, 0.34, 0.5), stone,
			Vector3((float(i) - 6.5) * 1.05, 0.15, 0.5),
			Vector3(0.0, float(i) * 0.7, 0.0))

	# Two A-frames carrying the ropes, and the deck between them.
	for sx: float in [-1.0, 1.0]:
		for lean: float in [-1.0, 1.0]:
			_cyl(root, 0.08, 0.10, 2.9, post,
				Vector3(sx * 1.5 + lean * 0.34, 1.45, 1.3),
				Vector3(0.0, 0.0, -lean * 0.14))
		_cyl(root, 0.05, 0.05, 3.4, rope,
			Vector3(sx * 1.5, 2.55, 3.0), Vector3(PI * 0.5, 0.0, 0.0))
	for i in 9:
		_box(root, Vector3(2.9, 0.07, 0.30), plank,
			Vector3(0.0, 0.92 - float(i) * 0.012, 1.5 + float(i) * 0.42))
	# The knot the evidence is about: rope turned twice round the near post.
	for i in 2:
		_cyl(root, 0.115, 0.115, 0.09, rope,
			Vector3(-1.5, 2.05 + float(i) * 0.10, 1.3), Vector3(0.0, 0.0, 0.0), 10)
	_ao_blob(root, Vector2(5.0, 3.0), Vector3(0.0, 0.02, 1.6), 0.5)


## A place people stopped, twice. The lower camp is tidy — its stone ring and
## its guy-line stakes are still square. The upper one was left in a hurry: the
## caravan is on its side and a tent is a bare skeleton (G13).
func _landmark_roadside_camp(root: Node3D) -> void:
	var shell := _flat("rc_shell", Color(0.74, 0.72, 0.66), 0.85)
	var rust := _flat("rc_rust", Color(0.46, 0.30, 0.20), 0.95)
	var glass := _flat("rc_glass", Color(0.28, 0.34, 0.34), 0.3, 0.2)
	var pole := _flat("rc_pole", Color(0.40, 0.38, 0.34), 0.9)
	var canvas := _flat("rc_canvas", Color(0.56, 0.52, 0.42), 0.95)
	var stone := _flat("rc_stone", Color(0.48, 0.46, 0.43), 0.95)
	var ash := _flat("rc_ash", Color(0.20, 0.19, 0.18), 1.0)

	# The caravan, on its side, wheels toward the road.
	var van := Node3D.new()
	van.position = Vector3(-3.4, 0.0, 0.4)
	van.rotation = Vector3(0.0, 0.42, PI * 0.5 + 0.06)
	root.add_child(van)
	_box(van, Vector3(2.3, 4.6, 2.0), shell, Vector3(0.0, 1.15, 0.0))
	_box(van, Vector3(2.35, 0.12, 2.05), rust, Vector3(0.0, 3.46, 0.0))
	for i in 2:
		_box(van, Vector3(0.05, 0.9, 0.8), glass,
			Vector3(1.18, 0.9 + float(i) * 1.7, 0.0))
	for sz: float in [-1.0, 1.0]:
		_cyl(van, 0.34, 0.34, 0.22, rust, Vector3(-1.22, 1.4, sz * 0.7),
			Vector3(0.0, 0.0, PI * 0.5))

	# Two tent skeletons: poles standing, canvas mostly gone.
	for t in 2:
		var tent := Node3D.new()
		tent.position = Vector3(1.6 + float(t) * 3.0, 0.0, 1.5 - float(t) * 0.8)
		tent.rotation.y = 0.3 - float(t) * 0.7
		root.add_child(tent)
		for sx: float in [-1.0, 1.0]:
			_cyl(tent, 0.035, 0.035, 1.9, pole, Vector3(sx * 0.9, 0.95, 0.0),
				Vector3(0.0, 0.0, -sx * 0.34))
		_cyl(tent, 0.03, 0.03, 2.4, pole, Vector3(0.0, 1.72, 0.0),
			Vector3(PI * 0.5, 0.0, 0.0))
		if t == 0:
			_box(tent, Vector3(1.3, 0.04, 1.1), canvas,
				Vector3(0.35, 0.62, 0.42), Vector3(0.5, 0.2, 0.3))

	# The lower camp: a stone ring still square, and its stakes still in line.
	for i in 9:
		var a := TAU * float(i) / 9.0
		_box(root, Vector3(0.34, 0.20, 0.34), stone,
			Vector3(0.4 + cos(a) * 0.72, 0.10, 3.5 + sin(a) * 0.72),
			Vector3(0.0, a, 0.0))
	_cyl(root, 0.62, 0.62, 0.05, ash, Vector3(0.4, 0.03, 3.5), Vector3.ZERO, 12)
	for i in 4:
		_cyl(root, 0.025, 0.025, 0.34, pole,
			Vector3(-1.6 + float(i) * 1.15, 0.17, 4.9),
			Vector3(0.0, 0.0, 0.22))
	_ao_blob(root, Vector2(9.0, 6.0), Vector3(0.0, 0.02, 1.8), 0.45)


## A shipping container put into the ground rather than onto it, with a whip
## antenna and a hatch. Half-buried is the tell: this was meant not to be seen
## from the road (G13).
func _landmark_listening_post(root: Node3D) -> void:
	var steel := _flat("lp_steel", Color(0.30, 0.36, 0.34), 0.8, 0.2)
	var rib := _flat("lp_rib", Color(0.25, 0.30, 0.29), 0.85, 0.2)
	var soil := _flat("lp_soil", Color(0.31, 0.26, 0.21), 1.0)
	var hatch := _flat("lp_hatch", Color(0.42, 0.44, 0.42), 0.7, 0.3)
	var wire := _flat("lp_wire", Color(0.34, 0.34, 0.35), 0.75, 0.5)
	var lamp := _flat("lp_lamp", Color(0.85, 0.34, 0.22), 0.4)

	# The mound it is buried in, then the container sunk into it.
	_cyl(root, 4.4, 5.6, 1.1, soil, Vector3(0.0, 0.55, 0.6), Vector3.ZERO, 16)
	_box(root, Vector3(6.1, 2.5, 2.5), steel, Vector3(0.0, 0.85, 0.6))
	for i in 11:
		_box(root, Vector3(0.10, 2.5, 2.56), rib,
			Vector3((float(i) - 5.0) * 0.54, 0.85, 0.6))
	_box(root, Vector3(6.2, 0.16, 2.6), rib, Vector3(0.0, 2.12, 0.6))

	# Hatch on top, open, with the ladder rail sticking out of it.
	_box(root, Vector3(1.0, 0.10, 1.0), hatch, Vector3(1.7, 2.22, 0.6))
	_box(root, Vector3(1.0, 0.08, 1.0), hatch, Vector3(2.35, 2.55, 0.6),
		Vector3(0.0, 0.0, -0.95))
	for sz: float in [-1.0, 1.0]:
		_cyl(root, 0.03, 0.03, 0.7, hatch,
			Vector3(1.42, 2.5, 0.6 + sz * 0.22))

	# The whip antenna, and one lamp that is still red.
	_cyl(root, 0.02, 0.05, 6.2, wire, Vector3(-2.3, 5.2, 0.6),
		Vector3(0.0, 0.0, 0.05))
	for i in 3:
		var a := TAU * float(i) / 3.0
		_cyl(root, 0.012, 0.012, 3.0, wire,
			Vector3(-2.3 + cos(a) * 0.7, 3.6, 0.6 + sin(a) * 0.7),
			Vector3(sin(a) * 0.24, 0.0, -cos(a) * 0.24))
	_ball(root, 0.11, lamp, Vector3(-2.3, 8.3, 0.6))
	_ao_blob(root, Vector2(7.5, 4.5), Vector3(0.0, 0.02, 0.6), 0.5)


## A single-storey clinic with ivy over most of it and its cross gone pale.
## Nothing is broken here — that is the unsettling part (G13).
func _landmark_old_clinic(root: Node3D) -> void:
	var render := _flat("cl_render", Color(0.78, 0.78, 0.73), 0.95)
	var trim := _flat("cl_trim", Color(0.60, 0.62, 0.60), 0.9)
	var roof := _flat("cl_roof", Color(0.34, 0.34, 0.33), 0.9)
	var glass := _flat("cl_glass", Color(0.30, 0.38, 0.38), 0.25, 0.25)
	var ivy := _flat("cl_ivy", Color(0.21, 0.36, 0.20), 0.95)
	var cross := _flat("cl_cross", Color(0.70, 0.44, 0.42), 0.9)

	var w := 10.0
	var d := 5.4
	var h := 3.2
	_box(root, Vector3(w + 0.6, 0.28, d + 0.6), trim, Vector3(0.0, 0.14, 0.0))
	_box(root, Vector3(w, h, d), render, Vector3(0.0, h * 0.5 + 0.28, 0.0))
	_box(root, Vector3(w + 0.8, 0.24, d + 0.8), roof, Vector3(0.0, h + 0.42, 0.0))
	# Windows along the south face, all intact.
	for i in 4:
		_box(root, Vector3(1.3, 1.5, 0.10), trim,
			Vector3((float(i) - 1.5) * 2.2, 1.95, -d * 0.5 - 0.05))
		_box(root, Vector3(1.1, 1.3, 0.06), glass,
			Vector3((float(i) - 1.5) * 2.2, 1.95, -d * 0.5 - 0.11))
	_box(root, Vector3(1.5, 2.3, 0.12), trim, Vector3(-w * 0.5 + 1.6, 1.43,
		-d * 0.5 - 0.06))

	# The cross over the door, faded to pink.
	_box(root, Vector3(0.9, 0.26, 0.08), cross,
		Vector3(-w * 0.5 + 1.6, 3.05, -d * 0.5 - 0.12))
	_box(root, Vector3(0.26, 0.9, 0.08), cross,
		Vector3(-w * 0.5 + 1.6, 3.05, -d * 0.5 - 0.12))

	# Ivy: a mat over the east third, and runners reaching along the roof line.
	var rng := RandomNumberGenerator.new()
	rng.seed = 151501
	for i in 46:
		var t := rng.randf()
		_box(root, Vector3(rng.randf_range(0.5, 1.2), rng.randf_range(0.4, 1.0),
			0.06), ivy,
			Vector3(w * 0.5 - rng.randf_range(0.2, 3.4), 0.5 + t * (h - 0.4),
				-d * 0.5 - 0.14), Vector3(0.0, 0.0, rng.randf_range(-0.3, 0.3)))
	for i in 14:
		_box(root, Vector3(rng.randf_range(0.6, 1.4), 0.32, 0.06), ivy,
			Vector3(rng.randf_range(-w * 0.5, w * 0.5), h + 0.30,
				-d * 0.5 - 0.12))
	_ao_blob(root, Vector2(w + 3.0, d + 3.0), Vector3(0.0, 0.02, 0.0), 0.55)


## A boundary stone at a crossroads, with a chalk ring drawn on it. People have
## been meeting here — the stone is old, the chalk is two days old, and it did
## not rain between (G13).
func _landmark_meeting_stone(root: Node3D) -> void:
	var rock := _flat("ms_rock", Color(0.53, 0.51, 0.47), 0.95)
	var dark := _flat("ms_dark", Color(0.40, 0.39, 0.36), 0.95)
	var chalk := _flat("ms_chalk", Color(0.93, 0.92, 0.88), 0.85)
	var post := _flat("ms_post", Color(0.38, 0.31, 0.22), 0.95)
	var iron := _flat("ms_iron", Color(0.40, 0.30, 0.22), 0.9, 0.3)

	# The stone: a leaning slab, not a boulder. Somebody stood it up.
	_box(root, Vector3(1.9, 3.1, 0.9), rock, Vector3(0.0, 1.55, 0.0),
		Vector3(0.0, 0.22, -0.06))
	_box(root, Vector3(2.3, 0.32, 1.3), dark, Vector3(0.0, 0.16, 0.0),
		Vector3(0.0, 0.22, 0.0))
	# The chalk ring and its seven marks, on the south face where you would
	# stand to read it.
	var face := 0.48
	for i in 22:
		var a := TAU * float(i) / 22.0
		_box(root, Vector3(0.10, 0.10, 0.04), chalk,
			Vector3(sin(0.22) * face + cos(a) * 0.62, 1.85 + sin(a) * 0.62,
				-cos(0.22) * face), Vector3(0.0, 0.22, 0.0))
	for i in 7:
		var a2 := TAU * float(i) / 7.0 - PI * 0.5
		_box(root, Vector3(0.16, 0.16, 0.04), chalk,
			Vector3(sin(0.22) * face + cos(a2) * 0.40, 1.85 + sin(a2) * 0.40,
				-cos(0.22) * face), Vector3(0.0, 0.22, a2))

	# A signpost with both arms gone, and the nails still in it.
	_cyl(root, 0.08, 0.10, 2.6, post, Vector3(3.1, 1.30, 1.4))
	for i in 2:
		_box(root, Vector3(0.10, 0.05, 0.05), iron,
			Vector3(3.1, 2.10 - float(i) * 0.34, 1.34))
	_ao_blob(root, Vector2(4.4, 3.2), Vector3(0.4, 0.02, 0.4), 0.55)


## A collapsed glasshouse with a mast through the roof of it: somebody grew
## things here AND transmitted from here, and the two are the same story. The
## beacon is still on, which is why the frame is lit from inside (G13).
func _landmark_signal_garden(root: Node3D) -> void:
	var frame := _flat("sg_frame", Color(0.42, 0.44, 0.42), 0.7, 0.25)
	var glass := _flat("sg_glass", Color(0.62, 0.74, 0.68), 0.2, 0.1)
	var brick := _flat("sg_brick", Color(0.48, 0.38, 0.32), 0.95)
	var soil := _flat("sg_soil", Color(0.28, 0.22, 0.17), 1.0)
	var green := _flat("sg_green", Color(0.30, 0.52, 0.26), 0.9)
	var steel := _flat("sg_steel", Color(0.48, 0.49, 0.50), 0.6, 0.4)
	var lamp := _flat("sg_lamp", Color(0.42, 0.88, 0.52), 0.3)

	var w := 7.0
	var d := 4.4
	_box(root, Vector3(w + 0.5, 0.5, d + 0.5), brick, Vector3(0.0, 0.25, 0.0))
	# Uprights, most still standing, two folded over.
	for i in 7:
		var x := (float(i) - 3.0) * (w / 6.0)
		var fallen := i == 2 or i == 5
		var h := 2.6 if not fallen else 1.2
		for sz: float in [-1.0, 1.0]:
			_cyl(root, 0.05, 0.05, h, frame,
				Vector3(x, 0.5 + h * 0.5, sz * d * 0.5),
				Vector3(0.0, 0.0, 0.5 if fallen else 0.0))
		if not fallen:
			_box(root, Vector3(0.08, 0.08, d), frame, Vector3(x, 3.1, 0.0))
			# One pane per bay, tilted: glass that is still IN the frame.
			_box(root, Vector3(w / 6.0 - 0.15, 0.04, d * 0.92), glass,
				Vector3(x + w / 12.0, 3.02, 0.0), Vector3(0.0, 0.0, 0.06))
	for sz2: float in [-1.0, 1.0]:
		_box(root, Vector3(w, 0.08, 0.08), frame, Vector3(0.0, 3.1, sz2 * d * 0.5))

	# Beds inside, still in rows, still green. Somebody waters these.
	for i in 3:
		_box(root, Vector3(w - 1.4, 0.22, 0.8), soil,
			Vector3(0.0, 0.61, (float(i) - 1.0) * 1.25))
		for k in 7:
			_ball(root, 0.13, green,
				Vector3((float(k) - 3.0) * 0.72, 0.78, (float(i) - 1.0) * 1.25),
				Vector3(1.0, 0.7, 1.0))

	# The mast, straight up through the broken bay, with the beacon lit.
	_cyl(root, 0.06, 0.09, 7.4, steel, Vector3(w * 0.5 - 1.2, 4.2, 0.0))
	for i in 3:
		_box(root, Vector3(0.9, 0.05, 0.05), steel,
			Vector3(w * 0.5 - 1.2, 5.4 + float(i) * 0.9, 0.0),
			Vector3(0.0, float(i) * 1.1, 0.0))
	_ball(root, 0.16, lamp, Vector3(w * 0.5 - 1.2, 7.95, 0.0))
	_ao_blob(root, Vector2(w + 2.5, d + 2.5), Vector3(0.0, 0.02, 0.0), 0.55)


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


# ---------------------------------------------------------------- traces (G9.2)

## Quiet leftovers of the outbreak years, seeded per chapter so each yard keeps
## its own history: boarded windows on a neighbor, a faded quarantine mark, a
## small roadside memorial, a leaning weathered sign. Implied past only — no
## text, no gore, and none of it inside the mowable lawn.
func _build_traces() -> void:
	var plank := _tex_mat("wood", "wood_albedo", Color(0.55, 0.42, 0.27), 0.85)
	var faded_paint := _flat("trace_paint", Color(0.52, 0.20, 0.16, 0.75), 0.95)
	faded_paint.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var stone_mat := _flat("trace_stone", Color(0.62, 0.61, 0.57), 0.95)
	var rust := _flat("trace_rust", Color(0.44, 0.30, 0.20), 0.9, 0.3)

	# 1. Boarded windows on one neighbor house (~70% of chapters). The neighbors
	# stand at neighbor_z(), so the boards go on their south face.
	if _rng.randf() < 0.7:
		var nx: float = GameConfig.NEIGHBOR_X[_rng.randi_range(0,
			GameConfig.NEIGHBOR_X.size() - 1)]
		var wall_z := GameConfig.neighbor_z() - 2.05
		for k in 2:
			var wx := nx + (-1.4 if k == 0 else 1.2) + _rng.randf_range(-0.2, 0.2)
			_box(self, Vector3(1.1, 0.16, 0.05), plank,
				Vector3(wx, 1.5, wall_z), Vector3(0.0, 0.0, 0.5))
			_box(self, Vector3(1.1, 0.16, 0.05), plank,
				Vector3(wx, 1.4, wall_z + 0.01), Vector3(0.0, 0.0, -0.45))

	# 2. A faded painted ring on the fence or a neighbor wall: the old clearance
	# mark, weathered to a shadow of itself (~60%).
	if _rng.randf() < 0.6:
		var mark_x := _rng.randf_range(-GameConfig.HALF_X * 0.6,
			GameConfig.HALF_X * 0.6)
		var ring := TorusMesh.new()
		ring.inner_radius = 0.22
		ring.outer_radius = 0.30
		ring.rings = 12
		ring.ring_segments = 6
		_mesh(self, ring, faded_paint,
			Vector3(mark_x, 1.1, GameConfig.neighbor_z() - 2.04),
			Vector3(PI * 0.5, 0.0, 0.0))

	# 3. Roadside memorial: a stone, a small board, flowers kept fresh — someone
	# still tends it (~65%). Sits on the dirt strip between fence and sidewalk.
	if _rng.randf() < 0.65:
		var mem_x := _rng.randf_range(-GameConfig.HALF_X * 0.8,
			GameConfig.HALF_X * 0.8)
		var mem_z := GameConfig.fence_south_z() + 0.9
		_ball(self, 0.30, stone_mat, Vector3(mem_x, 0.16, mem_z),
			Vector3(1.1, 0.6, 0.9))
		_box(self, Vector3(0.34, 0.5, 0.05), plank,
			Vector3(mem_x + 0.42, 0.25, mem_z), Vector3(-0.12, 0.3, 0.0))
		_flower(0, Vector3(mem_x - 0.35, 0.0, mem_z + 0.15))
		_flower(1, Vector3(mem_x - 0.15, 0.0, mem_z + 0.3))
		_ao_blob(self, Vector2(1.6, 1.0), Vector3(mem_x, 0.02, mem_z), 0.4)

	# 4. A leaning weathered sign by the road, its face long since blank (~55%).
	if _rng.randf() < 0.55:
		var sign_x := _rng.randf_range(-GameConfig.HALF_X, GameConfig.HALF_X)
		var sign_z := GameConfig.sidewalk_z() - 0.6
		_cyl(self, 0.05, 0.06, 1.7, rust,
			Vector3(sign_x, 0.85, sign_z), Vector3(0.0, 0.0, 0.14))
		_box(self, Vector3(0.9, 0.6, 0.04), rust,
			Vector3(sign_x + 0.22, 1.55, sign_z), Vector3(0.0, 0.1, 0.14))
