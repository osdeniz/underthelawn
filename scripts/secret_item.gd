class_name SecretItem
extends Node3D
## The object dug out of the lawn (§9): rises from -0.15 to +0.7 over 0.7 s
## while spinning, holds 1.4 s, then drifts up and fades.
##
## kind 0 = rusty key, kind 1 = old radio. Both are primitive combinations.

signal finished()

const KEY := 0
const RADIO := 1

## Display data for the reveal card (§16).
const INFO := [
	{ "emoji": "🔑", "name": "Paslı Anahtar", "line": "It looks old. What does it open?" },
	{ "emoji": "📻", "name": "Eski Radyo", "line": "It still hums faintly." },
]

var kind := KEY

var _visual: Node3D
var _materials: Array[StandardMaterial3D] = []


static func info_for(kind_index: int) -> Dictionary:
	return INFO[clampi(kind_index, 0, INFO.size() - 1)]


func setup(kind_index: int, ground: Vector3) -> void:
	kind = clampi(kind_index, 0, 1)
	position = ground
	_visual = Node3D.new()
	_visual.name = "Visual"
	_visual.position.y = GameConfig.ITEM_RISE_FROM
	add_child(_visual)
	if kind == KEY:
		_build_key()
	else:
		_build_radio()
	_play()


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


## Upright torus ring + shaft + two teeth, gold-brown, metalness 0.8 (§9).
func _build_key() -> void:
	var gold := _metal(GameConfig.KEY_COLOR, GameConfig.KEY_METALLIC, 0.3)

	var ring := TorusMesh.new()
	ring.inner_radius = GameConfig.KEY_TORUS_RADIUS * 0.55
	ring.outer_radius = GameConfig.KEY_TORUS_RADIUS
	ring.rings = 20
	ring.ring_segments = 10
	# Upright: the torus lies in XZ by default, so stand it on its edge.
	_piece(ring, gold, Vector3(0.0, 0.12, 0.0), Vector3(PI * 0.5, 0.0, 0.0))

	var shaft := CylinderMesh.new()
	shaft.top_radius = 0.022
	shaft.bottom_radius = 0.022
	shaft.height = 0.28
	shaft.radial_segments = 10
	_piece(shaft, gold, Vector3(0.0, -0.06, 0.0))

	var tooth := BoxMesh.new()
	tooth.size = Vector3(0.055, 0.035, 0.022)
	_piece(tooth, gold, Vector3(0.036, -0.13, 0.0))
	_piece(tooth, gold, Vector3(0.036, -0.185, 0.0))


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
