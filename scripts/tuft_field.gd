class_name TuftField
extends Node3D
## Long grass tufts — REFERENCE.md §5.
##
## 8 shared cluster geometries (deterministic RNG), each cluster = 7 tufts x 2
## crossed quads with the top edge tapered to 75%. The 368 mowable cells are
## spread across 8 MultiMeshInstance3D nodes; variety comes per instance from
## random Y rotation, 0.9-1.1 scale and in-cell jitter.
##
## Cutting (§4): the tuft turns to the mower's heading, then topples forward
## ~77 deg and shrinks to 0.25 over 0.1 s before disappearing.

const HIDDEN := Vector3.ZERO

var _model: LawnModel
var _meshes: Array[MultiMesh] = []
var _instances: Array[MultiMeshInstance3D] = []

var _cell_variant: PackedByteArray = PackedByteArray()
var _cell_slot: PackedInt32Array = PackedInt32Array()
var _cell_yaw: PackedFloat32Array = PackedFloat32Array()
var _cell_scale: PackedFloat32Array = PackedFloat32Array()
var _cell_origin: PackedVector3Array = PackedVector3Array()
## Slight per-cluster tint so the lawn is not one flat green.
var _cell_color: PackedColorArray = PackedColorArray()

## [{ cell, yaw, t }] — only cells cut in the last 0.1 s.
var _animating: Array = []
var _material: ShaderMaterial


func setup(model: LawnModel, seed_value: int = 20260822) -> void:
	_model = model
	_build_material()
	_build_variants(seed_value)
	_assign_cells(seed_value)
	refresh_all()


func _build_material() -> void:
	_material = ShaderMaterial.new()
	_material.shader = load("res://shaders/grass_tuft.gdshader")
	_material.set_shader_parameter("tuft_texture", TextureLibrary.tuft_silhouette())
	_material.set_shader_parameter("wind_amplitude", GameConfig.WIND_AMPLITUDE)
	_material.set_shader_parameter("wind_speed", GameConfig.WIND_SPEED)


func _build_variants(seed_value: int) -> void:
	for v in GameConfig.TUFT_VARIANTS:
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value + v * 7919
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = _make_cluster(rng)
		mm.instance_count = 0
		_meshes.append(mm)

		var mmi := MultiMeshInstance3D.new()
		mmi.name = "TuftVariant%d" % v
		mmi.multimesh = mm
		mmi.material_override = _material
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mmi)
		_instances.append(mmi)


## 7 tufts x 2 crossed quads, one geometry.
func _make_cluster(rng: RandomNumberGenerator) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for t in GameConfig.TUFTS_PER_CLUSTER:
		var offset := Vector3(
			rng.randf_range(-GameConfig.TUFT_CLUSTER_SPREAD, GameConfig.TUFT_CLUSTER_SPREAD),
			0.0,
			rng.randf_range(-GameConfig.TUFT_CLUSTER_SPREAD, GameConfig.TUFT_CLUSTER_SPREAD))
		var height := rng.randf_range(GameConfig.TUFT_HEIGHT_MIN, GameConfig.TUFT_HEIGHT_MAX)
		var width := rng.randf_range(GameConfig.TUFT_WIDTH_MIN, GameConfig.TUFT_WIDTH_MAX)
		var yaw := rng.randf() * TAU
		_add_quad(st, offset, yaw, width, height)
		_add_quad(st, offset, yaw + PI * 0.5, width, height)
	return st.commit()


func _add_quad(st: SurfaceTool, offset: Vector3, yaw: float, width: float, height: float) -> void:
	var side := Vector3(cos(yaw), 0.0, sin(yaw))
	var half_bottom := side * width * 0.5
	var half_top := side * width * GameConfig.TUFT_TOP_TAPER * 0.5
	var up := Vector3(0.0, height, 0.0)

	var bl := offset - half_bottom
	var br := offset + half_bottom
	var tl := offset + up - half_top
	var tr := offset + up + half_top

	# Root is the bottom of the silhouette image, so v = 1 at the root.
	_vertex(st, bl, Vector2(0.0, 1.0))
	_vertex(st, br, Vector2(1.0, 1.0))
	_vertex(st, tr, Vector2(1.0, 0.0))
	_vertex(st, bl, Vector2(0.0, 1.0))
	_vertex(st, tr, Vector2(1.0, 0.0))
	_vertex(st, tl, Vector2(0.0, 0.0))


func _vertex(st: SurfaceTool, pos: Vector3, uv: Vector2) -> void:
	st.set_normal(Vector3.UP)
	st.set_uv(uv)
	st.add_vertex(pos)


func _assign_cells(seed_value: int) -> void:
	var count := GameConfig.CELL_COUNT
	_cell_variant.resize(count)
	_cell_slot.resize(count)
	_cell_yaw.resize(count)
	_cell_scale.resize(count)
	_cell_origin.resize(count)
	_cell_color.resize(count)

	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var counts := PackedInt32Array()
	counts.resize(GameConfig.TUFT_VARIANTS)

	for row in GameConfig.GRID_ROWS:
		for col in GameConfig.GRID_COLS:
			var i := LawnModel.index_of(col, row)
			if not _model.is_mowable(col, row):
				_cell_slot[i] = -1
				continue
			var v := rng.randi_range(0, GameConfig.TUFT_VARIANTS - 1)
			_cell_variant[i] = v
			_cell_slot[i] = counts[v]
			counts[v] += 1
			_cell_yaw[i] = rng.randf() * TAU
			_cell_scale[i] = rng.randf_range(
				GameConfig.TUFT_CELL_SCALE_MIN, GameConfig.TUFT_CELL_SCALE_MAX)
			# In-cell jitter; cluster spread is +/-0.34 so +/-0.15 keeps it inside.
			_cell_origin[i] = LawnModel.cell_center(col, row) + Vector3(
				rng.randf_range(-0.15, 0.15), 0.0, rng.randf_range(-0.15, 0.15))
			# Brightness plus a nudge towards dry yellow or deep green.
			var bright := rng.randf_range(0.82, 1.14)
			var dryness := rng.randf_range(-0.06, 0.09)
			_cell_color[i] = Color(
				clampf(bright + dryness, 0.6, 1.3),
				clampf(bright + dryness * 0.45, 0.6, 1.3),
				clampf(bright - dryness * 1.5, 0.55, 1.3), 1.0)

	for v in GameConfig.TUFT_VARIANTS:
		_meshes[v].instance_count = counts[v]


# ---------------------------------------------------------------- runtime

## Rebuilds every instance transform from the model (used on start and restart).
func refresh_all() -> void:
	_animating.clear()
	for row in GameConfig.GRID_ROWS:
		for col in GameConfig.GRID_COLS:
			var i := LawnModel.index_of(col, row)
			if _cell_slot[i] < 0:
				continue
			_meshes[int(_cell_variant[i])].set_instance_color(_cell_slot[i], _cell_color[i])
			if _model.is_cut(col, row):
				_write(i, HIDDEN, 0.0, 0.0)
			else:
				_write(i, _cell_origin[i], _cell_yaw[i], 0.0)


## Starts the topple animation for one cell. `yaw` is the mower's Godot yaw.
func cut_cell(col: int, row: int, yaw: float) -> void:
	var i := LawnModel.index_of(col, row)
	if i < 0 or i >= _cell_slot.size() or _cell_slot[i] < 0:
		return
	_animating.append({ "cell": i, "yaw": yaw, "t": 0.0 })


func _process(delta: float) -> void:
	if _animating.is_empty():
		return
	var still := []
	for entry in _animating:
		var t: float = entry["t"] + delta / GameConfig.MOW_ANIM_TIME
		var i: int = entry["cell"]
		if t >= 1.0:
			_write(i, HIDDEN, 0.0, 0.0)
			continue
		entry["t"] = t
		_write(i, _cell_origin[i], entry["yaw"], t)
		still.append(entry)
	_animating = still


## progress 0 = standing, 1 = fully toppled. origin == HIDDEN hides the tuft.
func _write(cell: int, origin: Vector3, yaw: float, progress: float) -> void:
	var v := int(_cell_variant[cell])
	var slot := _cell_slot[cell]
	if origin == HIDDEN:
		_meshes[v].set_instance_transform(slot,
			Transform3D(Basis().scaled(Vector3.ZERO), _cell_origin[cell]))
		return
	var s := _cell_scale[cell] * lerpf(1.0, GameConfig.MOW_ANIM_END_SCALE, progress)
	var inst_basis := Basis(Vector3.UP, yaw) \
		* Basis(Vector3.RIGHT, GameConfig.MOW_ANIM_PITCH * progress)
	_meshes[v].set_instance_transform(slot,
		Transform3D(inst_basis.scaled(Vector3(s, s, s)), origin))
