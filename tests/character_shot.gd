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

	# The Marshal, then four townsfolk in their own clothes. Turned to face the
	# camera, because the whole point of this shot is the front of the head.
	# One facing us for the face, one turned away for the hair — which is the
	# view the player actually has of the driver (G14.21).
	var specs: Array = [[-0.32, -1], [0.32, 2]]
	for spec: Array in specs:
		var who := Character.new()
		if int(spec[1]) >= 0:
			who.wear(int(spec[1]))
		add_child(who)
		who.set_mode(Character.Mode.PUSH, null, self)
		who.position = Vector3(float(spec[0]), GameConfig.CHAR_WALK_WAIST_Y, 0.0)
		who.walk_speed = 0.0
		# Two of the five turned away, because the driver is seen from BEHIND in
		# play and the hair lives on the back of the head (G14.21).
		who.rotation.y = PI if float(spec[0]) < 0.0 else 0.0

	var cam := Camera3D.new()
	cam.position = Vector3(0.0, 0.95, 4.0)
	cam.rotation_degrees = Vector3(-6, 0, 0)
	cam.fov = 32
	cam.current = true
	add_child(cam)

	for _i in 30:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://out/character.png")
	get_tree().quit()
