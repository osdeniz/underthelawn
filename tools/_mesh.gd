extends SceneTree
func _initialize() -> void:
	var b := BladeMower.new()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tip: Vector3 = b._add_sickle(st, 0.0)
	var mesh := st.commit()
	var arrays := mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var norms = arrays[Mesh.ARRAY_NORMAL]
	print("tip=%s vertex=%d normal_dizisi=%s" % [tip, verts.size(),
		"YOK" if norms == null else str((norms as PackedVector3Array).size())])
	if norms != null:
		var n: PackedVector3Array = norms
		var zero := 0
		var nan := 0
		var down := 0
		for v in n:
			if v.length() < 0.001: zero += 1
			if is_nan(v.x) or is_nan(v.y) or is_nan(v.z): nan += 1
			if v.y < -0.1: down += 1
		print("sifir=%d nan=%d asagi_bakan=%d" % [zero, nan, down])
		print("ilk 6 normal: %s" % [n.slice(0, 6)])
	b.free()
	quit()
