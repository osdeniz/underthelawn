extends Node3D
## G14.25: the three animals, close enough to see what they are made of, in
## both the pose they hold and the pose they run in.

func _ready() -> void:
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(20, 20)
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

	# Built through the real entry point with NO lawn: with a null model nothing
	# places itself, which is what this shot wants — the bodies, put where they
	# can be seen rather than where the game would put them.
	var animals := Animals.build(self, null, 7, false, false)
	await get_tree().process_frame
	animals.set_process(false)

	# Front row: what they look like standing still. Back row: the two poses
	# that only ever appear for a second in play.
	var spots := {
		"Rabbit0": Vector3(-1.02, 0.0, 0.25),
		"Bird0": Vector3(-0.08, 0.0, 0.20),
		"Dog": Vector3(1.00, 0.0, -0.05),
		"Rabbit1": Vector3(-0.75, 0.0, -1.05),
		"Bird1": Vector3(0.45, 0.42, -1.05),
	}
	for key: String in spots:
		var node := animals.get_node_or_null(key) as Node3D
		if node == null:
			continue
		node.position = spots[key]
		node.rotation.y = 2.45
		node.visible = true

	# The bolting rabbit: ears flat back, body off the ground and pitched.
	var bolter := animals.get_node("Rabbit1/Body") as Node3D
	animals._set_ears(bolter, 1.35)
	bolter.position.y = GameConfig.RABBIT_HOP_HEIGHT
	bolter.rotation.x = 0.22
	# The bird in the air: wings out and mid-beat.
	animals._flap(animals.get_node("Bird1/Body") as Node3D, 0.6)

	var cam := Camera3D.new()
	cam.position = Vector3(0.0, 1.00, 2.95)
	cam.rotation_degrees = Vector3(-17, 0, 0)
	cam.fov = 42
	cam.current = true
	add_child(cam)

	for _i in 30:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://out/animals.png")
	print("[cekim] out/animals.png yazildi")
	get_tree().quit()
