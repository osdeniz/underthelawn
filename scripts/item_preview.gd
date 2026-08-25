class_name ItemPreview
extends SubViewportContainer
## Renders an evidence object into the reveal card (G12.8).
##
## The card used to show an emoji, which is invisible on a phone: iOS's default
## font has no colour-emoji glyphs and Godot does not fall back to the system
## emoji font. Showing the actual mesh is font-independent, always matches what
## is lying in the grass, and needs no art.

const VIEW_SIZE := Vector2i(320, 320)

var _viewport: SubViewport
var _pivot: Node3D
var _item: SecretItem


func _ready() -> void:
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_viewport = SubViewport.new()
	_viewport.size = VIEW_SIZE
	_viewport.transparent_bg = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	# Its own world: the card must not pick up the lawn's camera or lighting.
	_viewport.own_world_3d = true
	_viewport.world_3d = World3D.new()
	add_child(_viewport)

	_pivot = Node3D.new()
	_viewport.add_child(_pivot)

	var camera := Camera3D.new()
	camera.position = Vector3(0.0, 0.55, 1.15)
	camera.rotation.x = -0.42
	camera.fov = 42.0
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


## Swaps in a new object. The pivot turns slowly so the shape reads in the round.
func show_item(evidence_id: String) -> void:
	if _item != null and is_instance_valid(_item):
		_item.queue_free()
	_item = SecretItem.new()
	_pivot.add_child(_item)
	_item.setup_by_id(evidence_id, Vector3.ZERO)
	# Objects vary a lot in size; frame them all to a similar height.
	_item.scale = Vector3.ONE * _fit_scale(evidence_id)
	_pivot.rotation.y = 0.0


## Per-object framing. Measured by eye against the card, since these meshes were
## authored at world scale for the lawn, not for a portrait.
func _fit_scale(evidence_id: String) -> float:
	match evidence_id:
		"ellie": return 1.05
		"hatch", "prints", "arrow", "stones", "seedlings": return 1.25
		"gap": return 1.15
		"ribbon", "thread", "patch", "candle": return 2.0
		"boot", "can", "flashlight", "drawing", "map", "notebook": return 1.6
		"note", "leaflet", "letter", "log", "headline": return 1.4
	return 1.35


func _process(delta: float) -> void:
	if _pivot != null:
		_pivot.rotation.y += delta * 0.7
