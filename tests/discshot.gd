extends Node3D
## G12.10: a look at the tractor's front discs. The previous placement bug (both
## discs buried inside the deck box) was invisible to every unit test and only
## showed up in a render, so this scene exists to be looked at.

func _ready() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.20, 0.24, 0.18)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.75, 0.80, 0.85)
	e.ambient_light_energy = 1.0
	env.environment = e
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 35, 0)
	add_child(sun)
	var t: Node3D = load("res://scenes/Tractor.tscn").instantiate()
	add_child(t)
	await get_tree().process_frame
	# Mowers start inactive, which means hidden.
	t.visible = true
	if t is PhysicsBody3D:
		(t as Node).set_physics_process(false)
	var cam := Camera3D.new()
	add_child(cam)
	var focus := Vector3(0.0, 0.30, GameConfig.TRACTOR_DISC_OFFSET.z)
	cam.position = focus + Vector3(1.7, 1.0, -2.4)
	cam.look_at(focus)
	cam.current = true
	print("CAM %v -> %v" % [cam.position, focus])


func _bounds(node: Node) -> AABB:
	var out := AABB()
	var first := true
	for child in node.find_children("*", "VisualInstance3D", true, false):
		var vi := child as VisualInstance3D
		var box := vi.global_transform * vi.get_aabb()
		if first:
			out = box
			first = false
		else:
			out = out.merge(box)
	return out
