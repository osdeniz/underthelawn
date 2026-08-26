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
const HILL_COLOURS := [Color(0.48, 0.55, 0.48), Color(0.58, 0.63, 0.60),
	Color(0.68, 0.72, 0.72)]
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
			var hill := MeshInstance3D.new()
			var mesh := PrismMesh.new()
			mesh.size = Vector3(width, height, 2.0)
			mesh.left_to_right = rng.randf_range(0.35, 0.65)
			hill.mesh = mesh
			hill.material_override = mat
			hill.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			# Sunk well below the ground line so only the soft crest shows.
			hill.position = Vector3(cos(a) * ring,
				height * 0.5 - height * 0.62, sin(a) * ring)
			hill.rotation.y = -a + PI * 0.5
			root.add_child(hill)

	# A scatter of rooftops on the nearest band: the rest of the town, still out
	# there, still nobody's.
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


## Grass out to the hills, with trees standing in it. Everything here is
## unshaded and shadowless: at this distance a lit surface only shows the sun as
## a flat wash, and the cost has to stay near nothing.
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
			box.size = Vector3(scale * 0.22, scale * 1.3, scale * 0.22)
			trunk.mesh = box
			trunk.material_override = trunk_mat
			trunk.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			trunk.position = at + Vector3(0.0, scale * 0.65, 0.0)
			root.add_child(trunk)
			# Two offset blobs: one sphere reads as a lollipop at any distance.
			for blob in 2:
				var crown := MeshInstance3D.new()
				var ball := SphereMesh.new()
				ball.radius = scale * (0.62 if blob == 0 else 0.44)
				ball.height = ball.radius * 2.0
				ball.radial_segments = 6
				ball.rings = 3
				crown.mesh = ball
				crown.material_override = leaf_mat
				crown.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				crown.position = at + Vector3(
					rng.randf_range(-0.3, 0.3) * scale,
					scale * (1.35 if blob == 0 else 1.75),
					rng.randf_range(-0.3, 0.3) * scale)
				root.add_child(crown)


static func _unshaded(_key: String, colour: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = colour
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.roughness = 1.0
	return mat
