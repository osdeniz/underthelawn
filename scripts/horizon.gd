class_name Horizon
extends RefCounted
## Distant hills and rooftops, for every scene that has an edge (G13.1).
##
## The yard and the diorama both used to end at fog with nothing behind it,
## which reads as a wall. These are unshaded silhouettes on a ring well past
## the playable ground: no lighting, no shadows, no collision, and they never
## come close enough for their flatness to show.
##
## Cheap on purpose — one draw per shape, a few dozen triangles each.

## Pale and low-contrast, closing on the haze colour with distance. The first
## pass used strong greys and sharp prisms, which read as a mountain range
## standing over the town instead of land trailing away from it.
## Unshaded meshes bypass the tonemapper, so these have to be authored DARKER
## than they should look: at the values the sky ends up at, the first pass came
## out near-white and the hills read as snowfields.
## Repainted in G14.2. These were authored to be read through a fog wall that
## closed at 70 units — in front of the ring they stand on, so they had never
## actually been seen. With the fog pushed out to 210 the old values came out as
## a hard dark ridge; land trailing away is paler and bluer than the ground in
## front of it, band by band.
## Bluer with each band (G19.2): the first values greyed rather than receded,
## and grey triangles on the horizon were the "flat cardboard mountains" of
## the review. Land going away goes toward the sky's colour.
const HILL_COLOURS := [Color(0.47, 0.56, 0.50), Color(0.58, 0.66, 0.66),
	Color(0.68, 0.76, 0.80)]
const ROOF_COLOUR := Color(0.46, 0.45, 0.46)
const WALL_COLOUR := Color(0.56, 0.55, 0.55)

## The land between the plate and the hills. It used to be bare ground with a
## pale ridge behind it, which reads as paper (G14.2b): the country a town sits
## in has the same grass and the same trees as the town, just smaller with
## distance. Two bands of trees, thinning outwards.
const FAR_TREE_BANDS := 2
const FAR_TREES_PER_BAND := 26
const FAR_TRUNK := Color(0.34, 0.26, 0.19)
## Canopies pale with distance the same way the hills do, so the eye reads the
## whole band as one receding surface.
const FAR_LEAF := [Color(0.32, 0.46, 0.26), Color(0.42, 0.53, 0.36)]


## Adds the horizon to `parent`, on a ring of `radius`. Deterministic per seed.
## `ground` adds the meadow and the distant trees that fill the gap between the
## scene and the hills; `ground_tint` is the grass colour to match, since a
## wheat yard's country must not be green.
static func build(parent: Node3D, radius: float, seed_value: int,
		ground := true, ground_tint := Color(0.34, 0.44, 0.26)) -> void:
	var root := Node3D.new()
	root.name = "Horizon"
	parent.add_child(root)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	if ground:
		_build_country(root, radius, rng, ground_tint)

	# Three bands of hills at increasing distance, each paler than the one in
	# front: the cheapest possible aerial perspective.
	for band in 3:
		var ring := radius * (1.0 + float(band) * 0.34)
		var mat := _unshaded("hill_%d" % band, HILL_COLOURS[band])
		for i in 14 + band * 4:
			var a := TAU * (float(i) + rng.randf_range(-0.35, 0.35)) / float(14 + band * 4)
			# Wide and LOW: hills, not peaks. Height barely a tenth of width.
			var width := rng.randf_range(26.0, 52.0)
			var height := width * rng.randf_range(0.10, 0.19) \
				* (1.0 + float(band) * 0.18)
			# A mound, not a prism (G19.2): a triangle on the horizon is a
			# mountain however low it is. The profile is a raised cosine with
			# its crest pushed off-centre, so no two read as the same shape.
			var hill := MeshInstance3D.new()
			hill.mesh = _mound(width, height, rng.randf_range(0.35, 0.65))
			hill.material_override = mat
			hill.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			# Sunk well below the ground line so only the soft crest shows.
			hill.position = Vector3(cos(a) * ring,
				height * 0.5 - height * 0.62, sin(a) * ring)
			hill.rotation.y = -a + PI * 0.5
			root.add_child(hill)

	# A scatter of rooftops on the nearest band: the rest of the town, still out
	# there, still nobody's.
	var far_windows: Array = []
	var roof_mat := _unshaded("far_roof", ROOF_COLOUR)
	var wall_mat := _unshaded("far_wall", WALL_COLOUR)
	for i in 22:
		var a := rng.randf() * TAU
		# Kept to the back and sides; nothing directly behind the camera.
		if sin(a) > 0.45:
			continue
		var ring := radius * rng.randf_range(0.86, 1.02)
		var at := Vector3(cos(a) * ring, 0.0, sin(a) * ring)
		var w := rng.randf_range(2.2, 4.2)
		var h := rng.randf_range(1.6, 2.8)
		var wall := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(w, h, w * 0.8)
		wall.mesh = box
		wall.material_override = wall_mat
		wall.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		wall.position = at + Vector3(0.0, h * 0.5, 0.0)
		wall.rotation.y = rng.randf() * TAU
		root.add_child(wall)
		var roof := MeshInstance3D.new()
		var prism := PrismMesh.new()
		prism.size = Vector3(w * 1.15, rng.randf_range(0.9, 1.6), w * 0.9)
		roof.mesh = prism
		roof.material_override = roof_mat
		roof.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		roof.position = wall.position + Vector3(0.0, h * 0.5 + 0.45, 0.0)
		roof.rotation.y = wall.rotation.y
		root.add_child(roof)
		if rng.randf() < GameConfig.FAR_WINDOW_CHANCE:
			far_windows.append(wall.position
				+ Vector3(0.0, -h * 0.1, 0.0)
				+ Vector3(0.0, 0.0, -w * 0.42).rotated(Vector3.UP,
					wall.rotation.y))

	# Windows in the far houses, as ONE mesh rather than one node each. A dark
	# ring of rooftops around a lit town reads as abandonment, which is not what
	# the story says by the time the player is looking at a rebuilt square
	# (G14.6). Hidden by default; the hour decides.
	if not far_windows.is_empty():
		var lights := MeshInstance3D.new()
		lights.name = "FarWindows"
		lights.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		lights.set_meta("no_bake", true)
		var tool := SurfaceTool.new()
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		var half := GameConfig.FAR_WINDOW_SIZE * 0.5
		for any: Variant in far_windows:
			var at: Vector3 = any
			# Facing the middle of the plate, which is where the camera is.
			var to_middle := Vector3(-at.x, 0.0, -at.z).normalized()
			var side := to_middle.cross(Vector3.UP) * half
			var up := Vector3(0.0, half, 0.0)
			var corners := [at - side - up, at + side - up, at + side + up,
				at - side + up]
			for triangle: Array in [[0, 1, 2], [0, 2, 3]]:
				for index: int in triangle:
					tool.set_normal(to_middle)
					tool.set_uv(Vector2.ZERO)
					tool.add_vertex(corners[index])
		lights.mesh = tool.commit()
		var glow := StandardMaterial3D.new()
		glow.albedo_color = GameConfig.WINDOW_COLOUR
		glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		glow.disable_receive_shadows = true
		lights.material_override = glow
		lights.visible = false
		root.add_child(lights)


## Grass out to the hills, with trees standing in it. Everything here is
## unshaded and shadowless: at this distance a lit surface only shows the sun as
## a flat wash, and the cost has to stay near nothing.
## Turns the far windows on for the dark hours. Called by whatever owns the
## scene's light, since the horizon has no idea what time it is.
## Takes any Node, not a Node3D: the caller passes the scene root, and a scene
## root is not always 3D (a test's root is a plain Node, and this threw).
static func light_windows(parent: Node, lit: bool) -> void:
	for any: Variant in parent.find_children("FarWindows", "", true, false):
		var node := any as MeshInstance3D
		if node != null:
			node.visible = lit


static func _build_country(root: Node3D, radius: float,
		rng: RandomNumberGenerator, tint: Color) -> void:
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(radius * 5.2, radius * 5.2)
	ground.mesh = plane
	ground.material_override = _unshaded("country", tint)
	ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Just under the scene's own ground so it never z-fights with it.
	ground.position.y = -0.12
	root.add_child(ground)

	var trunk_mat := _unshaded("far_trunk", FAR_TRUNK)
	for band in FAR_TREE_BANDS:
		var leaf_mat := _unshaded("far_leaf_%d" % band, FAR_LEAF[band])
		var ring := radius * (0.52 + float(band) * 0.30)
		for i in FAR_TREES_PER_BAND:
			var a := TAU * (float(i) + rng.randf_range(-0.4, 0.4)) \
				/ float(FAR_TREES_PER_BAND)
			var out := ring * rng.randf_range(0.82, 1.18)
			# Scaled to the ring they stand on, so the same builder works for a
			# yard and for the hub's much smaller plate.
			var scale := radius * rng.randf_range(0.028, 0.045)
			var at := Vector3(cos(a) * out, 0.0, sin(a) * out)
			var trunk := MeshInstance3D.new()
			var box := BoxMesh.new()
			box.size = Vector3(scale * 0.16, scale * 1.3, scale * 0.16)
			trunk.mesh = box
			trunk.material_override = trunk_mat
			trunk.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			trunk.position = at + Vector3(0.0, scale * 0.65, 0.0)
			root.add_child(trunk)
			# Three blobs, spread sideways more than up (G19.2): two stacked
			# spheres still read as a lollipop; a crown is wider than it is
			# tall, with a lower blob to each side of the middle one.
			var lean_x := rng.randf_range(-0.2, 0.2)
			var blobs: Array = [
				[0.62, Vector3(lean_x, 1.35, 0.0)],
				[0.46, Vector3(lean_x - 0.55, 1.12, rng.randf_range(-0.2, 0.2))],
				[0.42, Vector3(lean_x + 0.52, 1.18, rng.randf_range(-0.2, 0.2))],
			]
			for blob: Array in blobs:
				var crown := MeshInstance3D.new()
				var ball := SphereMesh.new()
				ball.radius = scale * float(blob[0])
				ball.height = ball.radius * 1.7
				ball.radial_segments = 6
				ball.rings = 3
				crown.mesh = ball
				crown.material_override = leaf_mat
				crown.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				crown.position = at + (blob[1] as Vector3) * scale
				root.add_child(crown)


## Unshaded means the hour never touches these (G19.5): at night the country
## past the fence stayed daylight green under a blue sky, and in the lantern
## chapter it was the brightest thing on screen. Every material built here
## remembers its authored colour and shade() multiplies it by a tint read from
## the light that was actually written — sun energy, ambient colour, ambient
## energy — so the horizon follows every preset, blend and override for free.
static func shade(parent: Node, sun: DirectionalLight3D, env: Environment) -> void:
	if parent == null or env == null:
		return
	var sun_energy := sun.light_energy if sun != null else 1.0
	var strength := clampf((sun_energy * 0.5 + env.ambient_light_energy * 0.9) / 1.2,
		0.18, 1.0)
	var tint := Color.WHITE.lerp(env.ambient_light_color, 0.45) * strength
	tint.a = 1.0
	for any: Variant in parent.find_children("Horizon", "", true, false):
		var root := any as Node
		if root == null:
			continue
		for mi_any: Variant in root.find_children("*", "MeshInstance3D", true, false):
			var mi := mi_any as MeshInstance3D
			var mat := mi.material_override as StandardMaterial3D if mi != null else null
			if mat == null or not mat.has_meta("base_colour"):
				continue
			var base: Color = mat.get_meta("base_colour")
			mat.albedo_color = Color(base.r * tint.r, base.g * tint.g, base.b * tint.b, base.a)


static func _unshaded(_key: String, colour: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = colour
	mat.set_meta("base_colour", colour)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.roughness = 1.0
	# The mounds are single-sided fans seen from either side of the ring.
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat


## A hill's silhouette: a raised-cosine profile, `crest` in 0..1 saying where
## along the width the top sits, as one triangle fan. Twenty-two triangles.
static func _mound(width: float, height: float, crest: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := 12
	var base := Vector3(0.0, -height * 0.5, 0.0)
	var pts: Array[Vector3] = []
	for i in n + 1:
		var t := float(i) / float(n)
		# Piecewise cosine: rises to the crest, falls after it.
		var u := t / maxf(crest, 0.05) if t < crest else (1.0 - t) / maxf(1.0 - crest, 0.05)
		var y := height * (0.5 - 0.5 * cos(clampf(u, 0.0, 1.0) * PI))
		pts.append(Vector3((t - 0.5) * width, -height * 0.5 + y, 0.0))
	for i in n:
		st.set_normal(Vector3.BACK)
		st.add_vertex(base + Vector3(-width * 0.5, 0.0, 0.0))
		st.set_normal(Vector3.BACK)
		st.add_vertex(pts[i + 1])
		st.set_normal(Vector3.BACK)
		st.add_vertex(pts[i])
	return st.commit()
