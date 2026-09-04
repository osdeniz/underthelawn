class_name SalvageProp
extends Node3D
## Salvage in the grass (G19.1). This was a hovering, spinning, glowing stack
## of dollar bills — the hyper-casual ad-game pickup — in a world where the
## money is gone and the town pays in scrap and food. Worse, it floated ABOVE
## the grass, so the one rule this game has ("the grass hides the world") was
## broken by its own currency in the first yard.
##
## Now: a coil of wire, a couple of tins, or a gear and a bolt, lying half-sunk
## at ground level. Hidden until the machine opens the grass next to it (see
## ScrapField._on_cell_cut), then it rises the last few centimetres into view.
## Collected the same way as before: a quick pop and gone.

var _revealed := false
var _collected := false
var _rest_y := 0.0


static func spawn(parent: Node3D, at: Vector3) -> SalvageProp:
	var prop := SalvageProp.new()
	prop.name = "Salvage"
	parent.add_child(prop)
	prop._rest_y = GameConfig.PROP_GROUND_Y
	prop.position = Vector3(at.x, prop._rest_y - GameConfig.PROP_SINK, at.z)
	prop.visible = false
	prop._build()
	return prop


func _build() -> void:
	var rng := RandomNumberGenerator.new()
	# Seeded off the position: the same yard shows the same junk on every visit.
	rng.seed = int(absf(position.x) * 1000.0) + int(absf(position.z) * 17.0)
	rotation.y = rng.randf() * TAU
	match rng.randi_range(0, 2):
		0: _build_coil(rng)
		1: _build_tins(rng)
		_: _build_gear(rng)


## A coil of copper wire lying flat, with a loose second loop.
func _build_coil(rng: RandomNumberGenerator) -> void:
	var copper := _mat(GameConfig.SALVAGE_COPPER)
	var ring := TorusMesh.new()
	ring.inner_radius = 0.11
	ring.outer_radius = 0.21
	ring.rings = 10
	ring.ring_segments = 14
	_mesh(ring, copper, Vector3(0.0, 0.03, 0.0))
	var loose := TorusMesh.new()
	loose.inner_radius = 0.09
	loose.outer_radius = 0.16
	loose.rings = 8
	loose.ring_segments = 12
	var mi := _mesh(loose, copper, Vector3(0.14, 0.07, -0.06))
	mi.rotation = Vector3(deg_to_rad(rng.randf_range(15.0, 35.0)), 0.0,
		deg_to_rad(rng.randf_range(-20.0, 20.0)))


## Two tins: one standing, one on its side, both dull.
func _build_tins(rng: RandomNumberGenerator) -> void:
	var tin := _mat(GameConfig.SALVAGE_TIN)
	var dark := _mat(GameConfig.SALVAGE_IRON)
	var up := CylinderMesh.new()
	up.top_radius = 0.085
	up.bottom_radius = 0.085
	up.height = 0.22
	up.radial_segments = 10
	_mesh(up, tin, Vector3(-0.10, 0.09, 0.0))
	var lid := CylinderMesh.new()
	lid.top_radius = 0.07
	lid.bottom_radius = 0.07
	lid.height = 0.01
	lid.radial_segments = 10
	_mesh(lid, dark, Vector3(-0.10, 0.205, 0.0))
	var down := CylinderMesh.new()
	down.top_radius = 0.08
	down.bottom_radius = 0.08
	down.height = 0.22
	down.radial_segments = 10
	var mi := _mesh(down, tin, Vector3(0.12, 0.06, 0.05))
	mi.rotation = Vector3(0.0, deg_to_rad(rng.randf_range(-30.0, 30.0)), PI * 0.5)


## A gear on its face and a bolt beside it.
func _build_gear(rng: RandomNumberGenerator) -> void:
	var iron := _mat(GameConfig.SALVAGE_IRON)
	var light := _mat(GameConfig.SALVAGE_TIN)
	var disc := CylinderMesh.new()
	disc.top_radius = 0.17
	disc.bottom_radius = 0.17
	disc.height = 0.05
	disc.radial_segments = 16
	_mesh(disc, iron, Vector3(0.0, 0.03, 0.0))
	for i in 8:
		var a := TAU * float(i) / 8.0
		var tooth := BoxMesh.new()
		tooth.size = Vector3(0.07, 0.05, 0.06)
		var mi := _mesh(tooth, iron, Vector3(cos(a) * 0.19, 0.03, sin(a) * 0.19))
		mi.rotation.y = -a
	var hub := CylinderMesh.new()
	hub.top_radius = 0.05
	hub.bottom_radius = 0.05
	hub.height = 0.012
	hub.radial_segments = 10
	_mesh(hub, light, Vector3(0.0, 0.06, 0.0))
	var bolt := CylinderMesh.new()
	bolt.top_radius = 0.03
	bolt.bottom_radius = 0.03
	bolt.height = 0.16
	bolt.radial_segments = 6
	var b := _mesh(bolt, light, Vector3(0.24, 0.03, rng.randf_range(-0.08, 0.08)))
	b.rotation = Vector3(0.0, deg_to_rad(rng.randf_range(-40.0, 40.0)), PI * 0.5)


## Dull metal with a touch of self-light: in full sun a flat-shaded prop at
## ground level sinks into the cut grass, and the reveal has to be legible.
func _mat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.6
	m.metallic = 0.25
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = GameConfig.SALVAGE_GLOW
	return m


func _mesh(mesh: Mesh, mat: Material, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi


## The grass beside it has been cut: it rises the last few centimetres.
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


## Collect animation: jump, shrink, gone. Works from hidden too — a cell cut
## before any neighbour still has to pay out visibly.
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
