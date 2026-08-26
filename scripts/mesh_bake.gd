class_name MeshBake
extends RefCounted
## Welds a subtree's static MeshInstance3Ds into one mesh per material (G13.6).
##
## The diorama is built from primitives, which is what makes a building a
## dictionary entry plus a builder function — but it also meant 752 draw calls
## for the finished town: 240 for the edge trees alone, 132 for the bushes.
## Baking keeps the authoring style and pays the runtime cost once.
##
## What must NOT be baked:
##   * anything that moves on its own (figures, birds, washing, the swing)
##   * a restored building DURING its rebuild — the transition tweens each part
##     separately, so baking happens when the animation ends
##   * the reclaimed weed band, which retreats a step per chapter (G13.4)
##
## Baking is one-way. A subtree that may need its parts back later must be
## baked only once it is finished with them.


## Welds everything under `root` (root itself excluded) into one MeshInstance3D
## per material. Returns how many draws were saved, for the perf log.
static func bake(root: Node3D) -> int:
	if root == null or not is_instance_valid(root):
		return 0
	var sources: Array = []
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi.mesh == null or mi.get_meta("no_bake", false):
			continue
		sources.append(mi)
	if sources.size() < 2:
		return 0

	# Grouped by material: one surface per material is one draw call, so the
	# floor on this is however many distinct materials the subtree uses.
	var by_material: Dictionary = {}
	for source_any: Variant in sources:
		var mi := source_any as MeshInstance3D
		var mat := mi.material_override
		var key := mat.get_instance_id() if mat != null else 0
		if not by_material.has(key):
			by_material[key] = {"material": mat, "items": []}
		(by_material[key]["items"] as Array).append(mi)

	var before := sources.size()
	var made := 0
	for key: Variant in by_material:
		var group: Dictionary = by_material[key]
		var welded := _weld(group["items"], root)
		if welded == null:
			continue
		var node := MeshInstance3D.new()
		node.name = "Baked%d" % made
		node.mesh = welded
		node.material_override = group["material"]
		# Shadows come from the welded mesh now, so the originals must go before
		# this is added or the town casts every shadow twice.
		root.add_child(node)
		made += 1
	if made == 0:
		return 0
	for source_any2: Variant in sources:
		var mi := source_any2 as MeshInstance3D
		mi.get_parent().remove_child(mi)
		mi.queue_free()
	return before - made


## One ArrayMesh from many, each transformed into `root`'s space.
static func _weld(items: Array, root: Node3D) -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var wrote := false
	var inverse := root.global_transform.affine_inverse()
	for item_any: Variant in items:
		var mi := item_any as MeshInstance3D
		var local := inverse * mi.global_transform
		# surface_get_primitive_type only exists on ArrayMesh; a CylinderMesh or
		# BoxMesh is triangles by definition.
		var array_mesh := mi.mesh as ArrayMesh
		for surface in mi.mesh.get_surface_count():
			if array_mesh != null and \
					array_mesh.surface_get_primitive_type(surface) \
					!= Mesh.PRIMITIVE_TRIANGLES:
				continue
			tool.append_from(mi.mesh, surface, local)
			wrote = true
	if not wrote:
		return null
	# Normals are already in the source meshes; recomputing them would round off
	# the box corners every building is made of.
	return tool.commit()
