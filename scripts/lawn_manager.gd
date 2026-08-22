class_name LawnManager
extends Node3D
## Procedural lawn: a grid of grass tiles rendered as one ground plane plus one
## MultiMesh of grass blades. Cut state lives in a small RGBA texture (the "cut
## mask") that both shaders sample, so mowing a tile costs one pixel write
## instead of any per-blade CPU work.
##
## Mask channels: R = cut animation progress 0..1, G = mow direction (0 or 1).
##
## Assumes this node sits at the world origin: grid coordinates are computed from
## world XZ directly.

signal completion_changed(percent: float, cut_tiles: int, total_tiles: int)
signal lawn_completed()

@export_group("Lawn")
@export var grid_width: int = 26
@export var grid_depth: int = 26
@export var tile_size: float = 1.2

@export_group("Grass")
@export var clumps_per_tile: int = 6
@export var blade_height_min: float = 0.42
@export var blade_height_max: float = 0.72
@export var blade_width: float = 0.075

@export_group("Feel")
## How fast a tile animates from standing to cut (1.0 / seconds).
@export var cut_anim_speed: float = 5.5
@export var random_seed: int = 20260822

var lawn_origin := Vector2.ZERO   ## World XZ of the lawn's min corner.
var lawn_extent := Vector2.ONE    ## World size of the lawn in metres.
var total_tiles: int = 0
var cut_tiles: int = 0

var _progress: PackedFloat32Array = PackedFloat32Array()
var _stripe: PackedFloat32Array = PackedFloat32Array()
var _is_cut: PackedByteArray = PackedByteArray()
var _animating: Array[int] = []

var _mask_image: Image
var _mask_texture: ImageTexture
var _ground_material: ShaderMaterial
var _blade_material: ShaderMaterial
var _blades: MultiMeshInstance3D

var _secrets: Array = []          ## [{ node, cells, ratio }]
var _completed := false


func _ready() -> void:
	total_tiles = grid_width * grid_depth
	lawn_extent = Vector2(grid_width * tile_size, grid_depth * tile_size)
	lawn_origin = -lawn_extent * 0.5

	_progress.resize(total_tiles)
	_stripe.resize(total_tiles)
	_is_cut.resize(total_tiles)

	_mask_image = Image.create(grid_width, grid_depth, false, Image.FORMAT_RGBA8)
	_mask_image.fill(Color(0.0, 0.0, 0.0, 1.0))
	_mask_texture = ImageTexture.create_from_image(_mask_image)

	_build_ground()
	_build_surround()
	_build_blades()
	_collect_secrets.call_deferred()
	_emit_progress.call_deferred()


func _process(delta: float) -> void:
	if _animating.is_empty():
		return
	var still: Array[int] = []
	for i in _animating:
		var p: float = minf(_progress[i] + delta * cut_anim_speed, 1.0)
		_progress[i] = p
		var cx: int = i % grid_width
		var cz: int = floori(float(i) / float(grid_width))
		_mask_image.set_pixel(cx, cz, Color(p, _stripe[i], 0.0, 1.0))
		if p < 1.0:
			still.append(i)
	_animating = still
	_mask_texture.update(_mask_image)


# ---------------------------------------------------------------- cutting API

## Cuts every uncut tile whose centre falls inside an oriented rectangle.
## Returns how many tiles changed state this call.
func cut_rect(center: Vector3, forward: Vector3, half_width: float, half_length: float) -> int:
	var fwd := Vector3(forward.x, 0.0, forward.z)
	if fwd.length_squared() < 0.0001:
		fwd = Vector3.FORWARD
	fwd = fwd.normalized()
	var right := Vector3(-fwd.z, 0.0, fwd.x)

	# Stripe direction: which world axis the pass is mostly aligned to, and its
	# sign. Alternating passes therefore alternate stripe shade, like a real lawn.
	var stripe := 1.0 if fwd.z < 0.0 else 0.0
	if absf(fwd.x) > absf(fwd.z):
		stripe = 1.0 if fwd.x > 0.0 else 0.0

	# A little padding so coverage feels generous rather than checkered; more
	# along the travel axis so fast passes never leave hairline gaps.
	var hw := half_width + tile_size * 0.15
	var hl := half_length + tile_size * 0.35
	var reach := maxf(hw, hl) + tile_size

	var min_cell := _clamp_cell(world_to_cell(center - Vector3(reach, 0.0, reach)))
	var max_cell := _clamp_cell(world_to_cell(center + Vector3(reach, 0.0, reach)))

	var newly := 0
	for cz in range(min_cell.y, max_cell.y + 1):
		for cx in range(min_cell.x, max_cell.x + 1):
			var i: int = cz * grid_width + cx
			if _is_cut[i] == 1:
				continue
			var d := cell_center(cx, cz) - center
			if absf(d.dot(right)) <= hw and absf(d.dot(fwd)) <= hl:
				_mark_cut(i, cx, cz, stripe)
				newly += 1

	if newly > 0:
		_emit_progress()
		_update_secrets()
	return newly


## Feeds the mower's position to the grass shader so blades part around it.
func set_mower_position(pos: Vector3) -> void:
	if _blade_material:
		_blade_material.set_shader_parameter("mower_pos", pos)


func world_to_cell(pos: Vector3) -> Vector2i:
	return Vector2i(
		int(floor((pos.x - lawn_origin.x) / tile_size)),
		int(floor((pos.z - lawn_origin.y) / tile_size))
	)


func cell_center(cx: int, cz: int) -> Vector3:
	return Vector3(
		lawn_origin.x + (float(cx) + 0.5) * tile_size,
		0.0,
		lawn_origin.y + (float(cz) + 0.5) * tile_size
	)


func is_cell_cut(cx: int, cz: int) -> bool:
	if cx < 0 or cz < 0 or cx >= grid_width or cz >= grid_depth:
		return false
	return _is_cut[cz * grid_width + cx] == 1


func completion_percent() -> float:
	if total_tiles == 0:
		return 0.0
	return 100.0 * float(cut_tiles) / float(total_tiles)


func _mark_cut(i: int, cx: int, cz: int, stripe: float) -> void:
	_is_cut[i] = 1
	_stripe[i] = stripe
	_progress[i] = 0.0
	_animating.append(i)
	cut_tiles += 1
	# Write the stripe channel immediately so blades know which way to fall.
	_mask_image.set_pixel(cx, cz, Color(0.0, stripe, 0.0, 1.0))


func _clamp_cell(c: Vector2i) -> Vector2i:
	return Vector2i(clampi(c.x, 0, grid_width - 1), clampi(c.y, 0, grid_depth - 1))


func _emit_progress() -> void:
	var pct := completion_percent()
	completion_changed.emit(pct, cut_tiles, total_tiles)
	if not _completed and cut_tiles >= total_tiles:
		_completed = true
		lawn_completed.emit()


# ---------------------------------------------------------------- secrets

func _collect_secrets() -> void:
	_secrets.clear()
	for node in get_tree().get_nodes_in_group("secret"):
		var n3 := node as Node3D
		if n3 == null:
			continue
		var secret := node as SecretObject
		var radius := 2.2
		if secret != null:
			radius = secret.reveal_radius
		var cells: Array[int] = []
		var center := n3.global_position
		var r_cells := int(ceil(radius / tile_size)) + 1
		var origin_cell := world_to_cell(center)
		for cz in range(origin_cell.y - r_cells, origin_cell.y + r_cells + 1):
			for cx in range(origin_cell.x - r_cells, origin_cell.x + r_cells + 1):
				if cx < 0 or cz < 0 or cx >= grid_width or cz >= grid_depth:
					continue
				if cell_center(cx, cz).distance_to(Vector3(center.x, 0.0, center.z)) <= radius:
					cells.append(cz * grid_width + cx)
		_secrets.append({ "node": n3, "cells": cells, "ratio": -1.0 })
	_update_secrets()


func _update_secrets() -> void:
	for s in _secrets:
		var cells: Array[int] = s["cells"]
		if cells.is_empty():
			continue
		var hits := 0
		for i in cells:
			if _is_cut[i] == 1:
				hits += 1
		var ratio := float(hits) / float(cells.size())
		if is_equal_approx(ratio, float(s["ratio"])):
			continue
		s["ratio"] = ratio
		var secret := s["node"] as SecretObject
		if secret != null:
			secret.set_exposure(ratio)


# ---------------------------------------------------------------- building

func _build_ground() -> void:
	_ground_material = ShaderMaterial.new()
	_ground_material.shader = load("res://shaders/lawn_ground.gdshader")
	_ground_material.set_shader_parameter("cut_mask", _mask_texture)
	_ground_material.set_shader_parameter("lawn_origin", lawn_origin)
	_ground_material.set_shader_parameter("lawn_size", lawn_extent)
	_ground_material.set_shader_parameter("stripe_width", tile_size * 2.0)

	var plane := PlaneMesh.new()
	plane.size = lawn_extent
	plane.subdivide_width = 1
	plane.subdivide_depth = 1

	var mi := MeshInstance3D.new()
	mi.name = "Ground"
	mi.mesh = plane
	mi.material_override = _ground_material
	add_child(mi)


## Dirt apron plus a low hedge wall that keeps the mower on the lawn.
func _build_surround() -> void:
	var soil := PlaneMesh.new()
	soil.size = lawn_extent + Vector2(14.0, 14.0)
	var soil_mat := StandardMaterial3D.new()
	soil_mat.albedo_color = Color(0.28, 0.21, 0.14)
	soil_mat.roughness = 1.0
	var soil_mi := MeshInstance3D.new()
	soil_mi.name = "Soil"
	soil_mi.mesh = soil
	soil_mi.material_override = soil_mat
	soil_mi.position = Vector3(0.0, -0.04, 0.0)
	add_child(soil_mi)

	var hedge_mat := StandardMaterial3D.new()
	hedge_mat.albedo_color = Color(0.09, 0.20, 0.09)
	hedge_mat.roughness = 1.0

	var half := lawn_extent * 0.5
	var thickness := 0.7
	var height := 0.9
	var span_x := Vector3(lawn_extent.x + thickness * 2.0, height, thickness)
	var span_z := Vector3(thickness, height, lawn_extent.y + thickness * 2.0)
	var y := height * 0.5
	var walls: Array[Array] = [
		[Vector3(0.0, y, -half.y - thickness * 0.5), span_x],
		[Vector3(0.0, y, half.y + thickness * 0.5), span_x],
		[Vector3(-half.x - thickness * 0.5, y, 0.0), span_z],
		[Vector3(half.x + thickness * 0.5, y, 0.0), span_z],
	]

	var body := StaticBody3D.new()
	body.name = "Hedges"
	add_child(body)
	for w in walls:
		var pos: Vector3 = w[0]
		var size: Vector3 = w[1]

		var box := BoxMesh.new()
		box.size = size
		var mi := MeshInstance3D.new()
		mi.mesh = box
		mi.material_override = hedge_mat
		mi.position = pos
		body.add_child(mi)

		var shape := BoxShape3D.new()
		shape.size = size
		var cs := CollisionShape3D.new()
		cs.shape = shape
		cs.position = pos
		body.add_child(cs)


func _build_blades() -> void:
	_blade_material = ShaderMaterial.new()
	_blade_material.shader = load("res://shaders/grass_blade.gdshader")
	_blade_material.set_shader_parameter("cut_mask", _mask_texture)
	_blade_material.set_shader_parameter("lawn_origin", lawn_origin)
	_blade_material.set_shader_parameter("lawn_size", lawn_extent)

	var rng := RandomNumberGenerator.new()
	rng.seed = random_seed

	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = _make_grass_clump()
	mm.instance_count = total_tiles * clumps_per_tile

	var idx := 0
	for cz in grid_depth:
		for cx in grid_width:
			for _c in clumps_per_tile:
				var px := lawn_origin.x + (float(cx) + rng.randf()) * tile_size
				var pz := lawn_origin.y + (float(cz) + rng.randf()) * tile_size
				var h := rng.randf_range(blade_height_min, blade_height_max)
				var w := rng.randf_range(0.8, 1.25)
				var clump_basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(w, h, w))
				mm.set_instance_transform(idx, Transform3D(clump_basis, Vector3(px, 0.0, pz)))
				mm.set_instance_custom_data(idx,
					Color(rng.randf(), rng.randf(), rng.randf(), 1.0))
				idx += 1

	_blades = MultiMeshInstance3D.new()
	_blades.name = "GrassBlades"
	_blades.multimesh = mm
	_blades.material_override = _blade_material
	_blades.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_blades)


## Three tapered, curved blades in one mesh: cheap density for a mobile GPU.
## Mesh is unit-height so per-instance scale controls the real height.
func _make_grass_clump() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var offsets: Array[Vector3] = [
		Vector3(0.0, 0.0, 0.0), Vector3(0.05, 0.0, 0.04), Vector3(-0.045, 0.0, -0.05)]
	var yaws: Array[float] = [0.0, 2.1, 4.3]
	var heights: Array[float] = [1.0, 0.78, 0.88]
	for i in 3:
		_add_blade(st, yaws[i], offsets[i], heights[i], blade_width, 0.22)
	return st.commit()


func _add_blade(st: SurfaceTool, yaw: float, offset: Vector3, height: float,
		width: float, curve: float) -> void:
	var dir := Vector3(cos(yaw), 0.0, sin(yaw))
	var side := Vector3(-sin(yaw), 0.0, cos(yaw))
	var segments := 3
	var prev_l := Vector3.ZERO
	var prev_r := Vector3.ZERO
	var prev_v := 0.0

	for s in range(segments + 1):
		var v := float(s) / float(segments)
		var w := width * (1.0 - 0.88 * v)
		var center := offset + dir * (curve * v * v) + Vector3(0.0, v * height, 0.0)
		var l := center - side * w * 0.5
		var r := center + side * w * 0.5
		if s > 0:
			var tangent := (center - (prev_l + prev_r) * 0.5).normalized()
			var normal := side.cross(tangent).normalized()
			_add_quad(st, prev_l, prev_r, r, l, prev_v, v, normal)
		prev_l = l
		prev_r = r
		prev_v = v


func _add_quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3,
		v0: float, v1: float, normal: Vector3) -> void:
	# a = bottom-left, b = bottom-right, c = top-right, d = top-left
	st.set_normal(normal)
	st.set_uv(Vector2(0.0, v0))
	st.add_vertex(a)
	st.set_normal(normal)
	st.set_uv(Vector2(1.0, v0))
	st.add_vertex(b)
	st.set_normal(normal)
	st.set_uv(Vector2(1.0, v1))
	st.add_vertex(c)

	st.set_normal(normal)
	st.set_uv(Vector2(0.0, v0))
	st.add_vertex(a)
	st.set_normal(normal)
	st.set_uv(Vector2(1.0, v1))
	st.add_vertex(c)
	st.set_normal(normal)
	st.set_uv(Vector2(0.0, v1))
	st.add_vertex(d)
