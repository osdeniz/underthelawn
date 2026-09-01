class_name Fireflies
extends GPUParticles3D
## Sparks of light over the lawn after the sun is low (G14.5).
##
## ONE particle system: one draw call, simulated on the GPU, unshaded, casting
## no shadow and receiving no light. Adding forty separate glowing nodes would
## have cost forty draws and forty transforms a frame; this costs the same
## whether there are ten of them or a hundred, which is the whole reason it is
## built this way.
##
## The same swarm is the golden hour's dust and the night's fireflies: one node,
## one draw, a different colour and speed per hour (G14.6). At noon it stops
## emitting entirely, and a stopped GPUParticles3D draws nothing — so the switch
## costs nothing to flip either.

## Builds the swarm over `parent`, centred on the lawn.
var _process_material: ParticleProcessMaterial
var _material: StandardMaterial3D
var _quad: QuadMesh


static func build(parent: Node3D) -> Fireflies:
	if not GameConfig.FIREFLIES_ENABLED:
		return null
	var node := Fireflies.new()
	node.name = "Fireflies"
	parent.add_child(node)
	node._setup()
	node.refresh()
	return node


func _setup() -> void:
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	# A slab over the whole yard: wide, and only chest-to-head deep, because a
	# firefly at ankle height is lost in the grass and one at roof height is a
	# star.
	pm.emission_box_extents = Vector3(GameConfig.HALF_X + 3.0,
		GameConfig.FIREFLY_BAND.y * 0.5, GameConfig.HALF_Z + 3.0)
	pm.direction = Vector3(0.0, 1.0, 0.0)
	pm.spread = 180.0
	pm.initial_velocity_min = GameConfig.FIREFLY_DRIFT.x
	pm.initial_velocity_max = GameConfig.FIREFLY_DRIFT.y
	_process_material = pm
	pm.gravity = Vector3.ZERO
	# Turbulence is what makes them read as alive rather than as falling dust,
	# and it is free: the GPU already walks every particle.
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 0.9
	pm.turbulence_noise_scale = 1.6
	pm.turbulence_influence_min = 0.06
	pm.turbulence_influence_max = 0.18
	pm.scale_min = 0.5
	pm.scale_max = 1.0
	# The blink: alpha ramps up and back down over each life, and lifetime
	# randomness scatters the phase so they never pulse together.
	var ramp := Gradient.new()
	ramp.set_offset(0, 0.0)
	ramp.set_color(0, Color(1, 1, 1, 0))
	ramp.set_offset(1, 1.0)
	ramp.set_color(1, Color(1, 1, 1, 0))
	ramp.add_point(0.35, Color(1, 1, 1, 1))
	ramp.add_point(0.62, Color(1, 1, 1, 1))
	var ramp_tex := GradientTexture1D.new()
	ramp_tex.gradient = ramp
	pm.alpha_curve = ramp_tex
	process_material = pm

	var quad := QuadMesh.new()
	quad.size = Vector2(GameConfig.FIREFLY_SIZE, GameConfig.FIREFLY_SIZE)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	# Additive, so two of them overlapping read as brighter rather than as a
	# hard-edged sprite stack.
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.albedo_color = GameConfig.FIREFLY_COLOUR
	mat.disable_receive_shadows = true
	quad.material = mat
	draw_pass_1 = quad
	_quad = quad
	_material = mat

	amount = GameConfig.FIREFLY_COUNT
	lifetime = GameConfig.FIREFLY_LIFETIME
	preprocess = GameConfig.FIREFLY_LIFETIME
	randomness = 0.85
	local_coords = false
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	position.y = GameConfig.FIREFLY_BAND.x + GameConfig.FIREFLY_BAND.y * 0.5
	# Never welded into a baked mesh, and never worth drawing off screen.
	set_meta("no_bake", true)
	visibility_aabb = AABB(
		Vector3(-GameConfig.HALF_X - 6.0, -4.0, -GameConfig.HALF_Z - 6.0),
		Vector3(GameConfig.HALF_X * 2.0 + 12.0, 12.0, GameConfig.HALF_Z * 2.0 + 12.0))


## Turns the swarm on for the hours that have one. Called whenever the light
## changes, including from the switch on the bar.
func refresh() -> void:
	var hour := SkyTime.resolve(LevelVariant.current.time_of_day \
		if LevelVariant.current != null else GameConfig.TIME_OF_DAY_DEFAULT)
	var profile: Dictionary = GameConfig.MOTE_PROFILES.get(hour, {})
	var wanted := not profile.is_empty()
	visible = wanted
	emitting = wanted
	if not wanted:
		return
	# Retuning is cheaper than rebuilding, and it is what makes one node able to
	# be two different things: dust hangs almost still and pale, fireflies drift
	# and burn.
	_material.albedo_color = profile["colour"]
	_quad.size = Vector2(float(profile["size"]), float(profile["size"]))
	var drift: Vector2 = profile["drift"]
	_process_material.initial_velocity_min = drift.x
	_process_material.initial_velocity_max = drift.y
	amount = int(profile["count"])
