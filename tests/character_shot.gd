extends Node3D
## G14.17: the figure, on its own, big enough to see what it is made of.

func _ready() -> void:
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(10, 10)
	ground.mesh = plane
	var grass := StandardMaterial3D.new()
	grass.albedo_color = Color(0.26, 0.46, 0.18)
	ground.material_override = grass
	add_child(ground)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-46, 34, 0)
	sun.light_energy = 1.15
	sun.shadow_enabled = true
	add_child(sun)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.46, 0.62, 0.76)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.64, 0.72, 0.82)
	e.ambient_light_energy = 0.75
	env.environment = e
	add_child(env)

	# Two of them: standing, and mid-stride.
	for spec: Array in [[-0.42, 0.0], [0.42, 1.6]]:
		var who := Character.new()
		add_child(who)
		who.set_mode(Character.Mode.PUSH, null, self)
		who.position = Vector3(float(spec[0]), GameConfig.CHAR_WALK_WAIST_Y, 0.0)
		who.walk_speed = 0.9
		who._phase = float(spec[1])
		who.rotation.y = 0.35

	var cam := Camera3D.new()
	cam.position = Vector3(0.0, 0.95, 5.2)
	cam.rotation_degrees = Vector3(-4, 0, 0)
	cam.fov = 26
	cam.current = true
	add_child(cam)

	for _i in 30:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://out/character.png")
	get_tree().quit()
