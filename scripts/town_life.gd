class_name TownLife
extends Node3D
## Signs that people are back: chimney smoke and lit windows (G14.6).
##
## Both are driven ONLY by what has been rebuilt, so the diorama tells the
## player how far the restoration has come without a counter. A ruin never
## smokes and never lights a window — that is the whole point of them.
##
## Cost: one GPUParticles3D per smoking chimney (four at most), and ONE merged
## mesh for every lit window in the town. Windows are rebuilt when a building
## lands or the hour changes, which is rare; smoke is switched, not rebuilt.

var _smoke: Dictionary = {}
var _windows: MeshInstance3D
var _lit := false


func _ready() -> void:
	name = "TownLife"
	set_meta("no_bake", true)


## Builds a chimney plume for every buildable that has one. They start stopped;
## `refresh` decides which ones are actually alight.
func setup() -> void:
	for id: String in GameConfig.DIORAMA_SMOKE:
		if not GameConfig.DIORAMA_BUILDINGS.has(id):
			continue
		var spec: Dictionary = GameConfig.DIORAMA_BUILDINGS[id]
		var at: Vector3 = (spec["pos"] as Vector3) \
			+ (GameConfig.DIORAMA_SMOKE[id] as Vector3)
		var puff := _make_smoke()
		puff.position = at
		add_child(puff)
		_smoke[id] = puff
	_windows = MeshInstance3D.new()
	_windows.name = "Windows"
	_windows.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_windows.set_meta("no_bake", true)
	add_child(_windows)


## Called when a building lands and when the light changes.
func refresh() -> void:
	for id: String in _smoke:
		var puff := _smoke[id] as GPUParticles3D
		var alight := RestoreBoard.is_built(id)
		if puff.emitting != alight:
			puff.emitting = alight
			puff.visible = alight
	var hour := SkyTime.resolve(TownDiorama.DIORAMA_HOUR)
	var lit: bool = GameConfig.WINDOW_HOURS.has(hour)
	_build_windows(lit)


## One mesh for every lit window in the town. Rebuilt rather than toggled per
## window, because the set changes only when a building is finished — and a
## hundred separate quads would have been a hundred draws.
func _build_windows(lit: bool) -> void:
	if _windows == null or not is_instance_valid(_windows):
		return
	_windows.visible = lit
	if not lit:
		return
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var wrote := false
	for id: String in GameConfig.DIORAMA_WINDOWS:
		if not RestoreBoard.is_built(id):
			continue
		if not GameConfig.DIORAMA_BUILDINGS.has(id):
			continue
		var spec: Dictionary = GameConfig.DIORAMA_BUILDINGS[id]
		var base: Vector3 = spec["pos"]
		var yaw := float(spec.get("yaw", 0.0))
		for any: Variant in GameConfig.DIORAMA_WINDOWS[id]:
			var offset: Vector3 = any
			# The building is turned on its plot, so its windows turn with it.
			var turned := offset.rotated(Vector3.UP, yaw)
			_add_window(tool, base + turned, yaw)
			wrote = true
	if not wrote:
		_windows.visible = false
		return
	var mesh := tool.commit()
	_windows.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = GameConfig.WINDOW_COLOUR
	# Unshaded, so a window is bright at the exact hour everything else is dim.
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.disable_receive_shadows = true
	_windows.material_override = mat


func _add_window(tool: SurfaceTool, at: Vector3, yaw: float) -> void:
	var half := Vector3(GameConfig.WINDOW_SIZE.x * 0.5,
		GameConfig.WINDOW_SIZE.y * 0.5, 0.0)
	var right := Vector3(half.x, 0.0, 0.0).rotated(Vector3.UP, yaw)
	var up := Vector3(0.0, half.y, 0.0)
	var corners := [at - right - up, at + right - up, at + right + up,
		at - right + up]
	for triangle: Array in [[0, 1, 2], [0, 2, 3]]:
		for index: int in triangle:
			tool.set_normal(Vector3(0.0, 0.0, 1.0).rotated(Vector3.UP, yaw))
			tool.set_uv(Vector2.ZERO)
			tool.add_vertex(corners[index])


func _make_smoke() -> GPUParticles3D:
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.12
	pm.direction = Vector3(0.0, 1.0, 0.0)
	pm.spread = 12.0
	pm.initial_velocity_min = GameConfig.SMOKE_RISE.x
	pm.initial_velocity_max = GameConfig.SMOKE_RISE.y
	pm.gravity = Vector3(0.12, 0.05, 0.0)   # a little drift, no fall
	pm.scale_min = 0.6
	pm.scale_max = 1.4
	# Grows and fades as it climbs: smoke, not a string of beads.
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 0.35))
	curve.add_point(Vector2(1.0, 1.0))
	var scale_curve := CurveTexture.new()
	scale_curve.curve = curve
	pm.scale_curve = scale_curve
	var ramp := Gradient.new()
	ramp.set_offset(0, 0.0)
	ramp.set_color(0, Color(1, 1, 1, 0))
	ramp.set_offset(1, 1.0)
	ramp.set_color(1, Color(1, 1, 1, 0))
	ramp.add_point(0.22, Color(1, 1, 1, 1))
	var ramp_tex := GradientTexture1D.new()
	ramp_tex.gradient = ramp
	pm.alpha_curve = ramp_tex

	var quad := QuadMesh.new()
	quad.size = Vector2(GameConfig.SMOKE_SIZE, GameConfig.SMOKE_SIZE)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.albedo_color = GameConfig.SMOKE_COLOUR
	mat.disable_receive_shadows = true
	quad.material = mat

	var puff := GPUParticles3D.new()
	puff.process_material = pm
	puff.draw_pass_1 = quad
	puff.amount = GameConfig.SMOKE_COUNT
	puff.lifetime = GameConfig.SMOKE_LIFETIME
	puff.preprocess = GameConfig.SMOKE_LIFETIME
	puff.randomness = 0.7
	puff.local_coords = false
	puff.emitting = false
	puff.visible = false
	puff.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	puff.set_meta("no_bake", true)
	return puff
