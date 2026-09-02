class_name MoneyProp
extends Node3D
## The classic cash bundle (G9.4): a banded stack of green bills hovering over
## its cell, bobbing and slowly spinning so it reads at gameplay distance the
## way it does in every lawn-mowing ad. Collected = a quick pop toward the
## camera, then gone; the HUD's flying +$ label does the rest.

var _time := 0.0
var _base_y := 0.0
var _collected := false


static func spawn(parent: Node3D, at: Vector3) -> MoneyProp:
	var prop := MoneyProp.new()
	prop.name = "Money"
	parent.add_child(prop)
	prop.position = Vector3(at.x, GameConfig.MONEY_HOVER, at.z)
	prop._base_y = prop.position.y
	prop._time = randf() * TAU   # desynced bobbing across the yard
	prop._build()
	return prop


## A banded stack of dollar bills. What makes paper money read at gameplay
## distance is three things, and the first version had none of them: the RATIO
## of a note (2.35:1, not the 1.47:1 brick it was), the stepped EDGES of
## separate sheets, and a printed FACE on the top one — pale paper with dark
## ink, because the saturated green belongs to the edges of the stack and not
## to the side you are looking at (G14.12).
func _build() -> void:
	var size := GameConfig.MONEY_SIZE
	var bill := _mat(GameConfig.MONEY_BILL)
	var top := _mat(GameConfig.MONEY_BILL_TOP)
	var band := _mat(GameConfig.MONEY_BAND)
	var ink := _mat(GameConfig.MONEY_INK)
	var face := _mat(GameConfig.MONEY_FACE)

	var sheets := GameConfig.MONEY_SHEETS
	var sheet_h := size.y / float(sheets)
	var rng := RandomNumberGenerator.new()
	# Seeded off the position so every bundle is shuffled its own way, and the
	# same way on every visit.
	rng.seed = int(absf(position.x) * 1000.0) + int(absf(position.z) * 17.0)
	for i in sheets:
		var t := float(i) / float(maxi(sheets - 1, 1))
		var node := _box(Vector3(size.x, sheet_h * 0.9, size.z),
			top if i == sheets - 1 else bill,
			Vector3(rng.randf_range(-0.010, 0.010),
				-size.y * 0.5 + sheet_h * (float(i) + 0.5),
				rng.randf_range(-0.010, 0.010)))
		# A slight fan through the stack: a handful of cash never lands square.
		node.rotation.y = deg_to_rad(lerpf(-4.0, 5.0, t)
			+ rng.randf_range(-1.5, 1.5))

	# The top note, printed: a pale face inset from the edges, a dark frame
	# line, an oval where the portrait goes and a mark in each corner.
	var lid := size.y * 0.52
	# Small. At play distance the note is a few pixels across, and a face this
	# wide made the bundle read as a white card with green edges rather than as
	# money — the SILHOUETTE has to stay green (G14.12).
	_box(Vector3(size.x * 0.62, 0.006, size.z * 0.54), ink,
		Vector3(0.0, lid, 0.0))
	_box(Vector3(size.x * 0.56, 0.006, size.z * 0.46), face,
		Vector3(0.0, lid + 0.004, 0.0))
	var oval := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = size.z * 0.15
	disc.bottom_radius = disc.top_radius
	disc.height = 0.006
	disc.radial_segments = 12
	oval.mesh = disc
	oval.material_override = ink
	oval.position = Vector3(0.0, lid + 0.008, 0.0)
	# Squashed along the note, which is what turns a circle into a portrait
	# medallion.
	oval.scale = Vector3(1.0, 1.0, 0.72)
	add_child(oval)
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			_box(Vector3(size.x * 0.07, 0.006, size.z * 0.10), ink,
				Vector3(sx * size.x * 0.40, lid + 0.008, sz * size.z * 0.30))

	# Two paper straps across the short way, the way a bank bundles notes.
	for sx2: float in [-1.0, 1.0]:
		_box(Vector3(size.x * 0.065, size.y * 1.02, size.z * 1.05), band,
			Vector3(sx2 * size.x * 0.24, 0.0, 0.0))


## Saturated + softly emissive: in full sun a plain shaded green washed out to
## the pale tips of the grass — the ad-game money look needs its own light.
func _mat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.65
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = GameConfig.MONEY_GLOW
	return m


func _box(size: Vector3, mat: Material, pos: Vector3) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	add_child(mi)
	return mi


func _process(delta: float) -> void:
	if _collected:
		return
	_time += delta
	position.y = _base_y + sin(_time * TAU * 0.6) * GameConfig.MONEY_BOB
	rotation.y += GameConfig.MONEY_SPIN * delta


## Collect animation: jump, shrink, gone.
func collect() -> void:
	if _collected:
		return
	_collected = true
	var tw := create_tween()
	tw.tween_property(self, "position:y", _base_y + 1.2, 0.28) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(self, "scale", Vector3.ONE * 0.05, 0.30) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_callback(queue_free)
