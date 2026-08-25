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


## G12.8: every piece of evidence and every echo gets its OWN shape, keyed by
## the id in levels.json. Before this the world only knew two meshes, so a found
## ribbon lay in the grass as a teddy bear and rode home on the driver's back as
## one. Each builder is small on purpose — these read at gameplay distance as a
## silhouette and a colour, not as detail.
func setup_by_id(evidence_id: String, ground: Vector3) -> void:
	position = ground
	_visual = Node3D.new()
	_visual.name = "Visual"
	add_child(_visual)
	_build_by_id(evidence_id)
	set_process(true)


func _build_by_id(evidence_id: String) -> void:
	match evidence_id:
		"rabbit", "toy": _build_toy()
		"radio": _build_radio()
		"boot": _build_boot()
		"gap": _build_gap()
		"ribbon": _build_ribbon()
		"arrow": _build_arrow()
		"prints": _build_prints()
		"can": _build_can()
		"seedlings": _build_seedlings()
		"thread": _build_thread()
		"flashlight": _build_flashlight()
		"note", "leaflet", "letter", "log", "headline": _build_paper(evidence_id)
		"hatch": _build_hatch()
		"stones": _build_stones()
		"ellie": _build_child()
		"drawing", "map": _build_drawing(evidence_id)
		"notebook": _build_notebook()
		"patch": _build_patch()
		"candle": _build_candle()
		_: _build_radio()


## A single rubber boot, fallen on its side.
func _build_boot() -> void:
	var rubber := _metal(Color(0.62, 0.16, 0.14), 0.0, 0.6)
	var sole := _metal(Color(0.16, 0.15, 0.15), 0.0, 0.9)
	var shaft := CylinderMesh.new()
	shaft.top_radius = 0.10
	shaft.bottom_radius = 0.11
	shaft.height = 0.34
	shaft.radial_segments = 12
	_piece(shaft, rubber, Vector3(0.0, 0.11, 0.0), Vector3(PI * 0.5, 0.0, 0.2))
	var foot := BoxMesh.new()
	foot.size = Vector3(0.16, 0.13, 0.26)
	_piece(foot, rubber, Vector3(0.06, 0.07, 0.24), Vector3(0.0, 0.2, 0.0))
	var pad := BoxMesh.new()
	pad.size = Vector3(0.18, 0.04, 0.28)
	_piece(pad, sole, Vector3(0.06, 0.02, 0.24), Vector3(0.0, 0.2, 0.0))


## A child-sized hole scraped under a fence: a dark mouth and the spoil beside it.
func _build_gap() -> void:
	var soil := _metal(Color(0.30, 0.22, 0.14), 0.0, 1.0)
	var dark := _metal(Color(0.04, 0.04, 0.05), 0.0, 1.0)
	var hole := SphereMesh.new()
	hole.radius = 0.26
	hole.height = 0.24
	hole.radial_segments = 14
	var mouth := _piece(hole, dark, Vector3(0.0, 0.02, 0.0))
	mouth.scale = Vector3(1.0, 0.35, 0.7)
	for side: float in [-1.0, 1.0]:
		var heap := SphereMesh.new()
		heap.radius = 0.16
		heap.height = 0.16
		heap.radial_segments = 10
		var mound := _piece(heap, soil, Vector3(side * 0.24, 0.05, 0.10))
		mound.scale = Vector3(1.2, 0.5, 1.0)
	# Two fence pickets above it, so the hole reads as being UNDER something.
	var wood := _metal(Color(0.52, 0.40, 0.26), 0.0, 0.9)
	for x: float in [-0.16, 0.16]:
		var picket := BoxMesh.new()
		picket.size = Vector3(0.09, 0.42, 0.04)
		_piece(picket, wood, Vector3(x, 0.32, -0.14))


## A hair ribbon, tied and trailing.
func _build_ribbon() -> void:
	var silk := _metal(Color(0.92, 0.80, 0.26), 0.0, 0.5)
	var knot := SphereMesh.new()
	knot.radius = 0.06
	knot.height = 0.10
	knot.radial_segments = 10
	_piece(knot, silk, Vector3(0.0, 0.06, 0.0))
	for side: float in [-1.0, 1.0]:
		var loop := TorusMesh.new()
		loop.inner_radius = 0.05
		loop.outer_radius = 0.13
		loop.rings = 12
		loop.ring_segments = 6
		var bow := _piece(loop, silk, Vector3(side * 0.13, 0.06, 0.0),
			Vector3(0.0, 0.0, PI * 0.5))
		bow.scale = Vector3(1.0, 1.0, 0.35)
		var tail := BoxMesh.new()
		tail.size = Vector3(0.05, 0.01, 0.22)
		_piece(tail, silk, Vector3(side * 0.07, 0.02, 0.14),
			Vector3(0.0, side * 0.4, 0.0))


## An arrow scratched into the dirt.
func _build_arrow() -> void:
	var scratch := _metal(Color(0.24, 0.17, 0.10), 0.0, 1.0)
	var shaft := BoxMesh.new()
	shaft.size = Vector3(0.06, 0.02, 0.44)
	_piece(shaft, scratch, Vector3(0.0, 0.01, 0.0))
	for side: float in [-1.0, 1.0]:
		var barb := BoxMesh.new()
		barb.size = Vector3(0.05, 0.02, 0.20)
		_piece(barb, scratch, Vector3(side * 0.07, 0.01, -0.16),
			Vector3(0.0, side * 0.7, 0.0))


## Two sets of footprints pressed into mud, one small and one bare and large.
func _build_prints() -> void:
	var mud := _metal(Color(0.20, 0.15, 0.10), 0.0, 1.0)
	for i in 3:
		var small := SphereMesh.new()
		small.radius = 0.07
		small.height = 0.05
		small.radial_segments = 10
		var boot_print := _piece(small, mud,
			Vector3(-0.14, 0.01, -0.16 + float(i) * 0.17))
		boot_print.scale = Vector3(1.0, 0.4, 1.5)
		var big := SphereMesh.new()
		big.radius = 0.09
		big.height = 0.05
		big.radial_segments = 10
		var foot := _piece(big, mud,
			Vector3(0.16, 0.01, -0.10 + float(i) * 0.17))
		foot.scale = Vector3(1.0, 0.4, 1.7)


## A tin can, opened cleanly, its lid bent back.
func _build_can() -> void:
	var tin := _metal(Color(0.72, 0.73, 0.70), 0.75, 0.35)
	var label := _metal(Color(0.58, 0.32, 0.18), 0.0, 0.85)
	var body := CylinderMesh.new()
	body.top_radius = 0.11
	body.bottom_radius = 0.11
	body.height = 0.20
	body.radial_segments = 14
	_piece(body, tin, Vector3(0.0, 0.10, 0.0))
	var band := CylinderMesh.new()
	band.top_radius = 0.113
	band.bottom_radius = 0.113
	band.height = 0.11
	band.radial_segments = 14
	_piece(band, label, Vector3(0.0, 0.09, 0.0))
	var lid := CylinderMesh.new()
	lid.top_radius = 0.10
	lid.bottom_radius = 0.10
	lid.height = 0.012
	lid.radial_segments = 14
	_piece(lid, tin, Vector3(0.11, 0.21, 0.05), Vector3(0.9, 0.0, 0.3))


## Seedlings in a shallow tray, watered this week.
func _build_seedlings() -> void:
	var tray := _metal(Color(0.42, 0.26, 0.16), 0.0, 0.95)
	var soil := _metal(Color(0.18, 0.13, 0.09), 0.0, 1.0)
	var leaf := _metal(Color(0.24, 0.58, 0.22), 0.0, 0.9)
	var box := BoxMesh.new()
	box.size = Vector3(0.44, 0.10, 0.28)
	_piece(box, tray, Vector3(0.0, 0.05, 0.0))
	var dirt := BoxMesh.new()
	dirt.size = Vector3(0.40, 0.03, 0.24)
	_piece(dirt, soil, Vector3(0.0, 0.10, 0.0))
	for i in 4:
		var x := -0.15 + float(i) * 0.10
		var stem := CylinderMesh.new()
		stem.top_radius = 0.008
		stem.bottom_radius = 0.010
		stem.height = 0.14
		stem.radial_segments = 6
		_piece(stem, leaf, Vector3(x, 0.18, 0.0))
		for side: float in [-1.0, 1.0]:
			var blade := BoxMesh.new()
			blade.size = Vector3(0.09, 0.008, 0.05)
			_piece(blade, leaf, Vector3(x + side * 0.05, 0.24, 0.0),
				Vector3(0.0, 0.0, side * 0.5))


## A thread of wool caught on something, curled on the ground.
func _build_thread() -> void:
	var wool := _metal(Color(0.72, 0.40, 0.42), 0.0, 0.95)
	for i in 7:
		var angle := float(i) * 0.9
		var strand := CylinderMesh.new()
		strand.top_radius = 0.010
		strand.bottom_radius = 0.010
		strand.height = 0.12
		strand.radial_segments = 6
		_piece(strand, wool,
			Vector3(sin(angle) * 0.10, 0.012, cos(angle) * 0.10),
			Vector3(PI * 0.5, angle, 0.0))


## A police flashlight, lens forward.
func _build_flashlight() -> void:
	var shell := _metal(Color(0.16, 0.17, 0.19), 0.45, 0.4)
	var lens := _metal(Color(0.92, 0.90, 0.72), 0.1, 0.15)
	var body := CylinderMesh.new()
	body.top_radius = 0.045
	body.bottom_radius = 0.05
	body.height = 0.40
	body.radial_segments = 12
	_piece(body, shell, Vector3(0.0, 0.05, 0.0), Vector3(PI * 0.5, 0.0, 0.0))
	var head := CylinderMesh.new()
	head.top_radius = 0.085
	head.bottom_radius = 0.055
	head.height = 0.10
	head.radial_segments = 12
	_piece(head, shell, Vector3(0.0, 0.05, -0.24), Vector3(PI * 0.5, 0.0, 0.0))
	var glass := CylinderMesh.new()
	glass.top_radius = 0.075
	glass.bottom_radius = 0.075
	glass.height = 0.012
	glass.radial_segments = 12
	_piece(glass, lens, Vector3(0.0, 0.05, -0.29), Vector3(PI * 0.5, 0.0, 0.0))


## A sheet of paper: the note, the leaflet, the headline, the broadcast log.
func _build_paper(kind_id: String) -> void:
	var stock := Color(0.88, 0.85, 0.76)
	if kind_id == "headline":
		stock = Color(0.82, 0.78, 0.62)      # newsprint, yellowed
	elif kind_id == "leaflet":
		stock = Color(0.86, 0.80, 0.68)
	var paper := _metal(stock, 0.0, 0.95)
	var ink := _metal(Color(0.20, 0.19, 0.18), 0.0, 0.95)
	var sheet := BoxMesh.new()
	sheet.size = Vector3(0.30, 0.008, 0.40)
	_piece(sheet, paper, Vector3(0.0, 0.02, 0.0), Vector3(0.0, 0.3, 0.0))
	# Ruled lines of "text" so it reads as printed rather than blank.
	for i in 4:
		var line := BoxMesh.new()
		line.size = Vector3(0.20 - float(i) * 0.02, 0.002, 0.022)
		_piece(line, ink, Vector3(0.0, 0.026, -0.11 + float(i) * 0.075),
			Vector3(0.0, 0.3, 0.0))


## A child's notebook, half open.
func _build_notebook() -> void:
	var cover := _metal(Color(0.32, 0.42, 0.62), 0.0, 0.9)
	var pages := _metal(Color(0.90, 0.88, 0.82), 0.0, 0.95)
	var back := BoxMesh.new()
	back.size = Vector3(0.26, 0.012, 0.34)
	_piece(back, cover, Vector3(0.0, 0.02, 0.0))
	var leaf := BoxMesh.new()
	leaf.size = Vector3(0.24, 0.02, 0.32)
	_piece(leaf, pages, Vector3(0.0, 0.035, 0.0))
	var lid := BoxMesh.new()
	lid.size = Vector3(0.26, 0.012, 0.34)
	_piece(lid, cover, Vector3(0.0, 0.14, -0.20), Vector3(-1.0, 0.0, 0.0))


## A cellar hatch set into the ground, hinges oiled.
func _build_hatch() -> void:
	var plank := _metal(Color(0.42, 0.31, 0.20), 0.0, 0.92)
	var iron := _metal(Color(0.26, 0.25, 0.24), 0.6, 0.45)
	for i in 4:
		var board := BoxMesh.new()
		board.size = Vector3(0.13, 0.05, 0.56)
		_piece(board, plank, Vector3(-0.21 + float(i) * 0.14, 0.03, 0.0))
	for z: float in [-0.20, 0.20]:
		var strap := BoxMesh.new()
		strap.size = Vector3(0.58, 0.02, 0.06)
		_piece(strap, iron, Vector3(0.0, 0.06, z))
	var ring := TorusMesh.new()
	ring.inner_radius = 0.045
	ring.outer_radius = 0.07
	ring.rings = 12
	ring.ring_segments = 6
	_piece(ring, iron, Vector3(0.20, 0.08, 0.0), Vector3(PI * 0.5, 0.0, 0.0))


## Stones laid out in a ring: a game, not a warning.
func _build_stones() -> void:
	var rock := _metal(Color(0.55, 0.54, 0.51), 0.0, 0.95)
	for i in 7:
		var angle := TAU * float(i) / 7.0
		var pebble := SphereMesh.new()
		pebble.radius = 0.06
		pebble.height = 0.09
		pebble.radial_segments = 8
		var stone := _piece(pebble, rock,
			Vector3(sin(angle) * 0.22, 0.035, cos(angle) * 0.22))
		stone.scale = Vector3(1.1, 0.7, 0.9)


## Ellie herself, sitting: the one "evidence" that is a person.
func _build_child() -> void:
	var coat := _metal(Color(0.86, 0.62, 0.20), 0.0, 0.9)
	var skin := _metal(Color(0.80, 0.64, 0.50), 0.0, 0.8)
	var hair := _metal(Color(0.34, 0.22, 0.13), 0.0, 0.9)
	var legs := _metal(Color(0.30, 0.34, 0.44), 0.0, 0.9)
	var torso := CapsuleMesh.new()
	torso.radius = 0.11
	torso.height = 0.30
	torso.radial_segments = 10
	_piece(torso, coat, Vector3(0.0, 0.24, 0.0))
	var head := SphereMesh.new()
	head.radius = 0.09
	head.height = 0.18
	head.radial_segments = 12
	_piece(head, skin, Vector3(0.0, 0.44, 0.0))
	var cap := SphereMesh.new()
	cap.radius = 0.095
	cap.height = 0.14
	cap.radial_segments = 12
	_piece(cap, hair, Vector3(0.0, 0.47, -0.01))
	for side: float in [-1.0, 1.0]:
		var leg := CapsuleMesh.new()
		leg.radius = 0.045
		leg.height = 0.22
		leg.radial_segments = 8
		_piece(leg, legs, Vector3(side * 0.06, 0.09, 0.12),
			Vector3(PI * 0.42, 0.0, 0.0))


## A child's drawing, or the hand-drawn map fragment.
func _build_drawing(kind_id: String) -> void:
	var paper := _metal(Color(0.90, 0.87, 0.78), 0.0, 0.95)
	var sheet := BoxMesh.new()
	sheet.size = Vector3(0.34, 0.008, 0.26)
	_piece(sheet, paper, Vector3(0.0, 0.02, 0.0), Vector3(0.0, -0.2, 0.0))
	if kind_id == "map":
		var road := _metal(Color(0.35, 0.28, 0.20), 0.0, 0.95)
		for i in 3:
			var leg := BoxMesh.new()
			leg.size = Vector3(0.16, 0.002, 0.02)
			_piece(leg, road, Vector3(-0.08 + float(i) * 0.08, 0.026,
				-0.04 + float(i) * 0.05), Vector3(0.0, -0.2 + float(i) * 0.3, 0.0))
		return
	# The drawing: a ring of seven small marks. Its meaning is never stated.
	var crayon := _metal(Color(0.30, 0.35, 0.62), 0.0, 0.95)
	for i in 7:
		var angle := TAU * float(i) / 7.0
		var mark := BoxMesh.new()
		mark.size = Vector3(0.022, 0.002, 0.022)
		_piece(mark, crayon, Vector3(sin(angle) * 0.08, 0.026, cos(angle) * 0.06),
			Vector3(0.0, angle, 0.0))


## A settlement guard patch, embroidered.
func _build_patch() -> void:
	var cloth := _metal(Color(0.22, 0.30, 0.24), 0.0, 0.95)
	var thread_mat := _metal(Color(0.78, 0.68, 0.30), 0.0, 0.8)
	var badge := CylinderMesh.new()
	badge.top_radius = 0.13
	badge.bottom_radius = 0.13
	badge.height = 0.012
	badge.radial_segments = 14
	_piece(badge, cloth, Vector3(0.0, 0.02, 0.0))
	var rim := TorusMesh.new()
	rim.inner_radius = 0.11
	rim.outer_radius = 0.13
	rim.rings = 16
	rim.ring_segments = 5
	_piece(rim, thread_mat, Vector3(0.0, 0.028, 0.0))
	var bar := BoxMesh.new()
	bar.size = Vector3(0.12, 0.004, 0.03)
	_piece(bar, thread_mat, Vector3(0.0, 0.03, 0.0))


## A memorial candle tin, burned to the base.
func _build_candle() -> void:
	var tin := _metal(Color(0.68, 0.66, 0.62), 0.7, 0.4)
	var wax := _metal(Color(0.86, 0.82, 0.70), 0.0, 0.7)
	var soot := _metal(Color(0.14, 0.13, 0.12), 0.0, 1.0)
	var cup := CylinderMesh.new()
	cup.top_radius = 0.10
	cup.bottom_radius = 0.09
	cup.height = 0.13
	cup.radial_segments = 14
	_piece(cup, tin, Vector3(0.0, 0.065, 0.0))
	var pool := CylinderMesh.new()
	pool.top_radius = 0.085
	pool.bottom_radius = 0.085
	pool.height = 0.03
	pool.radial_segments = 14
	_piece(pool, wax, Vector3(0.0, 0.10, 0.0))
	var wick := CylinderMesh.new()
	wick.top_radius = 0.006
	wick.bottom_radius = 0.006
	wick.height = 0.03
	wick.radial_segments = 5
	_piece(wick, soot, Vector3(0.0, 0.125, 0.0))


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
