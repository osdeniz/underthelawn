class_name LawnView
extends Node3D
## Renders the lawn: ONE 16x24 ground plane whose albedo is multiplied by a
## 16x24 tint texture (one pixel per cell), plus the tuft field (§5).
##
## Sprint G1 has no obstacle art, so obstacles get neutral grey placeholders and
## the pool gets the placeholder plane the brief asks for.

var model: LawnModel
var tuft_field: TuftField

var _tint_image: Image
var _tint_texture: ImageTexture
var _ground_material: ShaderMaterial
var _tint_dirty := false
## Freshly cut cells flash bright for FRESH_FLASH_TIME before settling into
## their stripe tone (G6.5). Entries: { col, row, t }.
var _flashes: Array = []


func setup(lawn_model: LawnModel) -> void:
	model = lawn_model
	_build_tint()
	_build_ground()
	_build_obstacle_placeholders()

	tuft_field = TuftField.new()
	tuft_field.name = "TuftField"
	add_child(tuft_field)
	tuft_field.setup(model)

	model.cell_tint_changed.connect(_on_cell_tint_changed)
	repaint_all()


func _build_tint() -> void:
	_tint_image = Image.create(GameConfig.GRID_COLS, GameConfig.GRID_ROWS,
		false, Image.FORMAT_RGBA8)
	_tint_image.fill(GameConfig.ground_tall_tint())
	_tint_texture = ImageTexture.create_from_image(_tint_image)


func _build_ground() -> void:
	_ground_material = ShaderMaterial.new()
	_ground_material.shader = load("res://shaders/lawn_ground.gdshader")
	_ground_material.set_shader_parameter("cell_tint", _tint_texture)
	_ground_material.set_shader_parameter("uv_repeat",
		Vector2(GameConfig.GROUND_UV_REPEAT_X, GameConfig.GROUND_UV_REPEAT_Z))
	_ground_material.set_shader_parameter("normal_strength", GameConfig.GROUND_NORMAL_STRENGTH)
	_ground_material.set_shader_parameter("surface_roughness", GameConfig.GROUND_ROUGHNESS)

	var albedo := TextureLibrary.find("grass_albedo")
	if albedo != null:
		_ground_material.set_shader_parameter("grass_albedo", albedo)
		_ground_material.set_shader_parameter("has_albedo", true)
	else:
		TextureLibrary.warn_missing("grass_albedo", "duz renk zemin kullaniliyor")

	var normal := TextureLibrary.find("grass_normal")
	if normal != null:
		_ground_material.set_shader_parameter("grass_normal", normal)
		_ground_material.set_shader_parameter("has_normal", true)
	else:
		TextureLibrary.warn_missing("grass_normal", "normal map'siz zemin")

	var plane := PlaneMesh.new()
	plane.size = Vector2(float(GameConfig.GRID_COLS), float(GameConfig.GRID_ROWS))
	plane.subdivide_width = GameConfig.GRID_COLS
	plane.subdivide_depth = GameConfig.GRID_ROWS

	var mi := MeshInstance3D.new()
	mi.name = "Ground"
	mi.mesh = plane
	mi.material_override = _ground_material
	add_child(mi)


## Grey stand-ins so the player can see what they are colliding with. All of
## this is replaced by real art in a later sprint.
func _build_obstacle_placeholders() -> void:
	var grey := StandardMaterial3D.new()
	grey.albedo_color = Color(0.55, 0.55, 0.55)
	grey.roughness = 0.9

	var holder := Node3D.new()
	holder.name = "ObstaclePlaceholders"
	add_child(holder)

	for ob in model.obstacles:
		var ob_name: String = ob["name"]
		var grid: Rect2i = ob["grid"]
		var world := LawnModel.grid_rect_to_world(grid)
		var center := Vector3(world.position.x + world.size.x * 0.5, 0.0,
			world.position.y + world.size.y * 0.5)
		var mi := MeshInstance3D.new()
		mi.name = "Placeholder_%s" % ob_name
		if ob_name == "pool":
			var plane := PlaneMesh.new()
			plane.size = world.size
			mi.mesh = plane
			mi.position = center + Vector3(0.0, 0.015, 0.0)
		else:
			var box := BoxMesh.new()
			box.size = Vector3(world.size.x, 0.22, world.size.y)
			mi.mesh = box
			mi.position = center + Vector3(0.0, 0.11, 0.0)
		mi.material_override = grey
		holder.add_child(mi)


# ---------------------------------------------------------------- tint

func _on_cell_tint_changed(col: int, row: int) -> void:
	# Image row 0 == texture v 0 == z -12 == grid row 0 == north (§18 trap 5).
	# The cell starts on a bright wash and eases into its real tone (G6.5).
	_flashes.append({ "col": col, "row": row, "t": 0.0 })
	_tint_image.set_pixel(col, row, _flash_color(model.tint_for(col, row)))
	_tint_dirty = true


static func _flash_color(final: Color) -> Color:
	return (final * 1.4 + Color(0.12, 0.14, 0.06)).clamp()


func repaint_all() -> void:
	_flashes.clear()
	for row in GameConfig.GRID_ROWS:
		for col in GameConfig.GRID_COLS:
			_tint_image.set_pixel(col, row, model.tint_for(col, row))
	_tint_texture.update(_tint_image)
	_tint_dirty = false


func _process(delta: float) -> void:
	if not _flashes.is_empty():
		var still: Array = []
		for f in _flashes:
			var progress: float = f["t"] + delta / GameConfig.FRESH_FLASH_TIME
			var final := model.tint_for(f["col"], f["row"])
			if progress >= 1.0:
				_tint_image.set_pixel(f["col"], f["row"], final)
			else:
				f["t"] = progress
				_tint_image.set_pixel(f["col"], f["row"],
					_flash_color(final).lerp(final, progress))
				still.append(f)
		_flashes = still
		_tint_dirty = true
	if _tint_dirty:
		_tint_texture.update(_tint_image)
		_tint_dirty = false


func on_model_reset() -> void:
	repaint_all()
	if tuft_field:
		tuft_field.refresh_all()
