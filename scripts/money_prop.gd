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


func _build() -> void:
	var size := GameConfig.MONEY_SIZE
	var bill := _mat(GameConfig.MONEY_BILL)
	var top := _mat(GameConfig.MONEY_BILL_TOP)
	var band := _mat(GameConfig.MONEY_BAND)

	# Body of the stack, a lighter top "bill", and the paper band around it.
	_box(size, bill, Vector3.ZERO)
	_box(Vector3(size.x * 0.98, size.y * 0.12, size.z * 0.98), top,
		Vector3(0.0, size.y * 0.53, 0.0))
	_box(Vector3(size.x * 0.34, size.y * 1.12, size.z * 1.04), band,
		Vector3.ZERO)


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


func _box(size: Vector3, mat: Material, pos: Vector3) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	add_child(mi)


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
