class_name CarryStack
extends Node3D
## The classic hyper-casual carry stack (G10.1): everything the player picks up
## rides on the driver's back — or on the machine's deck when nobody is walking —
## until the search ends. Seeing the haul grow is the reward loop; a number in
## the corner is only the receipt.
##
## Two stacks share one node: cash bundles pile up, evidence rides on top so the
## story objects are always the visible crown of the pile.

const BILL_STEP := 0.075
const BILL_MAX := 14
const SWAY_HZ := 1.4

var _bills: Array[Node3D] = []
var _items: Array[Node3D] = []
var _time := 0.0


## Adds one cash bundle. Beyond BILL_MAX the stack stops growing (a tower taller
## than the driver reads as a bug, not a reward) but the counter keeps climbing.
func add_money() -> void:
	if _bills.size() >= BILL_MAX:
		_pop()
		return
	var bundle := Node3D.new()
	add_child(bundle)
	var mesh := BoxMesh.new()
	mesh.size = Vector3(GameConfig.MONEY_SIZE.x * 0.8,
		BILL_STEP * 0.85, GameConfig.MONEY_SIZE.z * 0.8)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = GameConfig.MONEY_BILL if _bills.size() % 2 == 0 \
		else GameConfig.MONEY_BILL_TOP
	mat.roughness = 0.7
	mat.emission_enabled = true
	mat.emission = mat.albedo_color
	mat.emission_energy_multiplier = GameConfig.MONEY_GLOW * 0.6
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	bundle.add_child(mi)
	# Each bundle lands slightly askew, which is what makes a stack read as a
	# stack rather than an extruded box.
	bundle.position = Vector3(randf_range(-0.03, 0.03),
		float(_bills.size()) * BILL_STEP, randf_range(-0.03, 0.03))
	bundle.rotation.y = randf_range(-0.22, 0.22)
	_bills.append(bundle)
	_pop()


## Adds an evidence object, riding on top of the cash.
func add_evidence(evidence_id: String) -> void:
	var item := SecretItem.new()
	add_child(item)
	item.setup_by_id(evidence_id, Vector3.ZERO)
	item.scale = Vector3.ONE * 0.75
	item.position.y = _top_y() + 0.12
	item.position.x = float(_items.size()) * 0.28 - 0.14
	_items.append(item)
	_pop()


func _top_y() -> float:
	return float(_bills.size()) * BILL_STEP


## A small squash on every pickup, so each addition is felt.
func _pop() -> void:
	scale = Vector3(1.18, 0.84, 1.18)
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector3.ONE, 0.24) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _process(delta: float) -> void:
	# The pile leans with the walk cycle; a rigid stack looks glued on.
	_time += delta
	rotation.z = sin(_time * TAU * SWAY_HZ) * 0.035
	rotation.x = cos(_time * TAU * SWAY_HZ * 0.5) * 0.02


func clear_all() -> void:
	for node in _bills + _items:
		if is_instance_valid(node):
			node.queue_free()
	_bills.clear()
	_items.clear()
