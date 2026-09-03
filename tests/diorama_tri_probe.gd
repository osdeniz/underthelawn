extends Node
## Where the town's triangles are. Sums mesh faces per top-level diorama child
## (MultiMesh instances counted), so the LOD work aims at the real cost.
func _ready() -> void:
	var dio: Node3D = load("res://scenes/TownDiorama.tscn").instantiate()
	add_child(dio)
	for _i in 30:
		await get_tree().process_frame
	var rows: Array = []
	var total := 0
	for child in dio.get_children():
		var tris := _tris(child)
		total += tris
		rows.append([tris, child.name, _count(child, "MeshInstance3D"), _count(child, "MultiMeshInstance3D")])
	rows.sort_custom(func(a, b): return a[0] > b[0])
	print("  [ucgen] toplam %d" % total)
	for r in rows.slice(0, 14):
		print("  [ucgen] %8d  %-28s mesh=%d multimesh=%d" % [r[0], r[1], r[2], r[3]])
	get_tree().quit()


func _tris(node: Node) -> int:
	var n := 0
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null and node.visible:
		n += _mesh_tris((node as MeshInstance3D).mesh)
	if node is MultiMeshInstance3D and (node as MultiMeshInstance3D).multimesh != null:
		var mm := (node as MultiMeshInstance3D).multimesh
		if mm.mesh != null:
			n += _mesh_tris(mm.mesh) * mm.instance_count
	for c in node.get_children():
		n += _tris(c)
	return n


func _mesh_tris(mesh: Mesh) -> int:
	var t := 0
	for s in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(s)
		if arrays.is_empty():
			continue
		var idx: Variant = arrays[Mesh.ARRAY_INDEX]
		var verts: Variant = arrays[Mesh.ARRAY_VERTEX]
		if idx != null and (idx as PackedInt32Array).size() > 0:
			t += (idx as PackedInt32Array).size() / 3
		elif verts != null:
			t += (verts as PackedVector3Array).size() / 3
	return t


func _count(node: Node, cls: String) -> int:
	return node.find_children("*", cls, true, false).size() + (1 if node.is_class(cls) else 0)
