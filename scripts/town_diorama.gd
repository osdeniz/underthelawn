class_name TownDiorama
extends Node3D
## The hub's 3D town, a fixed-camera model of the square (G13).
##
## This is a TRIAL of replacing the hub's 2D collage. Scope is deliberately
## three buildings: Marshal's station, two homes, the watchtower. The other
## seven projects in data/projects.json are not in this scene yet — they get
## added with the same recipe once the slice is approved.
##
## Everything here is primitives and flat materials, built in code, so a
## building's ruined and restored forms are two node trees that can be swapped
## and animated part by part. There is no skeleton and no animation resource.
##
## Nothing in this file may become a path to a .glb or a per-building scene:
## the whole point is that adding building four is a dictionary entry plus one
## builder function.

signal building_pressed(project_id: String)

const PART_META := "rest_pos"

var camera: Camera3D
## The building nodes, keyed by project id: {"ruined": Node3D, "restored": Node3D}
var _buildings: Dictionary = {}
var _mats: Dictionary = {}
var _sway_t := 0.0
var _pan := 0.0
var _pan_target := 0.0
var _pan_finger := -1
var _pan_from := 0.0
var _cam_base := Vector3.ZERO
var _cam_look := Vector3.ZERO
## Set while a restore transition owns the camera.
var _busy := false
var _rng := RandomNumberGenerator.new()
## The long-grass field: one MultiMesh per clump variant, plus where every
## clump stands and which ruin's overgrowth it belongs to (G13.1).
var _tuft_meshes: Array[MultiMesh] = []
var _tuft_spots: Array = []
## Plots whose weeds have been cleared by rebuilding.
var _cleared: Dictionary = {}
## Tree crowns that sway, with their phase offsets.
var _canopies: Array = []
## Cloth on the washing line, lantern lights, and birds in transit.
var _cloths: Array = []
var _lamps: Array = []
var _birds: Array = []
var _bird_timer := 3.0
## The townsfolk, and Ellie on her swing (G13.5).
var _figures: Array = []
var _ellie_swing: Node3D
## A restore card is being held down, and the camera is showing its plot.
var _peek := false
var _peek_id := ""
## Static subtrees waiting to be welded into one mesh per material (G13.6).
var _bake_targets: Array = []
## Which subtrees have already been welded; baking is one-way.
var _baked: Dictionary = {}
## The reclaimed weed band (G13.4): its own MultiMesh, never baked, because it
## retreats a step for every chapter the player finishes.
var _reclaim_mesh: MultiMesh
var _reclaim_spots: Array = []
var _life_t := 0.0


func _ready() -> void:
	_rng.seed = 13
	_cam_base = GameConfig.DIORAMA_CAM_POS
	_cam_look = GameConfig.DIORAMA_CAM_LOOK
	_build_environment()
	_build_plate()
	_build_dead_oak(GameConfig.DIORAMA_TREE_POS)
	for id: String in GameConfig.DIORAMA_BUILDINGS:
		_build_building(id)
	_build_edge_planting()
	_build_horizon()
	_build_tufts()
	_build_figures()
	_build_reclaim()
	refresh_state()
	_bake_static()


## Welds every static subtree, then says what it cost. Runs after the scene is
## built and after each rebuild finishes (G13.6).
func _bake_static() -> void:
	var saved := 0
	for target_any: Variant in _bake_targets:
		var node := target_any as Node3D
		if node != null and is_instance_valid(node):
			saved += MeshBake.bake(node)
	_bake_targets.clear()
	# The ruined forms never animate part by part — they sink as one node — so
	# they can be welded immediately.
	for id: String in _buildings:
		var ruined := _buildings[id]["ruined"] as Node3D
		if ruined != null and is_instance_valid(ruined) \
				and not _baked.has("ruin_" + id):
			saved += MeshBake.bake(ruined)
			_baked["ruin_" + id] = true
		# A restored form that is already standing has no animation left to
		# play, so it can be welded too.
		var restored := _buildings[id]["restored"] as Node3D
		if restored != null and is_instance_valid(restored) \
				and restored.visible and not _baked.has("built_" + id):
			saved += MeshBake.bake(restored)
			_baked["built_" + id] = true
	if GameConfig.PERF_LOG and saved > 0:
		print("[diorama] bake: %d cizim kazanildi" % saved)


## Shows each building in the form its project data says it should be in. Called
## on entry and after a purchase that was not animated.
func refresh_state() -> void:
	for id: String in _buildings:
		set_built(id, RestoreBoard.is_built(id), false)


func set_built(project_id: String, built: bool, animated: bool) -> void:
	var pair: Dictionary = _buildings.get(project_id, {})
	if pair.is_empty():
		return
	var ruined: Node3D = pair["ruined"]
	var restored: Node3D = pair["restored"]
	ruined.visible = not built
	restored.visible = built
	# A rebuilt plot loses its overgrowth: the town taking itself back.
	if built:
		_cleared[project_id] = true
	else:
		_cleared.erase(project_id)
	if not _tuft_meshes.is_empty():
		_write_tufts()
	if not _figures.is_empty():
		refresh_figures()
	if built and not animated:
		# Straight to standing: no half-fallen parts left over from a skipped
		# transition.
		for part in restored.get_children():
			var node := part as Node3D
			if node != null and node.has_meta(PART_META):
				node.position = node.get_meta(PART_META)
				node.scale = Vector3.ONE


func has_building(project_id: String) -> bool:
	return _buildings.has(project_id)


## Clouds on a ring behind the plate, and two or three flocks over the town.
## Both are unshaded billboards well outside the fog's far edge, so they read as
## distance rather than as objects.
func _build_sky_life() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 771
	var tex := TextureLibrary.find("cloud_billboard")
	var mat := StandardMaterial3D.new()
	if tex != null:
		mat.albedo_texture = tex
	mat.albedo_color = Color(1, 1, 1, 0.55)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	var sky := Node3D.new()
	sky.name = "SkyLife"
	# Never welded into the baked town: these move, and the bake is one-way.
	sky.set_meta("no_bake", true)
	add_child(sky)

	for i in GameConfig.DIORAMA_CLOUD_COUNT:
		var size := rng.randf_range(GameConfig.DIORAMA_CLOUD_SIZE.x,
			GameConfig.DIORAMA_CLOUD_SIZE.y)
		var quad := QuadMesh.new()
		quad.size = Vector2(size, size * 0.5)
		quad.material = mat
		var mi := MeshInstance3D.new()
		mi.mesh = quad
		mi.set_meta("no_bake", true)
		mi.position = _sky_spot(rng, GameConfig.DIORAMA_CLOUD_DIST,
			GameConfig.DIORAMA_CLOUD_DROP)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		sky.add_child(mi)

	# The flocks circle a point out in front rather than the town itself, for
	# the same reason: a ring around the plate is mostly behind the camera.
	var flock_root := Node3D.new()
	flock_root.set_meta("no_bake", true)
	flock_root.position = _sky_spot(rng, GameConfig.DIORAMA_BIRD_DIST,
		GameConfig.DIORAMA_BIRD_DROP)
	sky.add_child(flock_root)
	var flock := Birds.build(flock_root, 4242, Vector2(0.0, 0.0),
		Vector2(6.0, 15.0), GameConfig.DIORAMA_BIRD_SIZE)
	if flock != null:
		flock.set_meta("no_bake", true)


## A point in front of the hub camera: `dist` out along its view direction,
## `drop` below its own height, and up to DIORAMA_SKY_SPREAD degrees to either
## side. Everything about where sky decoration ends up on screen is decided
## here, which is why it is one function and not three copies of the same maths.
func _sky_spot(rng: RandomNumberGenerator, dist: Vector2,
		drop: Vector2) -> Vector3:
	var eye := GameConfig.DIORAMA_CAM_POS
	var forward := (GameConfig.DIORAMA_CAM_LOOK - eye)
	var flat := Vector2(forward.x, forward.z).normalized()
	var heading := atan2(flat.y, flat.x)
	var a := heading + deg_to_rad(
		rng.randf_range(-GameConfig.DIORAMA_SKY_SPREAD,
			GameConfig.DIORAMA_SKY_SPREAD))
	var out := rng.randf_range(dist.x, dist.y)
	return Vector3(eye.x + cos(a) * out,
		eye.y - rng.randf_range(drop.x, drop.y),
		eye.z + sin(a) * out)


# ---------------------------------------------------------------- environment

func _build_environment() -> void:
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.36, 0.60, 0.90)
	sky_mat.sky_horizon_color = Color(0.97, 0.88, 0.72)
	sky_mat.sky_curve = 0.16
	# The camera looks down, so most of the backdrop is the sky's GROUND half.
	# Warm and dim: the model should sit in haze, not on a grey wall.
	sky_mat.ground_bottom_color = Color(0.42, 0.36, 0.28)
	sky_mat.ground_horizon_color = Color(0.90, 0.82, 0.68)
	sky.sky_material = sky_mat
	env.sky = sky
	# The sky IS the ambient light and the reflection source, same as the yard:
	# a flat ambient colour is what made the first pass look like a toy under a
	# lightbox. NOT SDFGI and NOT SSAO — both are broken on the mobile renderer,
	# which is why every contact shadow here is a painted AO blob.
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.55
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	# The fog is the diorama's edge: the plate does not end, it dissolves.
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_light_color = Color(0.94, 0.90, 0.82)
	env.fog_density = 1.0
	env.fog_depth_curve = 1.6
	# Only the far RIM dissolves. At 30/58 the fog reached the middle of the
	# plate and turned the back half into a white haze (G13.1).
	env.fog_depth_begin = 52.0
	env.fog_depth_end = 96.0
	# Without this the sky is fog too, and the whole backdrop goes flat cream.
	env.fog_sky_affect = 0.15
	world.environment = env
	add_child(world)

	# Warm low morning sun, same shadow settings as the yard.
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation = Vector3(deg_to_rad(-38.0), deg_to_rad(38.0), 0.0)
	sun.light_color = Color(1.0, 0.94, 0.83)
	sun.light_energy = 1.15
	sun.shadow_enabled = true
	sun.shadow_blur = 3.0
	sun.directional_shadow_max_distance = 44.0
	add_child(sun)

	camera = Camera3D.new()
	camera.name = "DioramaCamera"
	camera.fov = GameConfig.DIORAMA_CAM_FOV
	camera.keep_aspect = Camera3D.KEEP_WIDTH
	camera.v_offset = GameConfig.DIORAMA_V_OFFSET
	camera.position = _cam_base
	add_child(camera)
	camera.look_at(_cam_look)


## The plate: a grass top, a bevelled rim that falls away, and a soil skirt. The
## bevel is what reads as "model on a table" rather than "ground that got cut".
func _build_plate() -> void:
	var half := GameConfig.DIORAMA_PLATE * 0.5
	var bevel := GameConfig.DIORAMA_BEVEL
	var grass := _ground_material()
	var soil := _tex_mat("soil", "dirt_albedo", GameConfig.TINT_SOIL, 1.0,
		Vector3(8.0, 3.0, 1.0))

	var top := PlaneMesh.new()
	top.size = GameConfig.DIORAMA_PLATE - Vector2.ONE * bevel * 2.0
	# Subdivided, so the ground shader has vertices to work with and the plate
	# is not one flat quad (G13.1).
	top.subdivide_width = 12
	top.subdivide_depth = 16
	_mesh(self, top, grass, Vector3.ZERO)

	# Four bevel skirts. A skirt that drops `h` over a run of `b` is
	# sqrt(b*b + h*h) long, and its centre sits half a bevel in from the outer
	# edge, half the drop down.
	var drop := GameConfig.DIORAMA_BEVEL_DROP
	var run := sqrt(bevel * bevel + drop * drop)
	var tilt := atan2(drop, bevel)
	var inner := half - Vector2.ONE * bevel * 0.5
	var sides := [
		{"size": Vector2(GameConfig.DIORAMA_PLATE.x - bevel * 2.0, run),
			"pos": Vector3(0.0, -drop * 0.5, -inner.y), "rot": Vector3(-tilt, 0.0, 0.0)},
		{"size": Vector2(GameConfig.DIORAMA_PLATE.x - bevel * 2.0, run),
			"pos": Vector3(0.0, -drop * 0.5, inner.y), "rot": Vector3(tilt, 0.0, 0.0)},
		{"size": Vector2(run, GameConfig.DIORAMA_PLATE.y - bevel * 2.0),
			"pos": Vector3(-inner.x, -drop * 0.5, 0.0), "rot": Vector3(0.0, 0.0, tilt)},
		{"size": Vector2(run, GameConfig.DIORAMA_PLATE.y - bevel * 2.0),
			"pos": Vector3(inner.x, -drop * 0.5, 0.0), "rot": Vector3(0.0, 0.0, -tilt)},
	]
	for side: Dictionary in sides:
		var skirt := PlaneMesh.new()
		skirt.size = side["size"]
		skirt.subdivide_width = 8
		_mesh(self, skirt, grass, side["pos"], side["rot"])

	var body := BoxMesh.new()
	body.size = Vector3(GameConfig.DIORAMA_PLATE.x - bevel * 2.0, 3.0,
		GameConfig.DIORAMA_PLATE.y - bevel * 2.0)
	_mesh(self, body, soil, Vector3(0.0, -drop - 1.5, 0.0))

	_build_square()


## The yard's ground recipe, not a flat colour: grass_albedo tiled through
## lawn_ground.gdshader with its normal map and a per-plate tint texture. The
## first version was a StandardMaterial with one albedo colour, which is what
## made the plate read as coloured cardboard (G13.1).
func _ground_material() -> ShaderMaterial:
	if _mats.has("ground"):
		return _mats["ground"]
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/lawn_ground.gdshader")
	var albedo := TextureLibrary.find("grass_albedo")
	var normal := TextureLibrary.find("grass_normal")
	if albedo != null:
		mat.set_shader_parameter("grass_albedo", albedo)
		mat.set_shader_parameter("has_albedo", true)
	else:
		TextureLibrary.warn_missing("grass_albedo", "duz renk zemin")
	if normal != null:
		mat.set_shader_parameter("grass_normal", normal)
		mat.set_shader_parameter("has_normal", true)
	mat.set_shader_parameter("fallback_albedo", GameConfig.DIORAMA_GRASS_TINT)
	mat.set_shader_parameter("uv_repeat", Vector2(9.0, 12.0))
	mat.set_shader_parameter("normal_strength", GameConfig.GROUND_NORMAL_STRENGTH)
	mat.set_shader_parameter("surface_roughness", 0.95)
	mat.set_shader_parameter("cell_tint", _tint_texture())
	_mats["ground"] = mat
	return mat


## A low-resolution noise tint the ground shader multiplies over the grass, so
## the plate has patches of lighter and darker green instead of one flat wash.
func _tint_texture() -> ImageTexture:
	var size := 24
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var noise := FastNoiseLite.new()
	noise.seed = 13
	noise.frequency = 0.09
	# The tint carries the COLOUR, not just brightness: grass_albedo is a
	# greyscale pattern, so a tint of pale greys left the whole plate white.
	var lush := GameConfig.DIORAMA_GRASS_TINT
	var dry_colour := Color(0.62, 0.58, 0.30)
	for y in size:
		for x in size:
			var n := noise.get_noise_2d(float(x), float(y)) * 0.5 + 0.5
			var dry := clampf((n - 0.62) * 2.4, 0.0, 1.0)
			var shade := lerpf(0.82, 1.24, n)
			var c := lush.lerp(dry_colour, dry) * shade
			img.set_pixel(x, y, Color(c.r, c.g, c.b))
	return ImageTexture.create_from_image(img)


## The paved square and the dirt paths that reach the three plots.
func _build_square() -> void:
	var stone := _tex_mat("stone", "asphalt_albedo", Color(0.56, 0.55, 0.52),
		0.95, Vector3(4.0, 4.0, 1.0))
	stone.albedo_color = Color(1.35, 1.34, 1.28)
	var dirt := _tex_mat("path", "dirt_albedo", Color(0.46, 0.36, 0.25), 1.0,
		Vector3(1.2, 6.0, 1.0))
	var joint := _flat("joint", Color(0.40, 0.39, 0.36), 0.95)

	var pave := CylinderMesh.new()
	pave.top_radius = 3.6
	pave.bottom_radius = 3.6
	pave.height = 0.10
	pave.radial_segments = 24
	_mesh(self, pave, stone, Vector3(0.0, 0.03, 0.0))
	# Joints across the paving: eight thin dark strips, so it reads as slabs
	# rather than a poured disc.
	for i in 8:
		var a := PI * float(i) / 8.0
		_box(self, Vector3(7.2, 0.02, 0.06), joint, Vector3(0.0, 0.09, 0.0),
			Vector3(0.0, a, 0.0))
	for id: String in GameConfig.DIORAMA_BUILDINGS:
		var spot: Vector3 = GameConfig.DIORAMA_BUILDINGS[id]["pos"]
		var to := Vector2(spot.x, spot.z)
		var path := BoxMesh.new()
		path.size = Vector3(1.6, 0.05, to.length())
		_mesh(self, path, dirt,
			Vector3(to.x * 0.5, 0.025, to.y * 0.5),
			Vector3(0.0, atan2(to.x, to.y), 0.0))


## The square's oak: leaning, thick-limbed, and big enough to be the landmark
## the town is arranged around. The swing project will hang from it.
func _build_dead_oak(at: Vector3) -> void:
	var bark := _tex_mat("bark", "bark_albedo", Color(0.30, 0.23, 0.17), 0.98,
		Vector3(1.0, 2.0, 1.0))
	var tree := Node3D.new()
	tree.name = "DeadOak"
	tree.position = at
	tree.rotation.y = 0.4
	add_child(tree)
	# A leaning trunk in two stages: thick and rooted, then narrower and tipped
	# further over, so it has a silhouette rather than being a post.
	_cyl(tree, 0.34, 0.62, 3.2, bark, Vector3(0.0, 1.6, 0.0),
		Vector3(0.0, 0.0, 0.10))
	_cyl(tree, 0.22, 0.36, 2.0, bark, Vector3(-0.42, 4.0, 0.10),
		Vector3(0.06, 0.0, 0.26))
	var limbs := [
		{"r": [0.09, 0.24], "len": 3.1, "at": Vector3(0.95, 4.3, 0.20),
			"rot": Vector3(0.0, 0.3, -0.95)},
		{"r": [0.08, 0.22], "len": 2.8, "at": Vector3(-1.15, 4.5, -0.30),
			"rot": Vector3(0.25, -0.2, 0.88)},
		{"r": [0.07, 0.18], "len": 2.2, "at": Vector3(-0.20, 5.4, -0.90),
			"rot": Vector3(-0.85, 0.0, 0.18)},
		{"r": [0.05, 0.11], "len": 1.4, "at": Vector3(1.85, 5.5, 0.55),
			"rot": Vector3(0.0, 0.2, -1.15)},
		{"r": [0.04, 0.10], "len": 1.2, "at": Vector3(-2.05, 5.6, 0.05),
			"rot": Vector3(0.0, 0.0, 1.05)},
		{"r": [0.04, 0.09], "len": 1.0, "at": Vector3(-0.75, 6.1, 0.65),
			"rot": Vector3(0.7, 0.0, 0.5)},
	]
	for limb: Dictionary in limbs:
		var radii: Array = limb["r"]
		_cyl(tree, float(radii[0]), float(radii[1]), float(limb["len"]), bark,
			limb["at"], limb["rot"])
	_ao_blob(tree, Vector2(5.6, 4.6), Vector3(1.1, 0.03, 0.7), 0.6)
	_build_square_props(tree)


## What is left lying around the square: a barrow on its side, two barrels, a
## crate, and a heap of cut weeds nobody came back for.
func _build_square_props(near: Node3D) -> void:
	var wood := _tex_mat("prop_wood", "wood_albedo", Color(0.52, 0.38, 0.24),
		0.95, Vector3(2.0, 1.0, 1.0))
	var rust := _flat("rust", Color(0.46, 0.30, 0.20), 0.9, 0.3)
	var iron := _flat("iron", Color(0.34, 0.34, 0.36), 0.6, 0.5)
	var straw := _flat("straw", Color(0.52, 0.48, 0.26), 1.0)

	# Two barrels by the trunk.
	for spec: Array in [[Vector3(2.4, 0.44, 1.5), 0.0], [Vector3(3.1, 0.42, 0.7), 0.3]]:
		var barrel := _cyl(near, 0.42, 0.46, 0.88, rust, spec[0],
			Vector3(0.0, float(spec[1]), 0.0))
		_box(near, Vector3(0.9, 0.06, 0.9), iron,
			(spec[0] as Vector3) + Vector3(0.0, 0.16, 0.0))
		barrel.name = "Barrel"
	# A crate, and a plank leaning on it.
	_box(near, Vector3(0.9, 0.7, 0.9), wood, Vector3(-2.6, 0.35, 1.3),
		Vector3(0.0, 0.5, 0.0))
	_box(near, Vector3(0.14, 1.5, 0.5), wood, Vector3(-3.2, 0.6, 1.9),
		Vector3(0.0, 0.4, 0.9))
	# The barrow: a tipped tray, one wheel, two handles.
	var barrow := Node3D.new()
	barrow.position = Vector3(-1.6, 0.0, -2.4)
	barrow.rotation = Vector3(0.0, 1.1, 0.0)
	near.add_child(barrow)
	_box(barrow, Vector3(1.1, 0.5, 0.7), rust, Vector3(0.0, 0.42, 0.0),
		Vector3(0.0, 0.0, 0.5))
	_cyl(barrow, 0.24, 0.24, 0.10, iron, Vector3(0.62, 0.24, 0.0),
		Vector3(0.0, 0.0, deg_to_rad(90.0)))
	for side: float in [-1.0, 1.0]:
		_box(barrow, Vector3(1.3, 0.07, 0.07), wood,
			Vector3(-0.45, 0.30, side * 0.28), Vector3(0.0, 0.0, 0.22))
	# The heap of dry cuttings at the foot of the tree.
	for i in 5:
		var a := TAU * float(i) / 5.0
		_box(near, Vector3(1.1, 0.22, 0.8), straw,
			Vector3(cos(a) * 0.8 - 0.6, 0.11, sin(a) * 0.7 + 1.9),
			Vector3(0.1, a, 0.06))


## Trees and hedges around the rim, so the frame is FULL and the plate does not
## simply run out into empty ground. Same idea as the yard's neighbour
## silhouettes: the edge of the world is scenery, not an edge (G13.1).
func _build_edge_planting() -> void:
	var bark := _tex_mat("bark", "bark_albedo", Color(0.30, 0.23, 0.17), 0.98,
		Vector3(1.0, 2.0, 1.0))
	var leaf_dark := _flat("leaf_dark", GameConfig.TREE_LEAF_DARK, 1.0)
	var leaf_light := _flat("leaf_light", GameConfig.TREE_LEAF_LIGHT, 1.0)
	var hedge := _flat("hedge", Color(0.20, 0.34, 0.16), 1.0)
	var half := GameConfig.DIORAMA_PLATE * 0.5
	var rng := RandomNumberGenerator.new()
	rng.seed = 606

	for i in GameConfig.DIORAMA_EDGE_TREES:
		var at := _rim_point(rng, half, 0.6, 3.2)
		# Behind the camera line there is nothing to frame, so the back half
		# gets most of the trees.
		if at.z > half.y * 0.65 and rng.randf() < 0.6:
			continue
		var tree := Node3D.new()
		tree.position = at
		tree.rotation.y = rng.randf() * TAU
		var size := rng.randf_range(0.9, 1.5)
		tree.scale = Vector3.ONE * size
		add_child(tree)
		_cyl(tree, 0.16, 0.26, 2.8, bark, Vector3(0.0, 1.4, 0.0),
			Vector3(0.0, 0.0, rng.randf_range(-0.09, 0.09)))
		var canopy := Node3D.new()
		canopy.name = "Canopy"
		tree.add_child(canopy)
		_canopies.append({"node": canopy, "phase": rng.randf() * TAU})
		for b in 8:
			var a := TAU * float(b) / 8.0
			var ring := 0.62 + rng.randf_range(-0.18, 0.3)
			var y := 3.1 + (0.95 if b % 3 == 0 else 0.35) + rng.randf_range(-0.2, 0.25)
			_ball(canopy, 0.66, leaf_light if y > 3.8 else leaf_dark,
				Vector3(cos(a) * ring, y, sin(a) * ring),
				Vector3(rng.randf_range(0.85, 1.35), rng.randf_range(0.65, 1.05),
					rng.randf_range(0.85, 1.35)))
		_ao_blob(tree, Vector2(3.4, 2.8), Vector3(0.7, 0.03, 0.45), 0.55)
		# The crown was its own node so it could sway; welded, the whole tree
		# leans instead, which at this distance is the same picture for a
		# tenth of the draws.
		_canopies.pop_back()
		_canopies.append({"node": tree, "phase": rng.randf() * TAU})
		_bake_targets.append(tree)

	# All the bushes under ONE node so they weld into a single draw: they do not
	# move, so nothing is lost by making them one mesh (G13.6).
	var hedges := Node3D.new()
	hedges.name = "Hedges"
	add_child(hedges)
	for i in GameConfig.DIORAMA_EDGE_BUSHES:
		var at := _rim_point(rng, half, 0.3, 2.2)
		var bush := Node3D.new()
		bush.position = at
		hedges.add_child(bush)
		for b in 3:
			_ball(bush, rng.randf_range(0.45, 0.8), hedge,
				Vector3(rng.randf_range(-0.4, 0.4), rng.randf_range(0.2, 0.45),
					rng.randf_range(-0.4, 0.4)),
				Vector3(1.2, rng.randf_range(0.6, 0.9), 1.2))
	_bake_targets.append(hedges)


## A point in the band just inside the plate's rim.
func _rim_point(rng: RandomNumberGenerator, half: Vector2, inset: float,
		band: float) -> Vector3:
	var side := rng.randi_range(0, 3)
	var along := rng.randf_range(-1.0, 1.0)
	var depth := inset + rng.randf() * band
	match side:
		0: return Vector3(along * half.x, 0.0, -half.y + depth)
		1: return Vector3(along * half.x, 0.0, half.y - depth)
		2: return Vector3(-half.x + depth, 0.0, along * half.y)
	return Vector3(half.x - depth, 0.0, along * half.y)


func _ball(parent: Node3D, radius: float, mat: Material, pos: Vector3,
		scale := Vector3.ONE) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 7
	mesh.rings = 4
	var node := _mesh(parent, mesh, mat, pos)
	node.scale = scale
	return node


# ---------------------------------------------------------------- camera life

func _process(delta: float) -> void:
	_life(delta)
	if camera == null or _busy or _peek:
		return
	_sway_t += delta
	if GameConfig.DIORAMA_PAN_ENABLED and _pan_finger < 0:
		# Eases back to centre once the finger is gone.
		_pan = move_toward(_pan, _pan_target,
			GameConfig.DIORAMA_PAN_RETURN * delta * maxf(1.0, absf(_pan) * 2.0))
	var sway := sin(_sway_t * TAU * GameConfig.DIORAMA_SWAY_HZ) \
		* deg_to_rad(GameConfig.DIORAMA_SWAY_DEG)
	_place_camera(_pan + sway)


## Everything that moves. All of it is cheap transform work on a handful of
## nodes — the town has to feel alive without costing the hub its frame rate.
func _life(delta: float) -> void:
	_life_t += delta
	# Crowns lean on the same wind the grass shader uses.
	for entry: Dictionary in _canopies:
		# Guard BEFORE the cast: casting a freed object throws in GDScript.
		if not is_instance_valid(entry["node"]):
			continue
		var node := entry["node"] as Node3D
		var phase := float(entry["phase"]) + _life_t * GameConfig.WIND_SPEED * 0.35
		node.rotation.z = sin(phase) * 0.035
		node.rotation.x = cos(phase * 0.7) * 0.022
	# Washing on the line, which is the grass sway's sibling.
	for entry: Dictionary in _cloths:
		if not is_instance_valid(entry["node"]):
			continue
		var peg := entry["node"] as Node3D
		var phase := float(entry["phase"]) + _life_t * 1.6
		peg.rotation.x = sin(phase) * 0.30
		peg.rotation.z = sin(phase * 0.6) * 0.12
	# Lantern flame: a small irregular wobble, never a clean sine, or it reads
	# as a pulsing LED instead of a flame.
	for light_any: Variant in _lamps:
		if not is_instance_valid(light_any):
			continue
		var lamp := light_any as OmniLight3D
		var base: float = lamp.get_meta("base")
		if lamp.get_meta("blink", false):
			# The mast beacon pulses instead of flickering: a slow on/off is
			# what an aircraft warning light does, and it reads from across the
			# plate where a flame's wobble would not.
			var pulse := 0.5 + 0.5 * sin(_life_t * 1.6)
			lamp.light_energy = base * (0.12 + pow(pulse, 3.0) * 1.5)
		else:
			var f := sin(_life_t * 6.1) * 0.5 + sin(_life_t * 11.3) * 0.3 \
				+ sin(_life_t * 2.7) * 0.2
			lamp.light_energy = base * (1.0 + f * 0.14)
	_fly_birds(delta)
	_walk_figures(delta)


## Two or three birds crossing now and then. Billboards on a straight line, not
## a flock simulation.
func _fly_birds(delta: float) -> void:
	_bird_timer -= delta
	if _bird_timer <= 0.0:
		_bird_timer = _rng.randf_range(7.0, 14.0)
		_launch_birds()
	for i in range(_birds.size() - 1, -1, -1):
		var bird: Dictionary = _birds[i]
		if not is_instance_valid(bird["node"]):
			_birds.remove_at(i)
			continue
		var node := bird["node"] as Node3D
		bird["t"] = float(bird["t"]) + delta
		var t := float(bird["t"])
		node.position = (bird["from"] as Vector3).lerp(bird["to"] as Vector3,
			t / float(bird["span"]))
		# A little bob, so it is not a sticker sliding across the sky.
		node.position.y += sin(t * 5.0 + float(bird["phase"])) * 0.35
		if t >= float(bird["span"]):
			node.queue_free()
			_birds.remove_at(i)


func _launch_birds() -> void:
	var half := GameConfig.DIORAMA_PLATE * 0.5
	var mat := _flat("bird", Color(0.16, 0.15, 0.17), 1.0)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var dir := 1.0 if _rng.randf() < 0.5 else -1.0
	var height := _rng.randf_range(9.0, 13.0)
	var span := _rng.randf_range(5.5, 8.0)
	var z := _rng.randf_range(-half.y * 0.7, half.y * 0.2)
	for i in _rng.randi_range(2, 3):
		var bird := Node3D.new()
		add_child(bird)
		# Two swept quads: a bird at this distance is a silhouette, nothing more.
		for wing: float in [-1.0, 1.0]:
			var quad := QuadMesh.new()
			quad.size = Vector2(0.9, 0.22)
			_mesh(bird, quad, mat, Vector3(wing * 0.45, 0.0, 0.0),
				Vector3(0.0, 0.0, wing * 0.5))
		var from := Vector3(-dir * (half.x + 6.0), height + float(i) * 0.7,
			z + float(i) * 1.4)
		_birds.append({"node": bird, "t": 0.0, "span": span,
			"phase": _rng.randf() * TAU, "from": from,
			"to": from + Vector3(dir * (GameConfig.DIORAMA_PLATE.x + 12.0), 0.0, 0.0)})
		bird.position = from


func _place_camera(yaw: float) -> void:
	var offset := _cam_base - _cam_look
	camera.position = _cam_look + offset.rotated(Vector3.UP, yaw)
	camera.look_at(_cam_look)


## Horizontal drag turns the model a little. Deliberately clamped: this is a
## thing on a table you lean around, not a camera you fly.
func on_pan_pressed(finger: int, at: Vector2) -> void:
	if not GameConfig.DIORAMA_PAN_ENABLED or _busy or _pan_finger >= 0:
		return
	_pan_finger = finger
	_pan_from = at.x


func on_pan_dragged(finger: int, at: Vector2) -> void:
	if finger != _pan_finger:
		return
	var limit := deg_to_rad(GameConfig.DIORAMA_PAN_DEG)
	_pan = clampf(deg_to_rad((at.x - _pan_from) * GameConfig.DIORAMA_PAN_PER_PIXEL),
		-limit, limit)
	_pan_target = 0.0


func on_pan_released(finger: int) -> void:
	if finger == _pan_finger:
		_pan_finger = -1


# ---------------------------------------------------------------- primitives

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


func _flat(key: String, color: Color, rough := 0.9, metal := 0.0) -> StandardMaterial3D:
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	m.metallic = metal
	_mats[key] = m
	return m


## A material that glows: lamps and lantern glass, lit even at this hour so the
## restored buildings read as inhabited.
func _glow(key: String, color: Color, energy := 1.4) -> StandardMaterial3D:
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = energy
	m.roughness = 0.4
	_mats[key] = m
	return m


func _mesh(parent: Node3D, mesh: Mesh, mat: Material, pos: Vector3,
		rot := Vector3.ZERO) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = mat
	node.position = pos
	node.rotation = rot
	parent.add_child(node)
	return node


func _box(parent: Node3D, size: Vector3, mat: Material, pos: Vector3,
		rot := Vector3.ZERO) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return _mesh(parent, mesh, mat, pos, rot)


func _cyl(parent: Node3D, r_top: float, r_bottom: float, height: float,
		mat: Material, pos: Vector3, rot := Vector3.ZERO) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = r_top
	mesh.bottom_radius = r_bottom
	mesh.height = height
	mesh.radial_segments = 10
	return _mesh(parent, mesh, mat, pos, rot)


## A soft dark blob on the ground: cheap contact shadow, and the reason SSAO
## stays off on this renderer.
func _ao_blob(parent: Node3D, size: Vector2, pos: Vector3, alpha := 0.6) -> void:
	var mesh := PlaneMesh.new()
	mesh.size = size
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = TextureLibrary.ao_radial()
	mat.albedo_color = Color(0.0, 0.0, 0.0, alpha)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.no_depth_test = false
	var node := _mesh(parent, mesh, mat, pos)
	# Never baked: welding the transparent contact shadows into one mesh threw
	# their depth sorting away and scattered black blotches over the buildings
	# (G13.7).
	node.set_meta("no_bake", true)


# ---------------------------------------------------------------- buildings

## Both forms of one building, parented to a plot node. The restored form's
## direct children are the "parts" the transition drops into place, so each
## builder keeps its restored pieces as TOP-LEVEL children — anything nested
## deeper rides along with its parent instead of landing on its own.
func _build_building(project_id: String) -> void:
	var spec: Dictionary = GameConfig.DIORAMA_BUILDINGS[project_id]
	var plot := Node3D.new()
	plot.name = project_id.capitalize()
	plot.position = spec["pos"]
	plot.rotation.y = float(spec["yaw"])
	# The buildings are authored around 3 m; on a 26x34 plate that read as
	# models on a lawn, so the whole plot is scaled up as one.
	plot.scale = Vector3.ONE * float(spec.get("scale",
		GameConfig.DIORAMA_BUILDING_SCALE))
	add_child(plot)

	var ruined := Node3D.new()
	ruined.name = "Ruined"
	plot.add_child(ruined)
	var restored := Node3D.new()
	restored.name = "Restored"
	plot.add_child(restored)

	match project_id:
		"station":
			_station_ruined(ruined)
			_station_restored(restored)
		"homes":
			_homes_ruined(ruined)
			_homes_restored(restored)
		"watchtower":
			_tower_ruined(ruined)
			_tower_restored(restored)
		"swing":
			_swing_ruined(ruined)
			_swing_restored(restored)
		"lantern":
			_lantern_ruined(ruined)
			_lantern_restored(restored)
		"greenhouse":
			_greenhouse_ruined(ruined)
			_greenhouse_restored(restored)
		"clinic":
			_clinic_ruined(ruined)
			_clinic_restored(restored)
		"mast":
			_mast_ruined(ruined)
			_mast_restored(restored)
		"farm":
			_farm_ruined(ruined)
			_farm_restored(restored)
		"barn":
			_barn_ruined(ruined)
			_barn_restored(restored)

	# Each part remembers where it belongs, so the transition can start it in
	# the air and tween it home.
	for child in restored.get_children():
		var node := child as Node3D
		if node != null:
			node.set_meta(PART_META, node.position)

	# One flat body per plot, big enough to catch a tap over the whole building.
	var touch := StaticBody3D.new()
	touch.name = "Touch"
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(4.4, 4.0, 4.4)
	shape.shape = box
	shape.position.y = 2.0
	touch.add_child(shape)
	touch.input_ray_pickable = true
	touch.input_event.connect(
		func(_cam: Node, event: InputEvent, _pos: Vector3, _n: Vector3,
				_i: int) -> void:
			if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
				building_pressed.emit(project_id))
	plot.add_child(touch)

	_buildings[project_id] = {"ruined": ruined, "restored": restored,
		"plot": plot}


## The building palette. Every surface here is a TextureLibrary texture, not a
## flat colour: siding, shingles, wood and bark are the same files the yard's
## house is built from, and they are what stops these reading as painted boxes
## (G13.1).
func _wall_mat(key: String, tint: Color) -> StandardMaterial3D:
	var mat := _tex_mat(key, "siding_albedo", tint, 0.95, Vector3(2.4, 1.6, 1.0))
	mat.albedo_color = tint
	return mat


func _roof_mat(key: String, tint: Color) -> StandardMaterial3D:
	var mat := _tex_mat(key, "roof_shingles_albedo", tint, 0.9,
		Vector3(2.2, 1.8, 1.0))
	mat.albedo_color = tint
	return mat


func _wood_mat(key: String, tint: Color) -> StandardMaterial3D:
	var mat := _tex_mat(key, "wood_albedo", tint, 0.95, Vector3(1.6, 1.0, 1.0))
	mat.albedo_color = tint
	return mat


## A window is three layers: a dark recess, the glass, and a frame around it.
## One flat blue rectangle reads as a sticker; the recess is what gives it
## depth at this camera distance.
func _window(root: Node3D, size: Vector2, at: Vector3, lit := false) -> void:
	var recess := _flat("window_dark", Color(0.06, 0.07, 0.09), 1.0)
	var glass := _glow("window_lit", Color(1.0, 0.86, 0.55), 1.1) if lit \
		else _flat("window_glass", Color(0.34, 0.44, 0.50), 0.25, 0.35)
	var frame := _wood_mat("frame_wood", Color(0.42, 0.32, 0.24))
	_box(root, Vector3(size.x, size.y, 0.06), recess,
		at - Vector3(0.0, 0.0, 0.04))
	_box(root, Vector3(size.x - 0.14, size.y - 0.14, 0.03), glass, at)
	# Four bars, not a solid border: a solid one hid the glass entirely.
	_box(root, Vector3(size.x + 0.10, 0.09, 0.08), frame,
		at + Vector3(0.0, size.y * 0.5, 0.02))
	_box(root, Vector3(size.x + 0.10, 0.09, 0.08), frame,
		at - Vector3(0.0, size.y * 0.5, -0.02))
	_box(root, Vector3(0.09, size.y + 0.10, 0.08), frame,
		at + Vector3(size.x * 0.5, 0.0, 0.02))
	_box(root, Vector3(0.09, size.y + 0.10, 0.08), frame,
		at - Vector3(size.x * 0.5, 0.0, -0.02))
	_box(root, Vector3(0.05, size.y - 0.14, 0.05), frame,
		at + Vector3(0.0, 0.0, 0.03))


## Thin green straps climbing a ruin: ivy, cheaply. Nature is halfway up the
## walls of everything nobody rebuilt.
func _ivy(root: Node3D, base: Vector3, height: float, count: int,
		seed_value: int) -> void:
	var vine := _flat("ivy", Color(0.20, 0.36, 0.16), 1.0)
	var leaf := _flat("ivy_leaf", Color(0.26, 0.46, 0.20), 1.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for i in count:
		var x := base.x + rng.randf_range(-0.9, 0.9)
		var h := height * rng.randf_range(0.45, 0.95)
		_box(root, Vector3(0.07, h, 0.05), vine,
			Vector3(x, base.y + h * 0.5, base.z),
			Vector3(0.0, 0.0, rng.randf_range(-0.10, 0.10)))
		for l in 3:
			var ly := base.y + h * (0.3 + 0.3 * float(l)) 
			_box(root, Vector3(0.20, 0.16, 0.04), leaf,
				Vector3(x + rng.randf_range(-0.18, 0.18), ly, base.z + 0.02),
				Vector3(0.0, 0.0, rng.randf_range(-0.6, 0.6)))


# ---- Marshal's station

func _station_ruined(root: Node3D) -> void:
	var wood := _wall_mat("ruin_wall", Color(0.50, 0.47, 0.42))
	var board := _wood_mat("ruin_board", Color(0.38, 0.34, 0.29))
	_box(root, Vector3(3.6, 2.2, 2.8), wood, Vector3(0.0, 1.1, 0.0))
	# The roof came down at one corner and stayed there.
	_box(root, Vector3(3.9, 0.16, 3.1), board, Vector3(0.25, 2.05, 0.1),
		Vector3(0.0, 0.0, deg_to_rad(-11.0)))
	# Boarded window: two planks nailed across the opening.
	_box(root, Vector3(1.1, 0.9, 0.06), board,
		Vector3(-0.9, 1.4, 1.42))
	_box(root, Vector3(1.4, 0.16, 0.08), wood, Vector3(-0.9, 1.55, 1.46),
		Vector3(0.0, 0.0, deg_to_rad(9.0)))
	_box(root, Vector3(1.4, 0.16, 0.08), wood, Vector3(-0.9, 1.25, 1.46),
		Vector3(0.0, 0.0, deg_to_rad(-7.0)))
	# Sign in the dirt where it fell.
	_box(root, Vector3(1.7, 0.5, 0.08), board, Vector3(1.7, 0.06, 2.0),
		Vector3(deg_to_rad(-84.0), deg_to_rad(14.0), 0.0))
	_ao_blob(root, Vector2(5.2, 4.4), Vector3(0.4, 0.03, 0.4), 0.5)


func _station_restored(root: Node3D) -> void:
	var wall := _wall_mat("station_wall", Color(0.86, 0.80, 0.68))
	var roof := _roof_mat("station_roof", Color(0.52, 0.56, 0.62))
	var trim := _wood_mat("station_trim", Color(0.56, 0.38, 0.27))
	var lamp := _glow("lamp_warm", Color(1.0, 0.86, 0.52), 2.2)
	_box(root, Vector3(3.4, 2.4, 2.6), wall, Vector3(0.0, 1.2, 0.0))
	_roof_prism(root, Vector3(0.0, 2.44, 0.0), 2.9, 0.85, roof)
	# A plain sill under the front wall instead of a porch: the porch roof sat
	# beneath the gable and the pair read as two roofs on one building.
	_box(root, Vector3(3.6, 0.14, 0.30), trim, Vector3(0.0, 0.07, 1.42))
	# Door, and the lantern beside it that says someone is in.
	_box(root, Vector3(0.9, 1.6, 0.10), trim, Vector3(0.85, 0.8, 1.33))
	_box(root, Vector3(0.20, 0.28, 0.20), lamp, Vector3(1.52, 1.68, 1.36))
	_lantern(root, Vector3(1.52, 1.68, 1.36), 2.6, 3.4)
	# Window, with the corkboard's silhouette standing behind the glass.
	_window(root, Vector2(1.3, 0.95), Vector3(-0.85, 1.45, 1.33), true)
	# STATION board over the door, upright this time.
	_box(root, Vector3(1.9, 0.48, 0.10), trim, Vector3(-0.1, 2.62, 1.20))
	_box(root, Vector3(1.5, 0.15, 0.04), wall, Vector3(-0.1, 2.62, 1.26))
	_ao_blob(root, Vector2(5.2, 4.4), Vector3(0.4, 0.03, 0.4), 0.5)


## A warm point light at a lamp, registered for the flicker in _life.
func _lantern(root: Node3D, at: Vector3, energy: float, range_m: float) -> void:
	var light := OmniLight3D.new()
	light.position = at
	light.light_color = Color(1.0, 0.86, 0.58)
	light.light_energy = energy
	light.omni_range = range_m
	light.shadow_enabled = false
	light.set_meta("base", energy)
	root.add_child(light)
	_lamps.append(light)


## Thin smoke from a chimney: the clearest single sign that somebody moved back
## in. Deliberately weak — a plume would read as a fire.
func _chimney_smoke(root: Node3D, at: Vector3) -> void:
	var puff := GPUParticles3D.new()
	puff.position = at
	puff.amount = 14
	puff.lifetime = 2.6
	puff.preprocess = 2.0
	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0.25, 1.0, 0.0)
	mat.spread = 12.0
	mat.initial_velocity_min = 0.22
	mat.initial_velocity_max = 0.42
	mat.gravity = Vector3(0.12, 0.10, 0.0)
	mat.scale_min = 0.16
	mat.scale_max = 0.46
	mat.scale_curve = _fade_curve()
	mat.color = Color(0.88, 0.87, 0.84, 0.16)
	puff.process_material = mat
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	var draw := StandardMaterial3D.new()
	# A soft radial texture, not a bare quad: an untextured billboard smoked in
	# hard-edged squares.
	draw.albedo_texture = TextureLibrary.ao_radial()
	draw.albedo_color = Color(0.94, 0.93, 0.90, 0.22)
	draw.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	draw.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	draw.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	draw.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	quad.material = draw
	puff.draw_pass_1 = quad
	root.add_child(puff)
	puff.emitting = true


## Smoke grows as it rises; one curve shared by every chimney.
func _fade_curve() -> CurveTexture:
	if _mats.has("smoke_curve"):
		return _mats["smoke_curve"]
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 0.35))
	curve.add_point(Vector2(1.0, 1.0))
	var tex := CurveTexture.new()
	tex.curve = curve
	_mats["smoke_curve"] = tex
	return tex


# ---- two homes

func _homes_ruined(root: Node3D) -> void:
	var wood := _wall_mat("ruin_wall", Color(0.50, 0.47, 0.42))
	var board := _wood_mat("ruin_board", Color(0.38, 0.34, 0.29))
	# Left hut: one wall gone, so it is three walls and a sagging roof.
	_box(root, Vector3(2.0, 1.8, 2.0), wood, Vector3(-1.5, 0.9, 0.0))
	_box(root, Vector3(0.12, 1.1, 2.0), board, Vector3(-2.5, 0.55, 0.0),
		Vector3(0.0, 0.0, deg_to_rad(14.0)))
	_box(root, Vector3(2.3, 0.14, 2.3), board, Vector3(-1.45, 1.72, 0.0),
		Vector3(deg_to_rad(6.0), 0.0, deg_to_rad(-9.0)))
	# Right hut: standing, but blind and patched.
	_box(root, Vector3(1.9, 1.7, 1.9), wood, Vector3(1.6, 0.85, 0.2))
	_box(root, Vector3(2.2, 0.14, 2.2), board, Vector3(1.6, 1.68, 0.2),
		Vector3(0.0, 0.0, deg_to_rad(5.0)))
	_box(root, Vector3(0.9, 0.8, 0.06), board, Vector3(1.6, 1.0, 1.18))
	_ivy(root, Vector3(-1.5, 0.0, 1.02), 1.7, 5, 311)
	_ivy(root, Vector3(1.6, 0.0, 0.98), 1.5, 4, 977)
	_ao_blob(root, Vector2(6.4, 4.0), Vector3(0.0, 0.03, 0.3), 0.5)


func _homes_restored(root: Node3D) -> void:
	var wall_a := _wall_mat("home_a", Color(0.90, 0.84, 0.72))
	var wall_b := _wall_mat("home_b", Color(0.78, 0.84, 0.78))
	var roof := _roof_mat("home_roof", Color(0.66, 0.36, 0.29))
	var trim := _wood_mat("home_trim", Color(0.50, 0.35, 0.26))
	_box(root, Vector3(2.0, 2.0, 2.0), wall_a, Vector3(-1.5, 1.0, 0.0))
	_roof_prism(root, Vector3(-1.5, 2.32, 0.0), 2.3, 0.7, roof)
	_box(root, Vector3(0.66, 1.2, 0.09), trim, Vector3(-1.5, 0.6, 1.02))
	_window(root, Vector2(0.62, 0.58), Vector3(-0.72, 1.42, 1.02), true)

	_box(root, Vector3(1.9, 1.9, 1.9), wall_b, Vector3(1.6, 0.95, 0.2))
	_roof_prism(root, Vector3(1.6, 2.22, 0.2), 2.2, 0.66, roof)
	_box(root, Vector3(0.62, 1.15, 0.09), trim, Vector3(1.6, 0.58, 1.18))
	_window(root, Vector2(0.60, 0.56), Vector3(0.85, 1.36, 1.18), true)

	# Chimneys, and the thin smoke that says someone is home.
	_box(root, Vector3(0.34, 0.7, 0.34), trim, Vector3(-2.05, 2.75, -0.45))
	_chimney_smoke(root, Vector3(-2.05, 3.20, -0.45))
	_box(root, Vector3(0.32, 0.62, 0.32), trim, Vector3(2.15, 2.62, -0.25))
	_chimney_smoke(root, Vector3(2.15, 3.05, -0.25))

	# The washing line between them, and the cloth on it. The cloth sways: it
	# is the sibling of the grass sway, and it is what makes the plot read as
	# lived in rather than merely repaired.
	_box(root, Vector3(2.6, 0.03, 0.03), trim, Vector3(0.05, 1.82, 0.9))
	var cloth_colours := [Color(0.90, 0.86, 0.78), Color(0.66, 0.74, 0.86),
		Color(0.88, 0.72, 0.60), Color(0.78, 0.84, 0.70)]
	var line := Node3D.new()
	line.name = "Washing"
	line.position = Vector3(0.05, 1.80, 0.9)
	root.add_child(line)
	for i in cloth_colours.size():
		var peg := Node3D.new()
		peg.position = Vector3(-1.0 + float(i) * 0.66, 0.0, 0.0)
		line.add_child(peg)
		_cloths.append({"node": peg, "phase": float(i) * 1.3})
		_box(peg, Vector3(0.44, 0.56, 0.02),
			_flat("cloth_%d" % i, cloth_colours[i], 1.0),
			Vector3(0.0, -0.30, 0.0))
	_ao_blob(root, Vector2(6.4, 4.0), Vector3(0.0, 0.03, 0.3), 0.5)


## A simple gable: two tilted slabs meeting at a ridge.
func _roof_prism(parent: Node3D, at: Vector3, span: float, rise: float,
		mat: Material) -> void:
	var slope := atan2(rise, span * 0.5)
	var length := sqrt(rise * rise + span * span * 0.25)
	for side: float in [-1.0, 1.0]:
		_box(parent, Vector3(length, 0.12, span),
			mat, at + Vector3(side * span * 0.25, rise * 0.5, 0.0),
			Vector3(0.0, 0.0, -side * slope))


# ---- watchtower

func _tower_ruined(root: Node3D) -> void:
	var wood := _wood_mat("ruin_beam", Color(0.46, 0.42, 0.36))
	var board := _wood_mat("ruin_board", Color(0.38, 0.34, 0.29))
	# The skeleton went over sideways and lies where it fell.
	var fallen := Node3D.new()
	fallen.rotation = Vector3(0.0, deg_to_rad(20.0), deg_to_rad(-78.0))
	fallen.position = Vector3(-0.6, 0.35, 0.6)
	root.add_child(fallen)
	for side: float in [-1.0, 1.0]:
		_box(fallen, Vector3(0.16, 4.2, 0.16), wood,
			Vector3(side * 0.5, 2.1, 0.0))
	for height: float in [1.2, 2.6, 3.8]:
		_box(fallen, Vector3(1.16, 0.12, 0.12), board,
			Vector3(0.0, height, 0.0))
	_box(fallen, Vector3(1.5, 0.14, 1.5), board, Vector3(0.0, 4.3, 0.0))
	# Two struts still standing, snapped off short.
	_box(root, Vector3(0.16, 1.1, 0.16), wood, Vector3(0.6, 0.55, -0.5),
		Vector3(0.0, 0.0, deg_to_rad(6.0)))
	_box(root, Vector3(0.16, 0.7, 0.16), wood, Vector3(1.0, 0.35, 0.1))
	_ivy(root, Vector3(0.4, 0.0, 0.7), 1.2, 4, 5501)
	_ao_blob(root, Vector2(5.6, 4.4), Vector3(-0.3, 0.03, 0.4), 0.5)


func _tower_restored(root: Node3D) -> void:
	var wood := _wood_mat("tower_wood", Color(0.66, 0.48, 0.30))
	var deck := _wood_mat("tower_deck", Color(0.54, 0.40, 0.27))
	var roof := _roof_mat("tower_roof", Color(0.50, 0.54, 0.60))
	var metal := _flat("tower_metal", Color(0.55, 0.57, 0.60), 0.5, 0.6)
	var beam := _glow("beacon", Color(1.0, 0.90, 0.60), 3.0)
	# Four legs, splayed slightly, braced twice.
	for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1),
			Vector2(1, 1)]:
		_box(root, Vector3(0.18, 4.2, 0.18), wood,
			Vector3(corner.x * 0.78, 2.1, corner.y * 0.78),
			Vector3(corner.y * 0.03, 0.0, -corner.x * 0.03))
	for height: float in [1.3, 2.8]:
		_box(root, Vector3(1.75, 0.12, 0.12), deck,
			Vector3(0.0, height, -0.78))
		_box(root, Vector3(1.75, 0.12, 0.12), deck,
			Vector3(0.0, height, 0.78))
		_box(root, Vector3(0.12, 0.12, 1.75), deck,
			Vector3(-0.78, height, 0.0))
		_box(root, Vector3(0.12, 0.12, 1.75), deck,
			Vector3(0.78, height, 0.0))
	# Platform, rail, roof.
	_box(root, Vector3(2.3, 0.14, 2.3), deck, Vector3(0.0, 4.25, 0.0))
	for side: Vector3 in [Vector3(0, 0, -1.15), Vector3(0, 0, 1.15),
			Vector3(-1.15, 0, 0), Vector3(1.15, 0, 0)]:
		var along := Vector3(2.4, 0.10, 0.10) if absf(side.z) > 0.0 \
			else Vector3(0.10, 0.10, 2.4)
		_box(root, along, deck, Vector3(0.0, 4.72, 0.0) + side)
	_box(root, Vector3(2.5, 0.14, 2.5), roof, Vector3(0.0, 5.45, 0.0))
	for corner: Vector2 in [Vector2(-1, -1), Vector2(1, 1)]:
		_box(root, Vector3(0.10, 0.75, 0.10), deck,
			Vector3(corner.x * 1.02, 5.10, corner.y * 1.02))
	# The beacon on top, and the glass turned east toward the road out.
	_cyl(root, 0.26, 0.26, 0.34, beam, Vector3(0.0, 5.70, 0.0))
	_lantern(root, Vector3(0.0, 5.70, 0.0), 4.5, 7.0)
	_cyl(root, 0.10, 0.10, 0.55, metal, Vector3(0.92, 4.65, 0.0),
		Vector3(0.0, 0.0, deg_to_rad(90.0)))
	_ao_blob(root, Vector2(5.6, 4.4), Vector3(-0.3, 0.03, 0.4), 0.5)


# ---------------------------------------------------------------- restoration

## The moment the money turns into a building (G13 §3).
##
## Camera pushes in, the ruin drops and puffs, then the restored parts come
## down from above one at a time, each with a tick and a puff of dust, then the
## whole thing flashes and the camera pulls back. Awaited, so the caller knows
## when the hub can be touched again. `skip()` cuts it short at any point.
func play_restore(project_id: String) -> void:
	var pair: Dictionary = _buildings.get(project_id, {})
	if pair.is_empty() or _busy:
		set_built(project_id, true, false)
		return
	_busy = true
	_skipped = false
	var plot: Node3D = pair["plot"]
	var ruined: Node3D = pair["ruined"]
	var restored: Node3D = pair["restored"]

	var parts: Array = []
	for child in restored.get_children():
		var node := child as Node3D
		if node != null and node.has_meta(PART_META):
			parts.append(node)
	# Ground up: a building that assembles roof-first reads as falling apart in
	# reverse. Sorting by resting height is what makes it read as construction.
	parts.sort_custom(func(a: Node3D, b: Node3D) -> bool:
		return (a.get_meta(PART_META) as Vector3).y < (b.get_meta(PART_META) as Vector3).y)

	await _zoom_to(plot.position, GameConfig.RESTORE_ZOOM_IN)
	await _collapse(ruined)
	ruined.visible = false
	restored.visible = true
	await _raise(parts)
	await _flash(restored)
	await _zoom_home(GameConfig.RESTORE_ZOOM_OUT)

	set_built(project_id, true, false)
	# The parts have finished moving, so this building can be welded now.
	_bake_static()
	_busy = false
	Analytics.track(
		AnalyticsEvents.RESTORE_ANIMATION_SKIPPED if _skipped else AnalyticsEvents.RESTORE_ANIMATION_WATCHED,
		{"id": project_id})


## A tap anywhere during the transition cuts to the end. The tweens check this
## between steps, so the scene never ends up half-built.
func skip() -> void:
	if _busy:
		_skipped = true


var _skipped := false


func _zoom_to(at: Vector3, seconds: float) -> void:
	if _skipped:
		return
	var focus := at + Vector3(0.0, 1.5, 0.0)
	# Straight in along the LINE THE CAMERA ALREADY LOOKS DOWN, not along the
	# line from the square outward. The outward version swung round to whichever
	# side of the plate the building sat on and ended up behind it.
	var dir := (_cam_base - _cam_look).normalized()
	var eye := focus + dir * GameConfig.RESTORE_CAM_DISTANCE
	await _fly(eye, focus, seconds, 0.0)


func _zoom_home(seconds: float) -> void:
	await _fly(_cam_base, _cam_look, seconds, GameConfig.DIORAMA_V_OFFSET)


func _fly(eye: Vector3, look: Vector3, seconds: float, v_offset := 0.0) -> void:
	var from_eye := camera.position
	var from_look := _look_point()
	var from_v := camera.v_offset
	var elapsed := 0.0
	while elapsed < seconds and not _skipped:
		elapsed += get_process_delta_time()
		var k := ease(clampf(elapsed / seconds, 0.0, 1.0), 0.4)
		camera.position = from_eye.lerp(eye, k)
		camera.look_at(from_look.lerp(look, k))
		# The hub shifts the frustum up to clear its cards; a close-up must undo
		# that, or the building it flew to sits off the top of the screen.
		camera.v_offset = lerpf(from_v, v_offset, k)
		await get_tree().process_frame
	camera.position = eye
	camera.look_at(look)
	camera.v_offset = v_offset


## Where the camera is pointed right now, so a fly can start from it.
func _look_point() -> Vector3:
	return camera.position - camera.global_transform.basis.z * 10.0


func _collapse(ruined: Node3D) -> void:
	if _skipped:
		ruined.visible = false
		return
	var seconds := GameConfig.RESTORE_COLLAPSE
	var elapsed := 0.0
	var start := ruined.position
	_dust(ruined.get_parent() as Node3D, Vector3(0.0, 0.4, 0.0), 1.8)
	AudioDirector.play_cut()
	while elapsed < seconds and not _skipped:
		elapsed += get_process_delta_time()
		var k := clampf(elapsed / seconds, 0.0, 1.0)
		# Sinks and flattens: the ruin goes back into the ground it came from.
		ruined.position = start + Vector3(0.0, -1.2 * k * k, 0.0)
		ruined.scale = Vector3(1.0 + 0.10 * k, maxf(0.02, 1.0 - k), 1.0 + 0.10 * k)
		await get_tree().process_frame
	ruined.position = start
	ruined.scale = Vector3.ONE


## Parts fall in from above, one every RESTORE_PART_GAP seconds, each landing
## with a tick and a small puff.
func _raise(parts: Array) -> void:
	# Spread the parts across a fixed span rather than a fixed gap each, so a
	# thirty-part greenhouse takes as long as an eight-part lantern.
	var gap := minf(GameConfig.RESTORE_PART_GAP,
		GameConfig.RESTORE_RAISE_SECONDS / maxf(1.0, float(parts.size())))
	for i in parts.size():
		if _skipped:
			break
		var part: Node3D = parts[i]
		var rest: Vector3 = part.get_meta(PART_META)
		part.position = rest + Vector3(0.0, GameConfig.RESTORE_PART_RISE, 0.0)
		# .call, not a plain call: _drop_part is a coroutine, and this one has to
		# run alongside the others rather than blocking the next part's start.
		_drop_part.call(part, rest)
		var waited := 0.0
		while waited < gap and not _skipped:
			waited += get_process_delta_time()
			await get_tree().process_frame
	# Let the last few finish their fall before the flash.
	var tail := 0.0
	while tail < GameConfig.RESTORE_PART_FALL and not _skipped:
		tail += get_process_delta_time()
		await get_tree().process_frame
	for part_any: Variant in parts:
		var node := part_any as Node3D
		node.position = node.get_meta(PART_META)


func _drop_part(part: Node3D, rest: Vector3) -> void:
	var seconds := GameConfig.RESTORE_PART_FALL
	var from := part.position
	var elapsed := 0.0
	while elapsed < seconds and not _skipped:
		elapsed += get_process_delta_time()
		var k := clampf(elapsed / seconds, 0.0, 1.0)
		# Accelerating fall, then a small settle: linear looked like a lift.
		part.position = from.lerp(rest, k * k)
		await get_tree().process_frame
	part.position = rest
	if not _skipped:
		AudioDirector.play_scrap()
		_dust(part.get_parent() as Node3D, rest, 0.7)


## The "it is done" beat: a warm light blooms inside the finished building and
## fades. A tint would mean touching the shared materials in _mats, which every
## other building draws with — this only touches one node.
func _flash(restored: Node3D) -> void:
	AudioDirector.play_discovery()
	Haptics.success()
	if _skipped:
		return
	var bloom := OmniLight3D.new()
	bloom.light_color = Color(1.0, 0.92, 0.70)
	bloom.omni_range = 7.0
	bloom.position = Vector3(0.0, 1.8, 0.0)
	restored.add_child(bloom)
	var seconds := GameConfig.RESTORE_SHINE
	var elapsed := 0.0
	while elapsed < seconds and not _skipped:
		elapsed += get_process_delta_time()
		var k := 1.0 - clampf(elapsed / seconds, 0.0, 1.0)
		bloom.light_energy = 6.0 * k
		await get_tree().process_frame
	bloom.queue_free()


## A short-lived puff of pale dust. Deliberately tiny: this is punctuation for
## a part landing, not weather.
##
## The process material and the draw mesh are built ONCE and shared. A restore
## calls this a dozen times, and building four fresh resources per call meant a
## fresh particle shader variant each time (G13.4). Per-puff size lives on the
## NODE's scale instead, so no clone is needed.
func _dust(parent: Node3D, at: Vector3, scale := 1.0) -> void:
	if parent == null:
		return
	var puff := GPUParticles3D.new()
	puff.position = at
	puff.amount = 10
	puff.lifetime = 0.5
	puff.one_shot = true
	puff.explosiveness = 0.95
	puff.process_material = _dust_process()
	puff.draw_pass_1 = _dust_quad()
	puff.scale = Vector3.ONE * scale
	parent.add_child(puff)
	puff.emitting = true
	puff.finished.connect(puff.queue_free)


func _dust_process() -> ParticleProcessMaterial:
	if _mats.has("dust_process"):
		return _mats["dust_process"]
	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0.0, 1.0, 0.0)
	mat.spread = 55.0
	mat.initial_velocity_min = 0.4
	mat.initial_velocity_max = 1.1
	mat.gravity = Vector3(0.0, -1.2, 0.0)
	mat.scale_min = 0.12
	mat.scale_max = 0.3
	mat.color = Color(0.82, 0.76, 0.66, 0.75)
	_mats["dust_process"] = mat
	return mat


func _dust_quad() -> QuadMesh:
	if _mats.has("dust_quad"):
		return _mats["dust_quad"]
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	var draw := StandardMaterial3D.new()
	# A soft radial texture, so a puff is a cloud rather than a hard square.
	draw.albedo_texture = TextureLibrary.ao_radial()
	draw.albedo_color = Color(0.86, 0.80, 0.70, 0.8)
	draw.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	draw.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	draw.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	quad.material = draw
	_mats["dust_quad"] = quad
	return quad


## Hills and rooftops past the rim, sunk in haze. Without them the plate ends
## at a blank wall of fog and the town reads as an island (G13.1).
func _build_horizon() -> void:
	Horizon.build(self, GameConfig.DIORAMA_PLATE.length() * 0.86, 20260826,
		true, GameConfig.DIORAMA_COUNTRY)
	# The hub is where the sky is actually ON SCREEN — a third of the frame,
	# against five degrees in a yard. Clouds and birds earn their place here
	# first (G14.2).
	_build_sky_life()
	var ring := get_node_or_null("Horizon") as Node3D
	if ring != null:
		_bake_targets.append(ring)


# ---------------------------------------------------------------- the field

## Long grass across the plate, from the SAME clump meshes and the same wind
## shader the yard uses (TuftField.cluster_mesh). Sparse in the open, thick at
## the foot of every ruin: nature took the town back while nobody was here.
## Rebuilding a plot clears its weeds — see set_built (G13.1).
func _build_tufts() -> void:
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/grass_clump.gdshader")
	mat.set_shader_parameter("wind_amplitude", GameConfig.WIND_AMPLITUDE * 1.4)
	mat.set_shader_parameter("wind_speed", GameConfig.WIND_SPEED)

	var variants := GameConfig.clump_variants().size()
	for v in variants:
		var mesh_rng := RandomNumberGenerator.new()
		mesh_rng.seed = 4801 + v * 7919
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = TuftField.cluster_mesh(mesh_rng, v)
		mm.instance_count = 0
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "TuftVariant%d" % v
		mmi.multimesh = mm
		mmi.material_override = mat
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mmi)
		_tuft_meshes.append(mm)

	_scatter_tufts()


## Decides where every clump stands. Each one remembers which plot's overgrowth
## it belongs to (or "" for the open field), so clearing a plot is a rewrite of
## the transform list rather than a rebuild.
func _scatter_tufts() -> void:
	_tuft_spots.clear()
	var half := GameConfig.DIORAMA_PLATE * 0.5 - Vector2.ONE * GameConfig.DIORAMA_BEVEL
	var step := GameConfig.DIORAMA_TUFT_SPACING
	var rng := RandomNumberGenerator.new()
	rng.seed = 91117

	var x := -half.x
	while x <= half.x:
		var z := -half.y
		while z <= half.y:
			var at := Vector3(x + rng.randf_range(-1.0, 1.0) * GameConfig.DIORAMA_TUFT_JITTER,
				0.0, z + rng.randf_range(-1.0, 1.0) * GameConfig.DIORAMA_TUFT_JITTER)
			z += step
			if not _open_ground(at):
				continue
			# Thinned out in the open so the plate reads as mown-ish ground with
			# grass coming through, not a meadow.
			if rng.randf() > 0.80:
				continue
			_tuft_spots.append({"at": at, "owner": "",
				"scale": rng.randf_range(0.46, 0.8), "yaw": rng.randf() * TAU,
				"variant": rng.randi_range(0, _tuft_meshes.size() - 1)})
		x += step

	# The overgrowth rings: dense, taller, and owned by their building.
	for id: String in GameConfig.DIORAMA_BUILDINGS:
		var spot: Vector3 = GameConfig.DIORAMA_BUILDINGS[id]["pos"]
		for _i in GameConfig.DIORAMA_OVERGROWTH_COUNT:
			var a := rng.randf() * TAU
			var r := sqrt(rng.randf()) * GameConfig.DIORAMA_OVERGROWTH_RADIUS
			var at := spot + Vector3(cos(a) * r, 0.0, sin(a) * r)
			if absf(at.x) > half.x or absf(at.z) > half.y:
				continue
			_tuft_spots.append({"at": at, "owner": id,
				"scale": rng.randf_range(0.75, 1.2), "yaw": rng.randf() * TAU,
				"variant": rng.randi_range(0, _tuft_meshes.size() - 1)})
	# NOT written here: refresh_state() runs next and writes them once the
	# cleared plots are known. Writing now showed every clump for a frame and
	# then dropped the cleared ones — the town flashed overgrown on entry.


## True once the plot this clump belongs to — or simply stands near — has been
## rebuilt. Clearing only the clumps TAGGED to a plot was not visible: the
## open-field grass around a finished house kept the yard looking abandoned.
func _is_cleared_ground(spot: Dictionary) -> bool:
	var owner_id := str(spot["owner"])
	if owner_id != "" and _cleared.has(owner_id):
		return true
	var at: Vector3 = spot["at"]
	for id: Variant in _cleared:
		var plot: Vector3 = GameConfig.DIORAMA_BUILDINGS[id]["pos"]
		if at.distance_to(plot) < GameConfig.DIORAMA_OVERGROWTH_RADIUS:
			return true
	return false


## Keeps grass off the paving and off the paths.
func _open_ground(at: Vector3) -> bool:
	if Vector2(at.x, at.z).length() < GameConfig.DIORAMA_SQUARE_RADIUS:
		return false
	for id: String in GameConfig.DIORAMA_BUILDINGS:
		var spot: Vector3 = GameConfig.DIORAMA_BUILDINGS[id]["pos"]
		var to := Vector2(spot.x, spot.z)
		# Distance from the path's centre line, which runs square -> building.
		var point := Vector2(at.x, at.z)
		var k := clampf(point.dot(to.normalized()) / to.length(), 0.0, 1.0)
		if point.distance_to(to * k) < 1.1:
			return false
	return true


## Pushes the surviving clumps into the MultiMeshes. A clump whose owner has
## been rebuilt is simply not written.
func _write_tufts() -> void:
	var per_variant: Array = []
	for _v in _tuft_meshes.size():
		per_variant.append([])
	for spot: Dictionary in _tuft_spots:
		if _is_cleared_ground(spot):
			continue
		per_variant[int(spot["variant"])].append(spot)
	for v in _tuft_meshes.size():
		var list: Array = per_variant[v]
		var mm: MultiMesh = _tuft_meshes[v]
		mm.instance_count = list.size()
		for i in list.size():
			var spot: Dictionary = list[i]
			var basis := Basis(Vector3.UP, float(spot["yaw"])).scaled(
				Vector3.ONE * float(spot["scale"]))
			mm.set_instance_transform(i, Transform3D(basis, spot["at"]))
			var shade := 0.82 + fmod(float(i) * 0.137, 0.34)
			mm.set_instance_color(i, Color(shade, shade, shade))


# ---------------------------------------------------------------- swing (G13.5)

## Ellie's swing hangs from the oak's thick limb, so "ruined" is the limb with
## nothing on it — a bare branch reads as absence better than a broken swing.
func _swing_ruined(root: Node3D) -> void:
	var rope := _flat("old_rope", Color(0.44, 0.40, 0.32), 1.0)
	# One frayed end still knotted round the limb: someone took it down.
	_cyl(root, 0.035, 0.035, 0.62, rope, Vector3(1.60, 4.30, 0.30),
		Vector3(0.14, 0.0, 0.05))


func _swing_restored(root: Node3D) -> void:
	var rope := _flat("rope", Color(0.76, 0.68, 0.50), 1.0)
	var plank := _wood_mat("swing_seat", Color(0.62, 0.45, 0.29))
	var ribbon := _flat("ribbon", Color(0.94, 0.82, 0.34), 0.9)
	# Two ropes down from the limb, a seat across them, and the yellow ribbon
	# from the case tied to one rope — the swing is Ellie's, and it says so.
	for side: float in [-0.36, 0.36]:
		_cyl(root, 0.035, 0.035, 2.60, rope,
			Vector3(1.60 + side, 3.20, 0.30))
	_box(root, Vector3(0.94, 0.09, 0.34), plank, Vector3(1.60, 1.92, 0.30))
	# The yellow ribbon from the case, knotted on the near rope.
	_box(root, Vector3(0.08, 0.30, 0.06), ribbon, Vector3(1.24, 3.50, 0.31),
		Vector3(0.0, 0.0, 0.30))
	_box(root, Vector3(0.24, 0.08, 0.06), ribbon, Vector3(1.30, 3.38, 0.31),
		Vector3(0.0, 0.0, -0.5))


# ---------------------------------------------------------------- lantern

func _lantern_ruined(root: Node3D) -> void:
	var iron := _flat("old_iron", Color(0.30, 0.29, 0.27), 0.9, 0.2)
	var glass := _flat("broken_glass", Color(0.34, 0.38, 0.36), 0.4, 0.2)
	# Snapped off at the base and lying where it fell.
	_cyl(root, 0.07, 0.10, 2.6, iron, Vector3(0.9, 0.16, 0.5),
		Vector3(0.0, 0.4, deg_to_rad(84.0)))
	_box(root, Vector3(0.32, 0.36, 0.32), glass, Vector3(2.1, 0.20, 0.7),
		Vector3(0.3, 0.4, 0.2))
	_cyl(root, 0.16, 0.20, 0.22, iron, Vector3(0.0, 0.11, 0.0))
	_ao_blob(root, Vector2(2.6, 2.0), Vector3(0.9, 0.03, 0.4), 0.45)


func _lantern_restored(root: Node3D) -> void:
	var iron := _flat("iron_post", Color(0.20, 0.20, 0.22), 0.8, 0.35)
	var glow := _glow("lamp_warm", Color(1.0, 0.86, 0.52), 2.2)
	_cyl(root, 0.16, 0.24, 0.26, iron, Vector3(0.0, 0.13, 0.0))
	_cyl(root, 0.06, 0.09, 3.0, iron, Vector3(0.0, 1.60, 0.0))
	# A little cross-arm and the lamp box under it.
	_box(root, Vector3(0.44, 0.06, 0.06), iron, Vector3(0.0, 3.06, 0.0))
	_box(root, Vector3(0.30, 0.38, 0.30), glow, Vector3(0.0, 2.82, 0.0))
	_box(root, Vector3(0.38, 0.08, 0.38), iron, Vector3(0.0, 3.04, 0.0))
	_lantern(root, Vector3(0.0, 2.82, 0.0), 3.4, 6.5)
	# The pool of light on the paving: a flat unshaded disc, because a real
	# light cannot show its own falloff on the ground at this camera distance.
	var pool := CylinderMesh.new()
	pool.top_radius = 2.4
	pool.bottom_radius = 2.4
	pool.height = 0.02
	pool.radial_segments = 18
	var pool_mat := StandardMaterial3D.new()
	pool_mat.albedo_texture = TextureLibrary.ao_radial()
	pool_mat.albedo_color = Color(1.0, 0.84, 0.50, 0.30)
	pool_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	pool_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	pool_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mesh(root, pool, pool_mat, Vector3(0.0, 0.06, 0.0))


# ---------------------------------------------------------------- greenhouse

func _greenhouse_ruined(root: Node3D) -> void:
	var frame := _wood_mat("gh_frame_old", Color(0.42, 0.38, 0.32))
	var shard := _flat("gh_shard", Color(0.40, 0.46, 0.44), 0.35, 0.15)
	# A leaning frame with most of its glass gone: four uprights out of true,
	# two ribs, and three panes still in place.
	for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1),
			Vector2(1, 1)]:
		_box(root, Vector3(0.10, 1.9, 0.10), frame,
			Vector3(corner.x * 0.95, 0.95, corner.y * 1.35),
			Vector3(corner.y * 0.10, 0.0, corner.x * 0.12))
	_box(root, Vector3(2.1, 0.09, 0.09), frame, Vector3(0.0, 1.86, -1.35),
		Vector3(0.0, 0.0, 0.10))
	_box(root, Vector3(2.1, 0.09, 0.09), frame, Vector3(0.0, 1.80, 1.35),
		Vector3(0.0, 0.0, -0.06))
	_box(root, Vector3(0.05, 1.1, 0.9), shard, Vector3(-0.95, 1.0, -0.7))
	_box(root, Vector3(0.05, 0.7, 0.8), shard, Vector3(0.95, 0.7, 0.6))
	_box(root, Vector3(1.2, 0.05, 0.7), shard, Vector3(-0.2, 0.04, 0.4),
		Vector3(0.0, 0.4, 0.0))
	_ivy(root, Vector3(0.0, 0.0, 1.40), 1.3, 4, 7717)
	_ao_blob(root, Vector2(4.2, 3.6), Vector3(0.2, 0.03, 0.3), 0.5)


func _greenhouse_restored(root: Node3D) -> void:
	var frame := _wood_mat("gh_frame", Color(0.60, 0.44, 0.30))
	var glass := _flat("gh_glass", Color(0.62, 0.78, 0.74, 0.42), 0.15, 0.1)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var old_glass := _flat("gh_glass_old", Color(0.50, 0.60, 0.56, 0.48), 0.3, 0.1)
	old_glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var soil := _flat("gh_soil", Color(0.32, 0.24, 0.17), 1.0)
	var sprout := _flat("gh_sprout", Color(0.36, 0.62, 0.26), 1.0)

	for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1),
			Vector2(1, 1)]:
		_box(root, Vector3(0.10, 2.0, 0.10), frame,
			Vector3(corner.x * 0.95, 1.0, corner.y * 1.35))
	# Walls: new panes and salvaged ones side by side, which is the story of
	# this town rebuilding out of what it still has.
	for i in 3:
		var z := -0.9 + float(i) * 0.9
		_box(root, Vector3(0.04, 1.9, 0.82), glass if i != 1 else old_glass,
			Vector3(-0.95, 0.98, z))
		_box(root, Vector3(0.04, 1.9, 0.82), old_glass if i != 1 else glass,
			Vector3(0.95, 0.98, z))
	_box(root, Vector3(1.86, 1.9, 0.04), glass, Vector3(0.0, 0.98, -1.35))
	_box(root, Vector3(1.86, 1.9, 0.04), old_glass, Vector3(0.0, 0.98, 1.35))
	_roof_prism(root, Vector3(0.0, 2.02, 0.0), 2.1, 0.55, glass)
	# Seedling beds, read through the glass: two soil rows with small green
	# blocks in them. This is what makes it a WORKING greenhouse and not a box.
	for row: float in [-0.45, 0.45]:
		_box(root, Vector3(0.66, 0.22, 2.2), soil, Vector3(row, 0.11, 0.0))
		for i in 7:
			_box(root, Vector3(0.14, 0.26, 0.14), sprout,
				Vector3(row + (0.12 if i % 2 == 0 else -0.12), 0.34,
					-0.95 + float(i) * 0.32))
	_ao_blob(root, Vector2(4.2, 3.6), Vector3(0.2, 0.03, 0.3), 0.5)


# ---------------------------------------------------------------- clinic

func _clinic_ruined(root: Node3D) -> void:
	var wall := _wall_mat("ruin_wall", Color(0.50, 0.47, 0.42))
	var board := _wood_mat("ruin_board", Color(0.38, 0.34, 0.29))
	_box(root, Vector3(2.8, 2.0, 2.4), wall, Vector3(0.0, 1.0, 0.0))
	_roof_prism(root, Vector3(0.0, 2.02, 0.0), 2.6, 0.5, board)
	# Boarded door, no sign, no supplies: a house nobody practises in.
	_box(root, Vector3(0.9, 1.5, 0.06), board, Vector3(0.2, 0.75, 1.22))
	_box(root, Vector3(1.2, 0.14, 0.08), board, Vector3(0.2, 1.05, 1.26),
		Vector3(0.0, 0.0, deg_to_rad(8.0)))
	# The veranda that has collapsed at one end.
	_box(root, Vector3(3.0, 0.10, 1.0), board, Vector3(0.0, 0.34, 1.85),
		Vector3(0.0, 0.0, deg_to_rad(-7.0)))
	_box(root, Vector3(0.10, 0.62, 0.10), board, Vector3(-1.35, 0.31, 2.25))
	_ivy(root, Vector3(-0.9, 0.0, 1.22), 1.5, 4, 4242)
	_ao_blob(root, Vector2(4.6, 4.0), Vector3(0.2, 0.03, 0.6), 0.5)


func _clinic_restored(root: Node3D) -> void:
	var wall := _wall_mat("clinic_wall", Color(0.90, 0.88, 0.82))
	var roof := _roof_mat("clinic_roof", Color(0.48, 0.50, 0.54))
	var trim := _wood_mat("clinic_trim", Color(0.54, 0.38, 0.27))
	var cross := _flat("clinic_cross", Color(0.74, 0.20, 0.18), 0.9)
	var sign := _flat("clinic_sign", Color(0.92, 0.90, 0.84), 0.9)
	var crate := _wood_mat("clinic_crate", Color(0.64, 0.52, 0.36))
	_box(root, Vector3(2.8, 2.1, 2.4), wall, Vector3(0.0, 1.05, 0.0))
	_roof_prism(root, Vector3(0.0, 2.12, 0.0), 2.6, 0.62, roof)
	_box(root, Vector3(0.86, 1.6, 0.10), trim, Vector3(0.2, 0.80, 1.22))
	_window(root, Vector2(0.9, 0.8), Vector3(-0.85, 1.35, 1.22), true)
	# The veranda, level this time, on four posts.
	_box(root, Vector3(3.0, 0.12, 1.1), trim, Vector3(0.0, 0.36, 1.92))
	for post_x: float in [-1.35, 1.35]:
		_box(root, Vector3(0.10, 0.36, 0.10), trim, Vector3(post_x, 0.18, 2.38))
	# The hand-painted sign: a white board with a red cross on it.
	_box(root, Vector3(1.1, 0.9, 0.07), sign, Vector3(-0.05, 2.35, 1.05))
	_box(root, Vector3(0.62, 0.18, 0.04), cross, Vector3(-0.05, 2.35, 1.10))
	_box(root, Vector3(0.18, 0.62, 0.04), cross, Vector3(-0.05, 2.35, 1.10))
	# Supply crates on the veranda: the clinic is stocked.
	_box(root, Vector3(0.5, 0.42, 0.5), crate, Vector3(1.05, 0.63, 1.95),
		Vector3(0.0, 0.3, 0.0))
	_box(root, Vector3(0.42, 0.36, 0.42), crate, Vector3(1.15, 1.02, 1.90),
		Vector3(0.0, -0.2, 0.0))
	_ao_blob(root, Vector2(4.6, 4.0), Vector3(0.2, 0.03, 0.6), 0.5)


# ---------------------------------------------------------------- radio mast

func _mast_ruined(root: Node3D) -> void:
	var steel := _flat("mast_old", Color(0.36, 0.35, 0.33), 0.85, 0.3)
	# The lattice went over and lies in the grass, still bolted at the foot.
	var fallen := Node3D.new()
	fallen.position = Vector3(0.0, 0.30, 0.0)
	fallen.rotation = Vector3(0.0, deg_to_rad(28.0), deg_to_rad(-82.0))
	root.add_child(fallen)
	for side: float in [-1.0, 1.0]:
		_box(fallen, Vector3(0.10, 5.4, 0.10), steel,
			Vector3(side * 0.32, 2.7, 0.0))
	for i in 6:
		# Cross bracing: alternating diagonals, which is what makes a lattice
		# read as a lattice rather than a ladder.
		_box(fallen, Vector3(0.78, 0.07, 0.07), steel,
			Vector3(0.0, 0.6 + float(i) * 0.9, 0.0),
			Vector3(0.0, 0.0, deg_to_rad(38.0 if i % 2 == 0 else -38.0)))
	_box(root, Vector3(0.7, 0.24, 0.7), steel, Vector3(0.0, 0.12, 0.0))
	_ao_blob(root, Vector2(5.0, 3.4), Vector3(1.2, 0.03, 0.2), 0.45)


func _mast_restored(root: Node3D) -> void:
	var steel := _flat("mast_steel", Color(0.58, 0.58, 0.60), 0.6, 0.5)
	var hut_wall := _wall_mat("mast_hut", Color(0.74, 0.72, 0.64))
	var hut_roof := _roof_mat("mast_hut_roof", Color(0.44, 0.46, 0.50))
	var cable := _flat("cable", Color(0.16, 0.16, 0.18), 0.9)
	_box(root, Vector3(0.8, 0.26, 0.8), steel, Vector3(0.0, 0.13, 0.0))
	for side: float in [-1.0, 1.0]:
		_box(root, Vector3(0.10, 5.6, 0.10), steel,
			Vector3(side * 0.30, 2.9, 0.0), Vector3(0.0, 0.0, side * 0.012))
		_box(root, Vector3(0.10, 5.6, 0.10), steel,
			Vector3(0.0, 2.9, side * 0.30), Vector3(side * 0.012, 0.0, 0.0))
	for i in 7:
		_box(root, Vector3(0.74, 0.06, 0.06), steel,
			Vector3(0.0, 0.7 + float(i) * 0.78, 0.30),
			Vector3(0.0, 0.0, deg_to_rad(36.0 if i % 2 == 0 else -36.0)))
		_box(root, Vector3(0.06, 0.06, 0.74), steel,
			Vector3(0.30, 0.7 + float(i) * 0.78, 0.0),
			Vector3(deg_to_rad(36.0 if i % 2 == 0 else -36.0), 0.0, 0.0))
	# The beacon, which blinks slowly in _life rather than glowing steadily.
	var beacon := _glow("mast_beacon", Color(1.0, 0.24, 0.20), 3.0)
	_cyl(root, 0.13, 0.13, 0.22, beacon, Vector3(0.0, 5.85, 0.0))
	var light := OmniLight3D.new()
	light.position = Vector3(0.0, 5.85, 0.0)
	light.light_color = Color(1.0, 0.30, 0.24)
	light.light_energy = 2.4
	light.omni_range = 5.0
	light.shadow_enabled = false
	light.set_meta("base", 2.4)
	light.set_meta("blink", true)
	root.add_child(light)
	_lamps.append(light)
	# The hut at its foot, and the cable running down into it.
	_box(root, Vector3(1.5, 1.2, 1.3), hut_wall, Vector3(1.55, 0.60, 0.55))
	_roof_prism(root, Vector3(1.55, 1.22, 0.55), 1.6, 0.36, hut_roof)
	_box(root, Vector3(0.42, 0.8, 0.06), _wood_mat("mast_door",
		Color(0.46, 0.33, 0.24)), Vector3(1.55, 0.40, 1.22))
	for i in 5:
		# The cable sags from the mast to the hut roof in five short segments.
		var k := float(i) / 4.0
		var sag := sin(k * PI) * 0.28
		_box(root, Vector3(0.05, 0.05, 0.42), cable,
			Vector3(lerpf(0.16, 1.55, k), lerpf(4.4, 1.5, k) - sag,
				lerpf(0.0, 0.40, k)),
			Vector3(deg_to_rad(-58.0 + k * 20.0), 0.0, 0.0))
	_ao_blob(root, Vector2(5.0, 3.8), Vector3(0.9, 0.03, 0.3), 0.5)


# ---------------------------------------------------------------- farm

func _farm_ruined(root: Node3D) -> void:
	var post := _wood_mat("farm_post_old", Color(0.40, 0.36, 0.30))
	var weed := _flat("farm_weed", Color(0.42, 0.46, 0.26), 1.0)
	var soil := _flat("farm_soil_old", Color(0.36, 0.31, 0.24), 1.0)
	# Three beds gone back to weed, and a fence with half its posts down.
	for bed in 3:
		var z := -1.6 + float(bed) * 1.6
		_box(root, Vector3(3.2, 0.14, 1.0), soil, Vector3(0.0, 0.07, z))
		for i in 5:
			_box(root, Vector3(0.22, 0.42, 0.20), weed,
				Vector3(-1.3 + float(i) * 0.65, 0.30,
					z + (0.22 if i % 2 == 0 else -0.18)),
				Vector3(0.12, float(i), 0.10))
	for i in 6:
		var x := -2.1 + float(i) * 0.84
		var down := i % 3 == 1
		_box(root, Vector3(0.09, 0.9, 0.09), post,
			Vector3(x, 0.14 if down else 0.45, 2.6),
			Vector3(deg_to_rad(78.0) if down else 0.0, 0.0, 0.0))
	_ao_blob(root, Vector2(6.0, 5.0), Vector3(0.0, 0.03, 0.2), 0.4)


func _farm_restored(root: Node3D) -> void:
	var post := _wood_mat("farm_post", Color(0.62, 0.46, 0.30))
	var soil := _flat("farm_soil", Color(0.30, 0.22, 0.15), 1.0)
	var crop := _flat("farm_crop", Color(0.40, 0.66, 0.28), 1.0)
	var stone := _flat("well_stone", Color(0.56, 0.54, 0.50), 0.95)
	var cloth := _flat("scare_cloth", Color(0.70, 0.36, 0.30), 1.0)
	var straw := _flat("scare_straw", Color(0.72, 0.62, 0.32), 1.0)
	# Three worked beds in neat rows.
	for bed in 3:
		var z := -1.6 + float(bed) * 1.6
		_box(root, Vector3(3.2, 0.18, 1.0), soil, Vector3(0.0, 0.09, z))
		for i in 8:
			_box(root, Vector3(0.18, 0.40, 0.18), crop,
				Vector3(-1.4 + float(i) * 0.40, 0.36, z - 0.22))
			_box(root, Vector3(0.18, 0.34, 0.18), crop,
				Vector3(-1.4 + float(i) * 0.40, 0.33, z + 0.22))
	# A fence that stands, all the way along.
	for i in 6:
		var x := -2.1 + float(i) * 0.84
		_box(root, Vector3(0.09, 0.95, 0.09), post, Vector3(x, 0.47, 2.6))
	for rail: float in [0.34, 0.72]:
		_box(root, Vector3(4.4, 0.07, 0.07), post, Vector3(0.0, rail, 2.6))
	# The stone well.
	_cyl(root, 0.52, 0.58, 0.66, stone, Vector3(-2.4, 0.33, -0.4))
	_cyl(root, 0.46, 0.46, 0.06, _flat("well_water",
		Color(0.20, 0.32, 0.38), 0.2, 0.4), Vector3(-2.4, 0.64, -0.4))
	for side: float in [-1.0, 1.0]:
		_box(root, Vector3(0.08, 0.9, 0.08), post,
			Vector3(-2.4 + side * 0.46, 1.05, -0.4))
	_roof_prism(root, Vector3(-2.4, 1.52, -0.4), 1.3, 0.32,
		_roof_mat("well_roof", Color(0.52, 0.34, 0.26)))
	# The scarecrow: cross, shirt, straw head, hat. Built like the yard's props.
	_box(root, Vector3(0.09, 1.7, 0.09), post, Vector3(1.9, 0.85, 0.2))
	_box(root, Vector3(1.1, 0.08, 0.08), post, Vector3(1.9, 1.35, 0.2))
	_box(root, Vector3(0.62, 0.60, 0.30), cloth, Vector3(1.9, 1.20, 0.2))
	_ball(root, 0.22, straw, Vector3(1.9, 1.68, 0.2))
	_cyl(root, 0.30, 0.34, 0.06, cloth, Vector3(1.9, 1.86, 0.2))
	_cyl(root, 0.17, 0.19, 0.20, cloth, Vector3(1.9, 1.94, 0.2))
	_ao_blob(root, Vector2(6.0, 5.0), Vector3(0.0, 0.03, 0.2), 0.4)


# ---------------------------------------------------------------- barn

func _barn_ruined(root: Node3D) -> void:
	var wall := _wall_mat("barn_old", Color(0.52, 0.30, 0.26))
	var board := _wood_mat("ruin_board", Color(0.38, 0.34, 0.29))
	# Standing, but half the roof is in the hayloft.
	_box(root, Vector3(3.4, 2.4, 2.8), wall, Vector3(0.0, 1.2, 0.0))
	_box(root, Vector3(1.9, 0.14, 3.0), board, Vector3(-0.85, 2.72, 0.0),
		Vector3(0.0, 0.0, deg_to_rad(34.0)))
	# The other slope has come down inside.
	_box(root, Vector3(1.7, 0.14, 2.6), board, Vector3(0.7, 1.05, 0.2),
		Vector3(0.10, 0.2, deg_to_rad(-58.0)))
	_box(root, Vector3(1.3, 1.7, 0.08), board, Vector3(0.0, 0.85, 1.44),
		Vector3(0.0, 0.0, deg_to_rad(6.0)))
	_ivy(root, Vector3(-1.2, 0.0, 1.44), 1.9, 5, 8181)
	_ao_blob(root, Vector2(5.4, 4.6), Vector3(0.2, 0.03, 0.3), 0.5)


func _barn_restored(root: Node3D) -> void:
	var wall := _wall_mat("barn_wall", Color(0.66, 0.30, 0.25))
	var roof := _roof_mat("barn_roof", Color(0.42, 0.40, 0.42))
	var patch := _roof_mat("barn_patch", Color(0.52, 0.48, 0.44))
	var trim := _wood_mat("barn_trim", Color(0.86, 0.82, 0.74))
	var hay := _flat("hay", Color(0.78, 0.68, 0.34), 1.0)
	var cat_fur := _flat("cat_fur", Color(0.36, 0.33, 0.31), 1.0)
	_box(root, Vector3(3.4, 2.5, 2.8), wall, Vector3(0.0, 1.25, 0.0))
	_roof_prism(root, Vector3(0.0, 2.52, 0.0), 3.1, 0.95, roof)
	# One patched panel, a different grey: repaired, not replaced.
	_box(root, Vector3(1.0, 0.10, 0.9), patch, Vector3(-0.75, 2.86, -0.55),
		Vector3(0.0, 0.0, deg_to_rad(31.0)))
	# The big door with its X brace, in pale trim against the red.
	_box(root, Vector3(1.4, 1.8, 0.08), trim, Vector3(0.0, 0.90, 1.44))
	for tilt: float in [0.9, -0.9]:
		_box(root, Vector3(2.2, 0.10, 0.05), wall, Vector3(0.0, 0.90, 1.49),
			Vector3(0.0, 0.0, tilt))
	_window(root, Vector2(0.7, 0.6), Vector3(0.0, 2.35, 1.44), true)
	# Hay bales by the door, and the cat asleep on the top one.
	for spec: Array in [[Vector3(1.5, 0.30, 1.75), 0.2],
			[Vector3(2.05, 0.30, 1.35), -0.3], [Vector3(1.62, 0.86, 1.68), 0.5]]:
		_box(root, Vector3(0.78, 0.56, 0.56), hay, spec[0],
			Vector3(0.0, float(spec[1]), 0.0))
	# One extra bale per harvest brought in, up to the cap: the barn visibly
	# fills as the player works the field (G13.6).
	for i in HarvestLog.bales():
		_box(root, Vector3(0.74, 0.52, 0.52), hay,
			Vector3(2.55 + float(i % 2) * 0.86, 0.28 + float(i / 2) * 0.54,
				1.95 - float(i / 2) * 0.30),
			Vector3(0.0, 0.2 + float(i) * 0.4, 0.0))
	_ball(root, 0.20, cat_fur, Vector3(1.62, 1.26, 1.68),
		Vector3(1.5, 0.85, 1.0))
	_ball(root, 0.12, cat_fur, Vector3(1.36, 1.30, 1.60))
	for ear: float in [-1.0, 1.0]:
		_box(root, Vector3(0.06, 0.09, 0.05), cat_fur,
			Vector3(1.34, 1.40, 1.60 + ear * 0.07))
	_ao_blob(root, Vector2(5.4, 4.6), Vector3(0.2, 0.03, 0.3), 0.5)


# ---------------------------------------------------------------- figures

## The people who come back. A figure only exists once the project that brings
## them here is built, so the town filling up is the same act as the town being
## rebuilt — you do not buy villagers, you buy the reason they return (G13.5).
func _build_figures() -> void:
	for id: String in GameConfig.DIORAMA_FIGURES:
		var spec: Dictionary = GameConfig.DIORAMA_FIGURES[id]
		var body := Node3D.new()
		body.name = "Figure_" + id
		add_child(body)
		if id == "cat":
			_cat_body(body, spec["colour"])
		else:
			_person_body(body, spec["colour"])
		body.visible = false
		_figures.append({"id": id, "node": body, "needs": str(spec["needs"]),
			"from": spec["from"], "to": spec["to"],
			"speed": float(spec["speed"]), "t": _rng.randf()})
	_build_ellie()
	refresh_figures()


## A person at diorama scale is a coat, a head and two legs — at this camera
## distance anything more is invisible, and anything less reads as a post.
func _person_body(root: Node3D, colour: Color) -> void:
	var coat := _flat("figure_%s" % colour.to_html(false), colour, 1.0)
	var skin := _flat("figure_skin", Color(0.78, 0.62, 0.50), 1.0)
	var dark := _flat("figure_dark", Color(0.22, 0.20, 0.22), 1.0)
	_box(root, Vector3(0.34, 0.46, 0.24), coat, Vector3(0.0, 0.60, 0.0))
	_ball(root, 0.13, skin, Vector3(0.0, 0.92, 0.0))
	# Legs are separate so they can scissor as the figure walks.
	for side: float in [-1.0, 1.0]:
		var leg := Node3D.new()
		leg.name = "Leg%s" % ("L" if side < 0.0 else "R")
		leg.position = Vector3(side * 0.09, 0.37, 0.0)
		root.add_child(leg)
		_box(leg, Vector3(0.11, 0.38, 0.11), dark, Vector3(0.0, -0.19, 0.0))


## The barn cat: a low body, a head and a tail that stands up.
func _cat_body(root: Node3D, colour: Color) -> void:
	var fur := _flat("cat_walk", colour, 1.0)
	_ball(root, 0.11, fur, Vector3(0.0, 0.13, 0.0), Vector3(1.7, 0.9, 1.0))
	_ball(root, 0.075, fur, Vector3(0.15, 0.19, 0.0))
	_box(root, Vector3(0.04, 0.18, 0.04), fur, Vector3(-0.17, 0.20, 0.0),
		Vector3(0.0, 0.0, 0.35))
	for ear: float in [-1.0, 1.0]:
		_box(root, Vector3(0.04, 0.06, 0.03), fur,
			Vector3(0.17, 0.25, ear * 0.045))


## Ellie on the swing, once the case is closed and the swing is built. She does
## not walk: she sits, and the seat swings under her.
func _build_ellie() -> void:
	var pivot := Node3D.new()
	pivot.name = "EllieSwing"
	var plot: Dictionary = GameConfig.DIORAMA_BUILDINGS[GameConfig.DIORAMA_ELLIE_NEEDS]
	pivot.position = (plot["pos"] as Vector3) + Vector3(0.0, 4.50, 0.0)
	pivot.rotation.y = float(plot["yaw"])
	add_child(pivot)
	# A pivot at the limb, with the seat hanging below it, so one rotation
	# swings rope, seat and child together.
	var rider := Node3D.new()
	rider.position = Vector3(1.60, -2.58, 0.30)
	pivot.add_child(rider)
	var coat := _flat("ellie_coat", Color(0.86, 0.44, 0.42), 1.0)
	var skin := _flat("figure_skin", Color(0.78, 0.62, 0.50), 1.0)
	var dark := _flat("figure_dark", Color(0.22, 0.20, 0.22), 1.0)
	_box(rider, Vector3(0.26, 0.34, 0.20), coat, Vector3(0.0, 0.22, 0.0))
	_ball(rider, 0.11, skin, Vector3(0.0, 0.48, 0.0))
	for side: float in [-1.0, 1.0]:
		_box(rider, Vector3(0.09, 0.30, 0.09), dark,
			Vector3(side * 0.07, 0.02, 0.14), Vector3(-0.55, 0.0, 0.0))
	pivot.visible = false
	_ellie_swing = pivot


## Shows or hides each figure according to what has been built. Called on entry
## and after every purchase.
func refresh_figures() -> void:
	for entry: Dictionary in _figures:
		var node := entry["node"] as Node3D
		if node == null or not is_instance_valid(node):
			continue
		node.visible = RestoreBoard.is_built(str(entry["needs"]))
	if _ellie_swing != null and is_instance_valid(_ellie_swing):
		# She is only here once the case that was looking for her is closed.
		_ellie_swing.visible = RestoreBoard.is_built(GameConfig.DIORAMA_ELLIE_NEEDS) \
			and ChapterProgress.done_count() >= ChapterProgress.count()


## Walks every visible figure back and forth along its pair of points, and
## swings Ellie. Called from _life.
func _walk_figures(delta: float) -> void:
	for entry: Dictionary in _figures:
		var node := entry["node"] as Node3D
		if node == null or not is_instance_valid(node) or not node.visible:
			continue
		# A triangle wave: out, back, out. No path-finding, no navmesh — these
		# are two points and a line between them.
		entry["t"] = fmod(float(entry["t"]) + delta * float(entry["speed"]) * 0.25, 1.0)
		var k := float(entry["t"]) * 2.0
		var forward := k <= 1.0
		if not forward:
			k = 2.0 - k
		var from: Vector3 = entry["from"]
		var to: Vector3 = entry["to"]
		node.position = from.lerp(to, k)
		var heading := (to - from) if forward else (from - to)
		if heading.length() > 0.01:
			node.rotation.y = atan2(heading.x, heading.z)
		# Legs scissor, and the body bobs, at a rate tied to the walk.
		var stride := sin(_life_t * 6.0 * float(entry["speed"]) * 3.0)
		node.position.y = absf(stride) * 0.035
		var left := node.get_node_or_null("LegL") as Node3D
		var right := node.get_node_or_null("LegR") as Node3D
		if left != null:
			left.rotation.x = stride * 0.55
		if right != null:
			right.rotation.x = -stride * 0.55
	if _ellie_swing != null and is_instance_valid(_ellie_swing) \
			and _ellie_swing.visible:
		_ellie_swing.rotation.x = sin(_life_t * 1.35) * 0.30


# ---------------------------------------------------------------- peek (G13.5)

## A short glance at a plot, for a restore card held down: the camera leans in,
## holds, and comes back. Unlike play_restore this does NOT take the screen —
## it can be cancelled the moment the finger lifts, and it refuses to run while
## a rebuild is playing.
func peek_at(project_id: String) -> void:
	if _busy or not _buildings.has(project_id):
		return
	_peek_id = project_id
	_peek = true
	var plot: Node3D = _buildings[project_id]["plot"]
	await _fly(_peek_eye(plot.position), plot.position + Vector3(0.0, 1.5, 0.0),
		0.45, 0.0)
	var held := 0.0
	while _peek and held < GameConfig.DIORAMA_PEEK_SECONDS:
		held += get_process_delta_time()
		await get_tree().process_frame
	await _fly(_cam_base, _cam_look, 0.45, GameConfig.DIORAMA_V_OFFSET)
	_peek = false
	_peek_id = ""


## Ends a glance early — the finger came off the card.
func end_peek() -> void:
	_peek = false


## Same standoff rule as the restore close-up: in along the camera's own view
## line, so the plot is seen from the angle the player already has.
func _peek_eye(at: Vector3) -> Vector3:
	var focus := at + Vector3(0.0, 1.5, 0.0)
	return focus + (_cam_base - _cam_look).normalized() \
		* GameConfig.RESTORE_CAM_DISTANCE


# ---------------------------------------------------------------- reclaimed (G13.4)

## The weed band that rings the town and retreats a step per finished chapter.
##
## NOT baked with the static meshes: it changes eight times over a playthrough,
## so it stays its own MultiMesh and is rewritten rather than rebuilt.
func _build_reclaim() -> void:
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/grass_clump.gdshader")
	mat.set_shader_parameter("wind_amplitude", GameConfig.WIND_AMPLITUDE * 1.8)
	mat.set_shader_parameter("wind_speed", GameConfig.WIND_SPEED * 0.8)
	var mesh_rng := RandomNumberGenerator.new()
	mesh_rng.seed = 5150
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	# Variant 0 is the plain tall clump; the band is one species gone rank.
	mm.mesh = TuftField.cluster_mesh(mesh_rng, 0)
	mm.instance_count = 0
	var node := MultiMeshInstance3D.new()
	node.name = "ReclaimBand"
	node.multimesh = mm
	node.material_override = mat
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	_reclaim_mesh = mm

	# Every clump the band could ever hold, with the depth at which it stands.
	# Retreating is then a matter of writing fewer of them, not re-scattering.
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260826
	var half := GameConfig.DIORAMA_PLATE * 0.5 - Vector2.ONE * GameConfig.DIORAMA_BEVEL
	var band := GameConfig.RECLAIM_BAND_START
	var step := 1.0 / sqrt(GameConfig.RECLAIM_DENSITY)
	var x := -half.x
	while x <= half.x:
		var z := -half.y
		while z <= half.y:
			var at := Vector3(x + rng.randf_range(-0.4, 0.4), 0.0,
				z + rng.randf_range(-0.4, 0.4))
			z += step
			# Depth into the plate from whichever edge is nearest.
			var depth := minf(half.x - absf(at.x), half.y - absf(at.z))
			if depth > band or depth < 0.0:
				continue
			_reclaim_spots.append({"at": at, "depth": depth,
				"scale": rng.randf_range(GameConfig.RECLAIM_CLUMP_SCALE.x,
					GameConfig.RECLAIM_CLUMP_SCALE.y),
				"yaw": rng.randf() * TAU, "fall": 0.0})
		x += step
	_write_reclaim()


## How deep the band reaches at the current chapter count.
func _reclaim_band() -> float:
	var done := clampi(ChapterProgress.done_count(), 0, GameConfig.RECLAIM_STEPS)
	var k := float(done) / float(GameConfig.RECLAIM_STEPS)
	return lerpf(GameConfig.RECLAIM_BAND_START, GameConfig.RECLAIM_BAND_END, k)


## Writes the clumps that are still standing. `fall` lets a clump lie flat
## during the retreat animation instead of vanishing.
func _write_reclaim() -> void:
	if _reclaim_mesh == null:
		return
	var band := _reclaim_band()
	var kept: Array = []
	for spot: Dictionary in _reclaim_spots:
		if float(spot["depth"]) <= band or float(spot["fall"]) > 0.0:
			kept.append(spot)
	_reclaim_mesh.instance_count = kept.size()
	for i in kept.size():
		var spot: Dictionary = kept[i]
		var fall := float(spot["fall"])
		var basis := Basis(Vector3.UP, float(spot["yaw"]))
		if fall > 0.0:
			# Laid over, not shrunk: cut grass falls.
			basis = basis.rotated(Vector3.RIGHT.rotated(Vector3.UP,
				float(spot["yaw"])), fall * PI * 0.44)
		basis = basis.scaled(Vector3.ONE * float(spot["scale"])
			* (1.0 - fall * 0.35))
		_reclaim_mesh.set_instance_transform(i, Transform3D(basis, spot["at"]))
		var shade := 0.74 + fmod(float(i) * 0.11, 0.3)
		_reclaim_mesh.set_instance_color(i, Color(shade, shade * 0.98, shade * 0.9))


## Plays the band stepping back: the clumps that no longer belong lie down over
## RECLAIM_FALL_SECONDS, then stop being written at all. Awaited by the hub.
func play_reclaim_step() -> void:
	var band := _reclaim_band()
	var doomed: Array = []
	for spot: Dictionary in _reclaim_spots:
		if float(spot["depth"]) > band and float(spot["fall"]) <= 0.0:
			doomed.append(spot)
	if doomed.is_empty():
		return
	AudioDirector.play_cut()
	var elapsed := 0.0
	while elapsed < GameConfig.RECLAIM_FALL_SECONDS:
		elapsed += get_process_delta_time()
		var k := clampf(elapsed / GameConfig.RECLAIM_FALL_SECONDS, 0.0, 1.0)
		for spot: Dictionary in doomed:
			# Staggered by depth, so the fall sweeps outward instead of the
			# whole ring dropping at once.
			var lag := clampf((float(spot["depth"]) - band) * 0.10, 0.0, 0.5)
			spot["fall"] = clampf((k - lag) / maxf(0.01, 1.0 - lag), 0.0, 1.0)
		_write_reclaim()
		await get_tree().process_frame
	for spot: Dictionary in doomed:
		spot["fall"] = 0.0
	_write_reclaim()


## True when the band is standing further out than the chapter count allows —
## the hub uses this to decide whether a retreat is owed.
func reclaim_owed() -> bool:
	var band := _reclaim_band()
	for spot: Dictionary in _reclaim_spots:
		if float(spot["depth"]) > band:
			return true
	return false
