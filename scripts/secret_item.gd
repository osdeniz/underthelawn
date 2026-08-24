class_name SecretItem
extends Node3D
## The object dug out of the lawn (§9): rises from -0.15 to +0.7 over 0.7 s
## while spinning, holds 1.4 s, then drifts up and fades.
##
## kind 0 = rusty key, kind 1 = old radio. Both are primitive combinations.

signal finished()

const TOY := 0
const RADIO := 1

## Fallback display data, used only if data/story.json is missing. The real
## strings live there (G7) — these two are now EVIDENCE in a missing-person
## case, not curiosities, and N2 will swap the data without touching this file.
const INFO := [
	{ "emoji": "🧸", "name": "Ellie's Toy", "line": "It's hers. She was here." },
	{ "emoji": "📻", "name": "Old Radio", "line": "Still tuned to the emergency channel." },
]

var kind := TOY

var _visual: Node3D
var _materials: Array[StandardMaterial3D] = []


## Story data first, the constant only as a fallback.
static func info_for(kind_index: int) -> Dictionary:
	var items := Story.list("evidence.items")
	if kind_index >= 0 and kind_index < items.size() and items[kind_index] is Dictionary:
		return items[kind_index]
	return INFO[clampi(kind_index, 0, INFO.size() - 1)]


func setup(kind_index: int, ground: Vector3) -> void:
	kind = clampi(kind_index, 0, 1)
	position = ground
	_visual = Node3D.new()
	_visual.name = "Visual"
	_visual.position.y = GameConfig.ITEM_RISE_FROM
	add_child(_visual)
	_build_for(kind)
	_play()


## G10.1: the same geometry as a WORLD PROP — the object itself lies in the
## grass, revealed by mowing, waiting to be driven over. A glowing orb told the
## player "something is here"; the object tells them WHAT is here, which is the
## whole point of an evidence hunt.
func setup_prop(kind_index: int, ground: Vector3) -> void:
	kind = clampi(kind_index, 0, 1)
	position = ground
	_visual = Node3D.new()
	_visual.name = "Visual"
	add_child(_visual)
	_build_for(kind)
	set_process(true)


## Builds whichever evidence mesh this chapter's slot maps to. Chapters past B1
## reuse the two sculpted meshes until their own art exists, so a slot never
## renders as nothing.
func _build_for(kind_index: int) -> void:
	if kind_index == TOY:
		_build_toy()
	else:
		_build_radio()


func _process(delta: float) -> void:
	if _visual:
		_visual.rotate_y(delta * GameConfig.ITEM_SPIN_RATE)


func _play() -> void:
	var tween := create_tween()
	tween.tween_property(_visual, "position:y", GameConfig.ITEM_RISE_TO,
		GameConfig.ITEM_RISE_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_interval(GameConfig.ITEM_HOLD_TIME)
	tween.tween_property(_visual, "position:y",
		GameConfig.ITEM_RISE_TO + GameConfig.ITEM_FADE_RISE, GameConfig.ITEM_FADE_TIME)
	tween.parallel().tween_method(_set_alpha, 1.0, 0.0, GameConfig.ITEM_FADE_TIME)
	tween.tween_callback(func() -> void:
		finished.emit()
		queue_free())


func _set_alpha(value: float) -> void:
	for m in _materials:
		m.albedo_color.a = value


func _metal(color: Color, metallic: float, roughness: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.metallic = metallic
	m.roughness = roughness
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_materials.append(m)
	return m


func _piece(mesh: Mesh, mat: StandardMaterial3D, pos: Vector3,
		rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	_visual.add_child(mi)
	return mi


## Ellie's plush bear (G7.1). Replaces §9's rusty key: the evidence is hers, so
## the object has to read as a child's toy at a glance from gameplay distance.
##
## Built from spheres and capsules with a flat, slightly rough material — no
## metalness, so it reads as cloth next to the metal radio. Everything is sized
## from TOY_BODY, and the head sits forward of the body so the silhouette is
## legible from the top-down camera rather than only from the side.
func _build_toy() -> void:
	var fur := _metal(GameConfig.TOY_FUR, 0.0, 0.85)
	var muzzle := _metal(GameConfig.TOY_MUZZLE, 0.0, 0.8)
	var ribbon := _metal(GameConfig.TOY_RIBBON, 0.0, 0.6)
	var eye := _metal(GameConfig.TOY_EYE, 0.1, 0.35)
	var r := GameConfig.TOY_BODY

	# Belly: a squashed sphere, so it sits rather than floats.
	var belly := SphereMesh.new()
	belly.radius = r
	belly.height = r * 1.85
	belly.radial_segments = 18
	belly.rings = 10
	var belly_node := _piece(belly, fur, Vector3(0.0, r * 0.95, 0.0))
	belly_node.scale = Vector3(1.0, 0.92, 0.86)

	# Head, a touch forward and slightly larger than a real bear's, which is
	# what makes a plush toy read as a plush toy.
	var head := SphereMesh.new()
	head.radius = r * 0.78
	head.height = r * 1.5
	head.radial_segments = 18
	head.rings = 10
	_piece(head, fur, Vector3(0.0, r * 2.35, r * 0.10))

	# Ears: small spheres on top, wide apart.
	var ear := SphereMesh.new()
	ear.radius = r * 0.30
	ear.height = r * 0.58
	ear.radial_segments = 12
	ear.rings = 7
	for side: float in [-1.0, 1.0]:
		_piece(ear, fur, Vector3(side * r * 0.56, r * 2.92, r * 0.02))

	# Muzzle + nose + eyes, all on the forward face.
	var snout := SphereMesh.new()
	snout.radius = r * 0.32
	snout.height = r * 0.55
	snout.radial_segments = 12
	snout.rings = 7
	_piece(snout, muzzle, Vector3(0.0, r * 2.16, r * 0.70))

	var nose := SphereMesh.new()
	nose.radius = r * 0.11
	nose.height = r * 0.20
	nose.radial_segments = 10
	nose.rings = 6
	_piece(nose, eye, Vector3(0.0, r * 2.24, r * 0.92))

	var eyeball := SphereMesh.new()
	eyeball.radius = r * 0.095
	eyeball.height = r * 0.19
	eyeball.radial_segments = 10
	eyeball.rings = 6
	for side: float in [-1.0, 1.0]:
		_piece(eyeball, eye, Vector3(side * r * 0.28, r * 2.55, r * 0.66))

	# Arms and legs: capsules, angled out so the shape stays readable overhead.
	var limb := CapsuleMesh.new()
	limb.radius = r * 0.26
	limb.height = r * 1.05
	limb.radial_segments = 10
	limb.rings = 4
	for side: float in [-1.0, 1.0]:
		_piece(limb, fur, Vector3(side * r * 0.95, r * 1.30, r * 0.05),
			Vector3(0.0, 0.0, side * -0.95))

	var leg := CapsuleMesh.new()
	leg.radius = r * 0.30
	leg.height = r * 1.0
	leg.radial_segments = 10
	leg.rings = 4
	for side: float in [-1.0, 1.0]:
		_piece(leg, fur, Vector3(side * r * 0.52, r * 0.32, r * 0.22),
			Vector3(PI * 0.42, 0.0, side * -0.28))

	# The ribbon is the one saturated note: it is what makes the toy identifiable
	# as a specific, remembered object rather than generic set dressing.
	# No rotation: TorusMesh already lies in XZ, which IS a collar. Standing it up
	# put the loop front-to-back, buried inside the body. It also has to reach
	# WIDER than the head (0.78r) and sit below the head's underside, or the
	# top-down camera never sees it.
	var bow := TorusMesh.new()
	bow.inner_radius = r * 0.66
	bow.outer_radius = r * 0.92
	bow.rings = 16
	bow.ring_segments = 8
	_piece(bow, ribbon, Vector3(0.0, r * 1.62, 0.0))
	# Knot on the chest, angled forward, which is the part actually facing the
	# camera in play.
	var knot := SphereMesh.new()
	knot.radius = r * 0.17
	knot.height = r * 0.30
	knot.radial_segments = 10
	knot.rings = 6
	_piece(knot, ribbon, Vector3(0.0, r * 1.66, r * 0.74))


## Brown case + dark grille + 3 metal wires + 2 knobs + tilted antenna (§9).
## The exact browns are not given in the spec.
func _build_radio() -> void:
	var case_mat := _metal(Color(0.36, 0.24, 0.15), 0.1, 0.65)
	var dark := _metal(Color(0.10, 0.09, 0.09), 0.2, 0.5)
	var steel := _metal(Color(0.66, 0.68, 0.70), 0.85, 0.3)

	var body := BoxMesh.new()
	body.size = GameConfig.RADIO_BOX
	_piece(body, case_mat, Vector3.ZERO)

	var grille := BoxMesh.new()
	grille.size = Vector3(0.19, 0.19, 0.012)
	_piece(grille, dark, Vector3(-0.10, 0.0, GameConfig.RADIO_BOX.z * 0.5 + 0.004))

	var wire := BoxMesh.new()
	wire.size = Vector3(0.20, 0.008, 0.006)
	for i in 3:
		_piece(wire, steel, Vector3(-0.10, -0.055 + float(i) * 0.055,
			GameConfig.RADIO_BOX.z * 0.5 + 0.012))

	var knob := CylinderMesh.new()
	knob.top_radius = 0.032
	knob.bottom_radius = 0.032
	knob.height = 0.02
	knob.radial_segments = 12
	for i in 2:
		_piece(knob, dark, Vector3(0.12, 0.055 - float(i) * 0.11,
			GameConfig.RADIO_BOX.z * 0.5 + 0.01), Vector3(PI * 0.5, 0.0, 0.0))

	var antenna := CylinderMesh.new()
	antenna.top_radius = 0.004
	antenna.bottom_radius = 0.007
	antenna.height = 0.34
	antenna.radial_segments = 6
	_piece(antenna, steel, Vector3(0.17, 0.19, 0.0), Vector3(0.0, 0.0, -0.45))
