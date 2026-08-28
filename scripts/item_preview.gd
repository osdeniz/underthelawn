class_name ItemPreview
extends SubViewportContainer
## Renders an evidence object into the reveal card (G12.8).
##
## The card used to show an emoji, which is invisible on a phone: iOS's default
## font has no colour-emoji glyphs and Godot does not fall back to the system
## emoji font. Showing the actual mesh is font-independent, always matches what
## is lying in the grass, and needs no art.

const VIEW_SIZE := Vector2i(320, 320)
## The corkboard pins sixteen of these at once, so it asks for a small,
## still, render-once preview instead (G12.10). Set both BEFORE add_child:
## _ready is what reads them.
var view_size := VIEW_SIZE
var spin := true

var _viewport: SubViewport
var _pivot: Node3D
var _item: SecretItem
## show_item may be called before this node enters the tree (the corkboard
## builds a whole card and adds it afterwards), and _ready has not run yet.
var _pending_id := ""


func _ready() -> void:
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_viewport = SubViewport.new()
	_viewport.size = view_size
	_viewport.transparent_bg = true
	# A still preview costs one frame of rendering and then nothing.
	_viewport.render_target_update_mode = (SubViewport.UPDATE_ALWAYS if spin
		else SubViewport.UPDATE_ONCE)
	# Its own world: the card must not pick up the lawn's camera or lighting.
	_viewport.own_world_3d = true
	_viewport.world_3d = World3D.new()
	add_child(_viewport)

	_pivot = Node3D.new()
	_viewport.add_child(_pivot)
	if _pending_id != "":
		var wanted := _pending_id
		_pending_id = ""
		# Deferred: the lights and camera below are not built yet.
		show_item.call_deferred(wanted)

	var camera := Camera3D.new()
	camera.position = Vector3(0.0, 0.46, 0.95)
	camera.rotation.x = -0.44
	camera.fov = 40.0
	_viewport.add_child(camera)

	# Two lights and a soft ambient, tuned so a dark object still reads.
	var key := DirectionalLight3D.new()
	key.rotation = Vector3(-0.8, -0.7, 0.0)
	key.light_energy = 1.5
	_viewport.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation = Vector3(-0.3, 2.3, 0.0)
	fill.light_energy = 0.6
	fill.light_color = Color(0.85, 0.88, 1.0)
	_viewport.add_child(fill)
	var env := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_CLEAR_COLOR
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.55, 0.55, 0.58)
	environment.ambient_light_energy = 0.9
	env.environment = environment
	_viewport.add_child(env)

	# A spinning preview redraws a whole little 3D world — two lights, a camera
	# and an environment — every frame. The reveal card is hidden for almost the
	# entire chapter, and UPDATE_ALWAYS does not care whether anyone can see it,
	# so the spin has to be switched with the card (G16). Last, so everything it
	# reaches for is already built.
	visibility_changed.connect(_sync_spin)
	_sync_spin()


## Renders only while the card is actually on screen.
func _sync_spin() -> void:
	if not spin:
		return
	var seen := is_visible_in_tree()
	set_process(seen)
	if _viewport == null:
		return
	_viewport.render_target_update_mode = (SubViewport.UPDATE_ALWAYS
		if seen else SubViewport.UPDATE_DISABLED)


## Swaps in a new object. The pivot turns slowly so the shape reads in the round.
func show_item(evidence_id: String) -> void:
	if _pivot == null:
		_pending_id = evidence_id
		return
	if _item != null and is_instance_valid(_item):
		_item.queue_free()
	_item = SecretItem.new()
	_pivot.add_child(_item)
	_item.setup_by_id(evidence_id, Vector3.ZERO)
	# Objects vary a lot in size; frame them all to a similar height.
	_item.scale = Vector3.ONE * _fit_scale(evidence_id)
	# Most of these meshes are built standing on y=0 for the lawn, so the pivot
	# drops to put their middle, not their feet, in front of the camera.
	_item.position.y = -_item_height(evidence_id) * 0.5
	_pivot.rotation.y = 0.0 if spin else -0.5
	if not spin and _viewport != null:
		# The object changed, so the one-shot render has to happen again.
		_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE


## Roughly how tall each object stands, for centring it in the card.
func _item_height(evidence_id: String) -> float:
	match evidence_id:
		"ellie": return 0.55
		"rabbit", "toy": return 0.45
		"radio", "receiver", "can", "candle", "flashlight": return 0.28
		"battery", "apple": return 0.24
		"crate_lid": return 0.12
		"boot", "seedlings", "gap": return 0.30
		"ribbon", "thread", "arrow", "prints", "stones", "hatch": return 0.12
	return 0.14


## Per-object framing. Measured by eye against the card, since these meshes were
## authored at world scale for the lawn, not for a portrait.
func _fit_scale(evidence_id: String) -> float:
	match evidence_id:
		"ellie": return 0.80
		"hatch", "prints", "arrow", "stones", "seedlings": return 0.95
		"gap": return 0.95
		"ribbon", "thread", "patch", "candle": return 1.55
		"boot", "can", "flashlight", "drawing", "map", "notebook": return 1.15
		"note", "leaflet", "letter", "log", "headline": return 1.05
		"number_log": return 1.05
		"battery", "apple": return 1.30
		"crate_lid": return 1.15
	return 1.10


func _process(delta: float) -> void:
	if _pivot != null and spin:
		_pivot.rotation.y += delta * 0.7
