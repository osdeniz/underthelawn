extends TestBase
## G14.22: the same figure, head level and head turned.

func run() -> void:
	suite = "BAKIS CEKIM"
	min_checks = 1
	var stage := Node3D.new()
	add_child(stage)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(10, 10)
	ground.mesh = plane
	var grass := StandardMaterial3D.new()
	grass.albedo_color = Color(0.26, 0.46, 0.18)
	ground.material_override = grass
	stage.add_child(ground)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-46, 34, 0)
	sun.light_energy = 1.15
	sun.shadow_enabled = true
	stage.add_child(sun)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.46, 0.62, 0.76)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.64, 0.72, 0.82)
	e.ambient_light_energy = 0.75
	env.environment = e
	stage.add_child(env)

	# Left: nothing noticed. Right: something on the ground to its left.
	var specs: Array = [[-0.34, false], [0.34, true]]
	for spec: Array in specs:
		var who := Character.new()
		who.wear(2)
		stage.add_child(who)
		who.set_mode(Character.Mode.PUSH, null, stage)
		who.position = Vector3(float(spec[0]), GameConfig.CHAR_WALK_WAIST_Y, 0.0)
		who.walk_speed = 0.0
		who.rotation.y = PI
		if bool(spec[1]):
			who.look_has = true
			who.look_target = Vector3(float(spec[0]) - 1.6, 0.45, 1.4)
	var cam := Camera3D.new()
	cam.position = Vector3(0.0, 0.95, 4.6)
	cam.rotation_degrees = Vector3(-3, 0, 0)
	cam.fov = 30
	cam.current = true
	stage.add_child(cam)
	await frames(90)
	await drawn_frame()
	get_viewport().get_texture().get_image().save_png("res://out/look.png")
	print("[cekim] out/look.png yazildi")
	ck("iki figur kuruldu", stage.get_child_count() >= 5)
