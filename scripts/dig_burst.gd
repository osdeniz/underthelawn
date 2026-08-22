class_name DigBurst
extends GPUParticles3D
## Soil-coloured one-shot burst when a secret is dug out (§9):
## birthRate 160 over 0.15 s, lifetime 0.5, with gravity. Frees itself.


static func spawn(parent: Node, world_pos: Vector3) -> DigBurst:
	var burst := DigBurst.new()
	burst.name = "DigBurst"
	burst._configure()
	parent.add_child(burst)
	burst.global_position = world_pos
	burst.restart()
	burst.emitting = true
	burst.finished.connect(burst.queue_free)
	return burst


func _configure() -> void:
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.18
	pm.direction = Vector3(0.0, 1.0, 0.0)
	pm.spread = 60.0
	pm.initial_velocity_min = 1.4
	pm.initial_velocity_max = 3.4
	pm.gravity = Vector3(0.0, GameConfig.CLIP_GRAVITY, 0.0)
	pm.scale_min = 0.5
	pm.scale_max = 1.5
	pm.angular_velocity_min = -420.0
	pm.angular_velocity_max = 420.0
	pm.color = GameConfig.DIG_COLOR

	var quad := QuadMesh.new()
	quad.size = Vector2(0.05, 0.05)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	mat.albedo_color = GameConfig.DIG_COLOR
	quad.material = mat

	process_material = pm
	draw_pass_1 = quad
	lifetime = GameConfig.DIG_LIFETIME
	amount = maxi(int(GameConfig.DIG_BIRTH_RATE * GameConfig.DIG_EMIT_TIME), 1)
	# Emit over DIG_EMIT_TIME out of the full lifetime.
	explosiveness = clampf(1.0 - GameConfig.DIG_EMIT_TIME / GameConfig.DIG_LIFETIME, 0.0, 1.0)
	one_shot = true
	local_coords = false
	emitting = false
