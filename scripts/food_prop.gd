class_name FoodProp
extends Node3D
## A crate of produce in the grass (G14.12).
##
## The salvage prop's twin in behaviour — sits at ground level, hidden until
## the grass beside it is cut, pops when collected (G19.1) — and its opposite
## in shape and colour: a wooden crate with round produce spilling over the
## top, so at a glance you know which of the two you just uncovered.

var _revealed := false
var _collected := false
var _rest_y := 0.0


static func spawn(parent: Node3D, at: Vector3) -> FoodProp:
	var prop := FoodProp.new()
	prop.name = "Food"
	parent.add_child(prop)
	prop._rest_y = GameConfig.PROP_GROUND_Y + GameConfig.FOOD_SIZE.y * 0.5
	prop.position = Vector3(at.x, prop._rest_y - GameConfig.PROP_SINK, at.z)
	prop.visible = false
	prop.rotation.y = randf() * TAU
	prop._build()
	return prop


func _build() -> void:
	var size := GameConfig.FOOD_SIZE
	var wood := _mat(GameConfig.FOOD_CRATE)
	var dark := _mat(GameConfig.FOOD_CRATE_DARK)

	# Four walls and a floor rather than a solid box: an open crate reads as
	# holding something, and the produce needs somewhere to sit.
	_box(Vector3(size.x, size.y * 0.14, size.z), dark,
		Vector3(0.0, -size.y * 0.43, 0.0))
	# Walls at two thirds height, and sunk: a full-height crate hid the produce
	# completely, which is the only part that says "food" (G14.12).
	for side: float in [-1.0, 1.0]:
		_box(Vector3(size.x, size.y * 0.50, size.z * 0.12), wood,
			Vector3(0.0, -size.y * 0.22, side * size.z * 0.44))
		_box(Vector3(size.x * 0.12, size.y * 0.50, size.z), wood,
			Vector3(side * size.x * 0.44, -size.y * 0.22, 0.0))

	var rng := RandomNumberGenerator.new()
	rng.seed = int(absf(position.x) * 991.0) + int(absf(position.z) * 31.0)
	for i in 7:
		var produce := MeshInstance3D.new()
		var ball := SphereMesh.new()
		ball.radius = size.x * rng.randf_range(0.12, 0.17)
		ball.height = ball.radius * 2.0
		ball.radial_segments = 8
		ball.rings = 4
		produce.mesh = ball
		var colours: Array = GameConfig.FOOD_PRODUCE
		produce.material_override = _mat(colours[i % colours.size()])
		produce.position = Vector3(
			rng.randf_range(-0.26, 0.26) * size.x,
			size.y * rng.randf_range(0.10, 0.46),
			rng.randf_range(-0.26, 0.26) * size.z)
		add_child(produce)


## Softly emissive like the salvage, for the same reason: in full sun a shaded
## prop at ground level sinks into the cut grass.
func _mat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.8
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = GameConfig.SALVAGE_GLOW
	return m


func _box(size: Vector3, mat: Material, pos: Vector3) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	add_child(mi)


## The grass beside it has been cut: the crate rises into view.
func reveal() -> void:
	if _revealed or _collected:
		return
	_revealed = true
	visible = true
	var tw := create_tween()
	tw.tween_property(self, "position:y", _rest_y, GameConfig.PROP_REVEAL_TIME) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func is_revealed() -> bool:
	return _revealed


func collect() -> void:
	if _collected:
		return
	_collected = true
	visible = true
	var tw := create_tween()
	tw.tween_property(self, "position:y", _rest_y + 1.2, 0.28) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(self, "scale", Vector3.ONE * 0.05, 0.30) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_callback(queue_free)
