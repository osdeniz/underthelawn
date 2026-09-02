extends Node3D
## G14.22: the same figure, head level and head turned.

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

	# Left: nothing noticed. Right: something on the ground to its left.
	var specs: Array = [[-0.34, false], [0.34, true]]
	for spec: Array in specs:
		var who := Character.new()
		who.wear(2)
		add_child(who)
		who.set_mode(Character.Mode.PUSH, null, self)
		who.position = Vector3(float(spec[0]), GameConfig.CHAR_WALK_WAIST_Y, 0.0)
		who.walk_speed = 0.0
		who.rotation.y = PI
		if bool(spec[1]):
			who.look_has = true
			who.look_target = Vector3(float(spec[0]) - 1.6, 0.45, 1.4)
	var cam := Camera3D.new()
	cam.position = Vector3(0.0, 1.10, 3.2)
	cam.rotation_degrees = Vector3(-5, 0, 0)
	cam.fov = 28
	cam.current = true
	add_child(cam)
	for _i in 90:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://out/look.png")
	get_tree().quit()
