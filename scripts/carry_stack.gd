class_name CarryStack
extends Node3D
## The classic hyper-casual carry stack (G10.1): everything the player picks up
## rides on the driver's back — or on the machine's deck when nobody is walking —
## until the search ends. Seeing the haul grow is the reward loop; a number in
## the corner is only the receipt.
##
## Two stacks share one node: salvage bundles pile up, evidence rides on top so
## the story objects are always the visible crown of the pile.
##
## G68 reshaped it. The ceiling is the driver's NAPE, not the sky: sizes, step
## and count all come out of GameConfig.carry_slab_max(), which derives them
## from the character's own shoulder height, and the crown's room is inside that
## budget. Before this a full haul stood a metre above the driver's head.

const SWAY_HZ := 1.4

var _bills: Array[Node3D] = []
var _items: Array[Node3D] = []
var _time := 0.0


## Adds one bundle of salvage — flattened tin and copper, the way scrap gets
## carried (G19.1; it was a cash bundle). Once the pile reaches the nape it
## stops growing and the counter keeps climbing: the haul is the reward, but a
## load taller than the person under it reads as a bug.
func add_salvage() -> void:
	if _bills.size() >= GameConfig.carry_slab_max():
		_pop()
		return
	var bundle := Node3D.new()
	add_child(bundle)
	var mesh := BoxMesh.new()
	mesh.size = GameConfig.CARRY_SLAB_SIZE
	var mat := StandardMaterial3D.new()
	mat.albedo_color = GameConfig.SALVAGE_TIN if _bills.size() % 3 != 1 \
		else GameConfig.SALVAGE_COPPER
	mat.roughness = 0.6
	mat.metallic = 0.25
	mat.emission_enabled = true
	mat.emission = mat.albedo_color
	mat.emission_energy_multiplier = GameConfig.SALVAGE_GLOW
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	bundle.add_child(mi)
	# Each bundle lands slightly askew, which is what makes a stack read as a
	# stack rather than an extruded box.
	bundle.position = Vector3(randf_range(-0.02, 0.02),
		float(_bills.size()) * GameConfig.CARRY_SLAB_STEP, randf_range(-0.02, 0.02))
	bundle.rotation.y = randf_range(-0.22, 0.22)
	_bills.append(bundle)
	_pop()


## Adds an evidence object, riding on top of the salvage. Small, and clustered
## sideways rather than stacked: three finds on top of a full pile used to be
## three more storeys, and the ceiling has to hold for the crown as well. The
## spread is deliberately tighter than the driver's shoulders — a boot standing
## out past the shoulder line is the same silliness as a tower, sideways.
func add_evidence(evidence_id: String) -> void:
	var item := SecretItem.new()
	add_child(item)
	item.setup_by_id(evidence_id, Vector3.ZERO)
	item.scale = Vector3.ONE * GameConfig.CARRY_EVIDENCE_SCALE
	item.position.y = minf(_top_y() + 0.04,
		GameConfig.carry_stack_height() - 0.04)
	item.position.x = float(_items.size() % 3) * 0.065 - 0.065
	item.position.z = -0.02 if _items.size() >= 3 else 0.02
	_items.append(item)
	_pop()


func _top_y() -> float:
	return float(_bills.size()) * GameConfig.CARRY_SLAB_STEP


## A small squash on every pickup, so each addition is felt.
func _pop() -> void:
	scale = Vector3(1.18, 0.84, 1.18)
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector3.ONE, 0.24) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _process(delta: float) -> void:
	# The pile leans with the walk cycle; a rigid stack looks glued on. The sway
	# rides on a standing lean INTO the back (G68), so the load reads as resting
	# against the driver rather than balanced on them.
	_time += delta
	rotation.z = sin(_time * TAU * SWAY_HZ) * 0.035
	rotation.x = -GameConfig.CARRY_LEAN + cos(_time * TAU * SWAY_HZ * 0.5) * 0.02


func clear_all() -> void:
	for node in _bills + _items:
		if is_instance_valid(node):
			node.queue_free()
	_bills.clear()
	_items.clear()
