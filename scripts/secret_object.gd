class_name SecretObject
extends Node3D
## A thing buried under the lawn. It is invisible while the grass above it is
## standing, fades in as that grass gets cut, and "pops" with light, particles
## and a chime once enough of its patch is mowed.
##
## The LawnManager finds these via the "secret" group and drives set_exposure().

signal discovered(display_name: String)

@export var display_name: String = "Ancient Stone Hatch"
## World-space radius of the grass patch that hides this object.
@export var reveal_radius: float = 2.4
## Fraction of that patch that must be cut before the object is fully revealed.
@export var reveal_threshold: float = 0.8
@export var buried_depth: float = 0.5

var exposure: float = 0.0
var is_discovered: bool = false

var _visual: Node3D
var _stone_mat: StandardMaterial3D
var _rune_mat: StandardMaterial3D
var _fading_mats: Array[StandardMaterial3D] = []
var _light: OmniLight3D
var _burst: GPUParticles3D
var _chime: AudioStreamPlayer3D
var _thud: AudioStreamPlayer3D
var _pulse: float = 0.0


func _ready() -> void:
	add_to_group("secret")
	_build()
	_apply_exposure(0.0)


func get_reveal_radius() -> float:
	return reveal_radius


func set_exposure(ratio: float) -> void:
	exposure = clampf(ratio, 0.0, 1.0)
	_apply_exposure(exposure)
	if not is_discovered and exposure >= reveal_threshold:
		_discover()


func _apply_exposure(ratio: float) -> void:
	if _visual == null or is_discovered:
		# Once revealed the tween owns the transform and the materials go opaque.
		return
	_visual.visible = ratio > 0.015
	# Fade in and rise out of the soil as the grass above is cut away.
	_visual.position.y = lerpf(-buried_depth, 0.0, ease(ratio, 0.6))
	var alpha := clampf(ratio * 1.6, 0.0, 1.0)
	for m in _fading_mats:
		m.albedo_color.a = alpha
	if _rune_mat:
		_rune_mat.emission_energy_multiplier = 0.15 + 0.5 * ratio


func _process(delta: float) -> void:
	if not is_discovered:
		return
	_pulse += delta * 2.0
	var glow := 1.0 + 0.35 * sin(_pulse)
	if _rune_mat:
		_rune_mat.emission_energy_multiplier = glow
	if _light:
		_light.light_energy = 1.4 + 0.35 * sin(_pulse * 1.3)
	if _visual:
		_visual.rotation.y += delta * 0.12


func _discover() -> void:
	is_discovered = true

	# Fully uncovered: render opaque so the inlays sort correctly.
	for m in _fading_mats:
		m.albedo_color.a = 1.0
		m.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED

	if _burst:
		_burst.restart()
		_burst.emitting = true
	if _thud:
		_thud.play()
	if _chime:
		_chime.play()

	var tween := create_tween().set_parallel(true)
	if _visual:
		_visual.scale = Vector3(0.8, 0.8, 0.8)
		tween.tween_property(_visual, "scale", Vector3.ONE, 0.6) \
			.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		tween.tween_property(_visual, "position:y", 0.14, 0.5) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if _light:
		_light.light_energy = 0.0
		tween.tween_property(_light, "light_energy", 1.6, 0.7)

	discovered.emit(display_name)


# ---------------------------------------------------------------- construction

func _build() -> void:
	_visual = Node3D.new()
	_visual.name = "Visual"
	add_child(_visual)

	_stone_mat = StandardMaterial3D.new()
	_stone_mat.albedo_color = Color(0.30, 0.29, 0.27, 1.0)
	_stone_mat.roughness = 0.95
	_stone_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_stone_mat.cull_mode = BaseMaterial3D.CULL_BACK

	_rune_mat = StandardMaterial3D.new()
	_rune_mat.albedo_color = Color(0.34, 0.54, 0.26, 1.0)
	_rune_mat.emission_enabled = true
	_rune_mat.emission = Color(0.45, 1.0, 0.55)
	_rune_mat.emission_energy_multiplier = 0.6
	_rune_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_fading_mats = [_stone_mat, _rune_mat]

	# Hexagonal stone slab.
	var slab := CylinderMesh.new()
	slab.top_radius = 1.02
	slab.bottom_radius = 1.16
	slab.height = 0.24
	slab.radial_segments = 6
	slab.rings = 1
	var slab_mi := MeshInstance3D.new()
	slab_mi.name = "Slab"
	slab_mi.mesh = slab
	slab_mi.material_override = _stone_mat
	slab_mi.position = Vector3(0.0, 0.10, 0.0)
	slab_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_visual.add_child(slab_mi)

	# Glowing rune ring inlaid in the slab face.
	var ring := TorusMesh.new()
	ring.inner_radius = 0.62
	ring.outer_radius = 0.74
	ring.rings = 24
	ring.ring_segments = 8
	var ring_mi := MeshInstance3D.new()
	ring_mi.name = "RuneRing"
	ring_mi.mesh = ring
	ring_mi.material_override = _rune_mat
	ring_mi.position = Vector3(0.0, 0.23, 0.0)
	ring_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_visual.add_child(ring_mi)

	# Six rune marks around the ring.
	for i in 6:
		var a := TAU * float(i) / 6.0
		var mark := BoxMesh.new()
		mark.size = Vector3(0.09, 0.05, 0.26)
		var mark_mi := MeshInstance3D.new()
		mark_mi.mesh = mark
		mark_mi.material_override = _rune_mat
		mark_mi.position = Vector3(cos(a) * 0.42, 0.23, sin(a) * 0.42)
		mark_mi.rotation.y = -a
		mark_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_visual.add_child(mark_mi)

	# Iron pull ring in the middle.
	var iron := StandardMaterial3D.new()
	iron.albedo_color = Color(0.18, 0.16, 0.15, 1.0)
	iron.metallic = 0.8
	iron.roughness = 0.45
	iron.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_fading_mats.append(iron)
	var handle := TorusMesh.new()
	handle.inner_radius = 0.13
	handle.outer_radius = 0.2
	handle.rings = 16
	handle.ring_segments = 8
	var handle_mi := MeshInstance3D.new()
	handle_mi.name = "Handle"
	handle_mi.mesh = handle
	handle_mi.material_override = iron
	handle_mi.position = Vector3(0.0, 0.26, 0.0)
	handle_mi.rotation.x = deg_to_rad(70.0)
	handle_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_visual.add_child(handle_mi)

	_light = OmniLight3D.new()
	_light.name = "Glow"
	_light.light_color = Color(0.6, 1.0, 0.6)
	_light.light_energy = 0.0
	_light.omni_range = 6.0
	_light.shadow_enabled = false
	_light.position = Vector3(0.0, 0.9, 0.0)
	_visual.add_child(_light)

	_burst = _make_burst()
	_visual.add_child(_burst)

	# Both clips are generated up front: synthesising one during the reveal
	# would hitch a frame.
	_chime = AudioStreamPlayer3D.new()
	_chime.name = "Chime"
	_chime.unit_size = 24.0
	_chime.max_distance = 60.0
	_chime.stream = Sfx.make_chime()
	_visual.add_child(_chime)

	_thud = AudioStreamPlayer3D.new()
	_thud.name = "Thud"
	_thud.unit_size = 26.0
	_thud.max_distance = 60.0
	_thud.volume_db = -2.0
	_thud.stream = Sfx.make_thud()
	_visual.add_child(_thud)


func _make_burst() -> GPUParticles3D:
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE_SURFACE
	pm.emission_sphere_radius = 0.7
	pm.direction = Vector3(0.0, 1.0, 0.0)
	pm.spread = 55.0
	pm.initial_velocity_min = 2.5
	pm.initial_velocity_max = 6.0
	pm.gravity = Vector3(0.0, -6.0, 0.0)
	pm.scale_min = 0.5
	pm.scale_max = 1.4
	pm.color = Color(0.75, 1.0, 0.6, 1.0)
	pm.angular_velocity_min = -360.0
	pm.angular_velocity_max = 360.0

	var mesh := QuadMesh.new()
	mesh.size = Vector2(0.09, 0.09)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.85, 1.0, 0.7, 1.0)
	mesh.material = mat

	var p := GPUParticles3D.new()
	p.name = "RevealBurst"
	p.process_material = pm
	p.draw_pass_1 = mesh
	p.amount = 90
	p.lifetime = 1.4
	p.one_shot = true
	p.explosiveness = 0.95
	p.emitting = false
	p.local_coords = false
	return p
