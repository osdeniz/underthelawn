extends Node3D
## G68: the haul on the back, seen from behind — which is the view the player
## actually has of the driver. Left figure carries a FULL load, right figure
## carries three bundles, so the shot shows both the ceiling and the way there.

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

	# Left: side on, which is the view that shows the height against the
	# shoulders. Right: from behind with the same full load, which is the view
	# the player actually has while mowing.
	for spec: Array in [[-0.55, 40, 3, PI * 0.5], [0.55, 40, 3, 0.0]]:
		var who := Character.new()
		add_child(who)
		who.set_mode(Character.Mode.PUSH, null, self)
		who.position = Vector3(float(spec[0]), GameConfig.CHAR_WALK_WAIST_Y, 0.0)
		who.walk_speed = 0.0
		# Turned away, the way G14.21's shot does it: the player's view of the
		# driver is the back of the head, which is where the load rides.
		who.rotation.y = float(spec[3])
		var stack := CarryStack.new()
		who.add_child(stack)
		stack.position = GameConfig.CARRY_BACK_OFFSET
		for _i in int(spec[1]):
			stack.add_salvage()
		for i in int(spec[2]):
			stack.add_evidence(["radio", "ribbon", "boot"][i])

	var cam := Camera3D.new()
	cam.position = Vector3(0.0, 1.05, 3.0)
	cam.rotation_degrees = Vector3(-4, 0, 0)
	cam.fov = 40
	cam.current = true
	add_child(cam)

	for _i in 40:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	# The numbers behind the picture: where the load actually ends against the
	# nape, in world height.
	for any: Variant in find_children("*", "CarryStack", true, false):
		var stack := any as CarryStack
		var top := 0.0
		for kid: Variant in stack.get_children():
			top = maxf(top, (kid as Node3D).global_position.y)
		print("[olcum] yuk tepesi %.3f | ense %.3f | kafa tepesi ~%.3f" % [top,
			GameConfig.CHAR_WALK_WAIST_Y + GameConfig.CHAR_SHOULDER.y,
			GameConfig.CHAR_WALK_WAIST_Y + 0.79])
	get_viewport().get_texture().get_image().save_png("res://out/carry.png")
	print("[cekim] out/carry.png yazildi")
	get_tree().quit()
