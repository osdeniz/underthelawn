class_name Birds
extends Node3D
## Slow flocks circling high over every yard and over the town (G14.2).
##
## Silent by design: the ambient bird loop and the random chirp were taken OUT
## of gameplay in G9.4 and stay out. This is the other half of that decision —
## the sky was empty in both senses, and only one of them was deliberate.
##
## Each bird is two unshaded triangles with a slow flap. No texture, no shadow,
## no lighting: at 30 units up a silhouette is all that survives anyway, which
## is why they cost almost nothing.

var _flocks: Array = []
var _time := 0.0


## Adds a flock ring to `parent`. Deterministic per seed, like the horizon.
## `height` and `ring` are given rather than derived, because where a bird is
## VISIBLE is a property of the camera, not of the scene's size. Measured: the
## hub camera sits at y 28 looking down 39 degrees, so its top edge is 2.8
## degrees BELOW the horizon — anything higher than about y 25 at 60 units is
## off the top of the frame no matter how big the sky is.
static func build(parent: Node3D, seed_value: int, height: Vector2,
		ring: Vector2, size := 0.9) -> Birds:
	if not GameConfig.BIRDS_ENABLED:
		return null
	var node := Birds.new()
	node.name = "Birds"
	parent.add_child(node)
	node._populate(seed_value, height, ring, size)
	return node


func _populate(seed_value: int, height: Vector2, ring_range: Vector2,
		size: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var mat := StandardMaterial3D.new()
	mat.albedo_color = GameConfig.BIRD_COLOUR
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	for flock in GameConfig.BIRD_FLOCKS:
		var pivot := Node3D.new()
		pivot.position.y = rng.randf_range(height.x, height.y)
		add_child(pivot)
		var radius := rng.randf_range(ring_range.x, ring_range.y)
		var birds: Array = []
		for i in GameConfig.BIRDS_PER_FLOCK:
			var bird := Node3D.new()
			# Strung out along the circle, at slightly different radii: a line
			# of evenly spaced dots reads as a necklace, not a flock.
			var lead := float(i) * rng.randf_range(0.05, 0.11)
			bird.position = Vector3(radius * rng.randf_range(0.92, 1.08), 0.0, 0.0)
			pivot.add_child(bird)
			for side: float in [-1.0, 1.0]:
				var wing := MeshInstance3D.new()
				var mesh := PrismMesh.new()
				mesh.size = Vector3(size, 0.02, size * 0.42)
				wing.mesh = mesh
				wing.material_override = mat
				wing.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				# Welding a wing into a static mesh would freeze it mid-flap,
				# and the bake is one-way (G13.6).
				wing.set_meta("no_bake", true)
				wing.position.x = side * size * 0.5
				bird.add_child(wing)
			birds.append({
				"node": bird, "lead": lead,
				"flap": rng.randf() * TAU,
				"beat": rng.randf_range(2.6, 4.2),
			})
		_flocks.append({
			"pivot": pivot, "birds": birds,
			"speed": rng.randf_range(GameConfig.BIRD_SPEED.x, GameConfig.BIRD_SPEED.y)
				* (1.0 if rng.randf() < 0.5 else -1.0),
			"phase": rng.randf() * TAU,
		})


func _process(delta: float) -> void:
	_time += delta
	for entry_any: Variant in _flocks:
		var entry: Dictionary = entry_any
		var pivot: Node3D = entry["pivot"]
		pivot.rotation.y = float(entry["phase"]) + _time * float(entry["speed"]) * TAU
		for bird_any: Variant in entry["birds"]:
			var bird: Dictionary = bird_any
			var node: Node3D = bird["node"]
			# The lead spaces them around the ring; the flap is the only thing
			# that says these are birds and not specks.
			node.rotation.y = -float(bird["lead"])
			var beat := sin(_time * float(bird["beat"]) * TAU + float(bird["flap"]))
			for wing_index in node.get_child_count():
				var wing := node.get_child(wing_index) as Node3D
				if wing == null:
					continue
				var side := -1.0 if wing_index == 0 else 1.0
				wing.rotation.z = side * beat * 0.55
