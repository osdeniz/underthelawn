class_name FindMarker
extends Node3D
## The mark a find leaves behind (G12.6): a ring on the ground, a thin beam of
## light, and the object's own icon lying at its foot.
##
## It flares for a moment and then settles to a faint, permanent shaft for the
## rest of the chapter. The point is spatial memory — at a glance the player can
## see where they have already been rewarded, which turns a mown lawn into a map
## of their own search.

const FLARE_TIME := 2.4

var _beam: MeshInstance3D
var _beam_mat: StandardMaterial3D
var _ring_mat: StandardMaterial3D


static func spawn(parent: Node3D, at: Vector3, icon: String) -> FindMarker:
	var marker := FindMarker.new()
	marker.name = "FindMarker"
	parent.add_child(marker)
	marker.position = Vector3(at.x, 0.0, at.z)
	marker._build(icon)
	return marker


func _build(icon: String) -> void:
	# Ground ring: a flat disc, unshaded and additive so it glows on any palette.
	var disc := CylinderMesh.new()
	disc.top_radius = GameConfig.FIND_MARK_RADIUS
	disc.bottom_radius = GameConfig.FIND_MARK_RADIUS
	disc.height = 0.01
	disc.radial_segments = 20
	_ring_mat = _glow_mat(GameConfig.FIND_MARK_COLOR)
	var ring := MeshInstance3D.new()
	ring.mesh = disc
	ring.material_override = _ring_mat
	ring.position.y = 0.03
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ring)

	# Beam: a tall, thin cylinder. Cheaper and steadier than particles, and it
	# reads from across the lawn, which is the whole job.
	var column := CylinderMesh.new()
	column.top_radius = GameConfig.FIND_MARK_RADIUS * 0.30
	column.bottom_radius = GameConfig.FIND_MARK_RADIUS * 0.52
	column.height = GameConfig.FIND_MARK_BEAM_HEIGHT
	column.radial_segments = 12
	_beam_mat = _glow_mat(GameConfig.FIND_MARK_COLOR)
	_beam = MeshInstance3D.new()
	_beam.mesh = column
	_beam.material_override = _beam_mat
	_beam.position.y = GameConfig.FIND_MARK_BEAM_HEIGHT * 0.5
	_beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_beam)

	# The object's icon stays on the ground: what was found, not just where.
	if icon != "":
		var label := Label3D.new()
		label.text = icon
		label.font_size = 96
		label.pixel_size = 0.004
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.no_depth_test = false
		label.position.y = 0.22
		add_child(label)

	# Bright flare, then a faint shaft that lasts the rest of the chapter.
	_set_alpha(GameConfig.FIND_MARK_FLARE_ALPHA)
	var tw := create_tween()
	tw.tween_method(_set_alpha, GameConfig.FIND_MARK_FLARE_ALPHA,
		GameConfig.FIND_MARK_IDLE_ALPHA, FLARE_TIME) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _glow_mat(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	return mat


func _set_alpha(value: float) -> void:
	_ring_mat.albedo_color.a = value
	_beam_mat.albedo_color.a = value * 0.55
