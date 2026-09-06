extends TestBase
## Where a YARD's triangles are (G20.6), for the device checklist: the hub had
## a probe since G16.3, the yards never did. Five representative chapters,
## triangles per top-level node of the game scene, MultiMesh instances counted.

const YARDS := ["ch01_aldridge", "ch03_playground", "ch06_watertower",
	"ch19_town_square", "harvest_field"]

func run() -> void:
	suite = "BAHCE UCGEN"
	min_checks = 1
	for id: String in YARDS:
		var game: Node = await open(id)
		var rows: Array = []
		var total := 0
		for child in game.get_children():
			var t := _tris(child)
			if t > 0:
				total += t
				rows.append([t, child.name])
		rows.sort_custom(func(a, b): return a[0] > b[0])
		var top := PackedStringArray()
		for r in rows.slice(0, 4):
			top.append("%s=%d" % [r[1], r[0]])
		print("  [ucgen] %-20s toplam %7d  (%s)" % [id, total, ", ".join(top)])
		ck("%s ucgen sayildi" % id, total > 0)
		await close(game)


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
