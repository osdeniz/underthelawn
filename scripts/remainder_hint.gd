class_name RemainderHint
extends MultiMeshInstance3D
## The last-5% finder (G9.2). Past HINT_RATIO, every remaining uncut cell gets a
## soft pulsing marker above the grass, so the end of a search is a walk to the
## glow rather than a hunt by eye. One MultiMesh of unshaded billboards: at most
## HINT_MAX_CELLS quads, refreshed twice a second, pulsed in _process.

const REFRESH_INTERVAL := 0.5

var _model: LawnModel
var _timer := 0.0
var _time := 0.0
var _cells: Array[Vector2i] = []


func setup(model: LawnModel) -> void:
	_model = model
	var quad := QuadMesh.new()
	quad.size = Vector2(0.6, 0.6)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.albedo_color = GameConfig.HINT_COLOR
	quad.material = mat
	multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = quad
	multimesh.instance_count = 0
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _process(delta: float) -> void:
	if _model == null or multimesh == null:
		return
	_time += delta
	_timer -= delta
	if _timer <= 0.0:
		_timer = REFRESH_INTERVAL
		_rescan()
	# One shared pulse: scale breathes, which reads as "over here" without any
	# per-instance bookkeeping.
	var pulse := 0.75 + 0.35 * sin(_time * TAU * GameConfig.HINT_PULSE_HZ)
	for i in _cells.size():
		var at := LawnModel.cell_center(_cells[i].x, _cells[i].y)
		var xform := Transform3D(Basis().scaled(Vector3.ONE * pulse),
			at + Vector3(0.0, 0.85, 0.0))
		multimesh.set_instance_transform(i, xform)


func _rescan() -> void:
	_cells.clear()
	if _model.completion_ratio() < GameConfig.HINT_RATIO:
		multimesh.instance_count = 0
		return
	for row in GameConfig.GRID_ROWS:
		for col in GameConfig.GRID_COLS:
			if _model.is_mowable(col, row) and not _model.is_cut(col, row):
				_cells.append(Vector2i(col, row))
				if _cells.size() >= GameConfig.HINT_MAX_CELLS:
					multimesh.instance_count = 0
					return
	multimesh.instance_count = _cells.size()
