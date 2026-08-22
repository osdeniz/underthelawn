class_name SecretGlow
extends Node3D
## The golden shimmer that appears the moment a secret cell is mown (§9).
##
## Emissive sphere r0.15, floating +/-0.16 over 0.8 s, pulsing 1.0..1.3 over
## 0.5 s, spinning, with a looping spark emitter above it. Tapping it collects
## the secret; the hit test lives in Game via camera.project_ray.

signal collected(glow: SecretGlow)

var cell := Vector2i.ZERO
## 0 = key, 1 = radio (index into LawnModel.secret_cells).
var kind := 0
var is_taken := false

var _time := 0.0
var _orb: MeshInstance3D
var _sparks: GPUParticles3D
var _base_y := 0.0


func setup(cell_coords: Vector2i, kind_index: int, ground: Vector3) -> void:
	cell = cell_coords
	kind = kind_index
	_base_y = ground.y + GameConfig.GLOW_HOVER_HEIGHT
	position = Vector3(ground.x, _base_y, ground.z)
	_build()


func tap_radius() -> float:
	return GameConfig.GLOW_TAP_RADIUS


## Called by Game once the player taps it; the visuals stop immediately.
func take() -> void:
	if is_taken:
		return
	is_taken = true
	if _sparks:
		_sparks.emitting = false
	collected.emit(self)
	queue_free()


func _process(delta: float) -> void:
	_time += delta
	# Float, pulse and spin all run off their own periods (§9).
	position.y = _base_y + sin(_time * TAU / GameConfig.GLOW_FLOAT_PERIOD) \
		* GameConfig.GLOW_FLOAT_AMPLITUDE
	var pulse := lerpf(GameConfig.GLOW_PULSE_MIN, GameConfig.GLOW_PULSE_MAX,
		sin(_time * TAU / GameConfig.GLOW_PULSE_PERIOD) * 0.5 + 0.5)
	if _orb:
		_orb.scale = Vector3(pulse, pulse, pulse)
	rotate_y(delta * GameConfig.GLOW_SPIN_RATE)


func _build() -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = GameConfig.GLOW_COLOR
	mat.emission_enabled = true
	mat.emission = GameConfig.GLOW_COLOR
	mat.emission_energy_multiplier = 1.6
	mat.roughness = 0.35

	var sphere := SphereMesh.new()
	sphere.radius = GameConfig.GLOW_RADIUS
	sphere.height = GameConfig.GLOW_RADIUS * 2.0
	sphere.radial_segments = 16
	sphere.rings = 8

	_orb = MeshInstance3D.new()
	_orb.name = "Orb"
	_orb.mesh = sphere
	_orb.material_override = mat
	_orb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_orb)

	var light := OmniLight3D.new()
	light.light_color = GameConfig.GLOW_COLOR
	light.light_energy = 1.1
	light.omni_range = 3.0
	light.shadow_enabled = false
	add_child(light)

	_sparks = _make_sparks()
	add_child(_sparks)


## Looping sparks drifting upwards: birthRate 10, size 0.035 (§9).
func _make_sparks() -> GPUParticles3D:
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = GameConfig.GLOW_RADIUS * 1.3
	pm.direction = Vector3(0.0, 1.0, 0.0)
	pm.spread = 25.0
	pm.initial_velocity_min = 0.18
	pm.initial_velocity_max = 0.45
	pm.gravity = Vector3.ZERO
	pm.scale_min = 0.6
	pm.scale_max = 1.3
	pm.color = GameConfig.GLOW_COLOR

	var quad := QuadMesh.new()
	quad.size = Vector2(GameConfig.SPARK_SIZE, GameConfig.SPARK_SIZE)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.vertex_color_use_as_albedo = true
	mat.albedo_color = GameConfig.GLOW_COLOR
	quad.material = mat

	var lifetime := 1.6
	var p := GPUParticles3D.new()
	p.name = "Sparks"
	p.process_material = pm
	p.draw_pass_1 = quad
	p.lifetime = lifetime
	p.amount = int(GameConfig.SPARK_BIRTH_RATE * lifetime)
	p.local_coords = false
	p.emitting = true
	return p
