extends Node
func _ready() -> void:
	GameState.set_setting("meta", "orientation_done", true)
	Settlers.reset()
	Settlers.accept(str((Settlers.all()[0] as Dictionary)["id"]))
	print("  [sonda] kabul edilen: ", Settlers.accepted().size())
	var game: Node = load("res://scenes/Main.tscn").instantiate()
	game.variant_id = "harvest_field"
	add_child(game)
	for _i in 12:
		get_tree().paused = false
		await get_tree().process_frame
	var f: Node3D = game.find_child("HarvestSettler", true, false)
	print("  [sonda] figur: ", f, " konum: ", f.global_position if f else "yok",
		" fence_n=", GameConfig.fence_north_z(), " house=", GameConfig.house_pos_z(), " HALF_Z=", GameConfig.HALF_Z)
	var barn: Node = game.find_child("Landmark_barn", true, false)
	if barn:
		var aabb := AABB()
		var first := true
		for mi in barn.find_children("*", "MeshInstance3D", true, false):
			var b: AABB = (mi as MeshInstance3D).global_transform * (mi as MeshInstance3D).get_aabb()
			aabb = b if first else aabb.merge(b)
			first = false
		print("  [sonda] ahir kutusu: ", aabb)
	Settlers.reset()
	get_tree().quit()
