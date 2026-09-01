class_name TuftField
extends Node3D
## Long grass — G6.5 overhaul. Cells are filled with VOLUMETRIC opaque clumps:
## each clump is 5-7 low-poly V-folded blades that fan outward, coloured by a
## baked root->tip vertex gradient. 8 variants carry the colour identity
## (5 vivid greens, 2 dry, 1 light green with tiny white flowers) and are
## weighted so dry patches are occasional and flowers rare.
##
## The MultiMesh layout, per-cell placement and the cut/topple animation are
## unchanged from the §5 port; only the geometry and colouring moved on.

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
## Palette-driven variant list, resolved once at setup (G6.6).
var _variants: Array = []


func setup(model: LawnModel, seed_value: int = 20260822) -> void:
	_model = model
	_variants = GameConfig.clump_variants()
	_build_material()
	_build_variants(seed_value)
	_assign_cells(seed_value)
	refresh_all()


func _build_material() -> void:
	_material = ShaderMaterial.new()
	_material.shader = load("res://shaders/grass_clump.gdshader")
	# Sway is per plant: reeds move nearly twice as much as grass, corn barely
	# moves at all, and that difference is most of what tells them apart (G13).
	_material.set_shader_parameter("wind_amplitude",
		GameConfig.WIND_AMPLITUDE * float(GameConfig.plant("sway", 1.0)))
	_material.set_shader_parameter("wind_speed", GameConfig.WIND_SPEED)
	_material.set_shader_parameter("gust_speed", GameConfig.WIND_GUST_SPEED)
	_material.set_shader_parameter("gust_length", GameConfig.WIND_GUST_LENGTH)
	_material.set_shader_parameter("gust_strength", GameConfig.WIND_GUST_STRENGTH)


func _build_variants(seed_value: int) -> void:
	for v in _variants.size():
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value + v * 7919
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = _make_cluster(rng, v)
		mm.instance_count = 0
		_meshes.append(mm)

		var mmi := MultiMeshInstance3D.new()
		mmi.name = "TuftVariant%d" % v
		mmi.multimesh = mm
		mmi.material_override = _material
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mmi)
		_instances.append(mmi)


## One clump: CLUMP_BLADES V-folded volumetric blades fanning out from a tight
## base, plus tiny white flower blobs on the flowered variant. Vertex colours
## carry the variant's root->tip gradient; UV.y carries the height fraction for
## the wind. Everything is opaque — no texture, no alpha.
## Static so the town diorama can grow the same grass with no LawnModel behind
## it: one clump mesh, one source of truth for what this game's grass looks
## like (G13.1).
static func cluster_mesh(rng: RandomNumberGenerator, variant: int) -> ArrayMesh:
	return _make_cluster(rng, variant)


static func _make_cluster(rng: RandomNumberGenerator, variant: int) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var spec: Dictionary = GameConfig.clump_variants()[variant]
	var root_col: Color = spec["base"]
	var tip_col: Color = spec["tip"]
	# One cell = one instance whose MESH holds `per_cell` plants spread across
	# the cell (G1's layout). Heights are baked per plant — bimodal: short
	# filler with tall spikes — so instance scale never shrinks footprints.
	#
	# What grows here comes from the chapter's plant profile (G13). GRASS
	# restates the original constants, so this loop draws exactly what it always
	# drew unless a chapter asked for something else.
	var per_cell := int(GameConfig.plant("per_cell", GameConfig.TUFTS_PER_CLUSTER))
	var spread := float(GameConfig.plant("spread", GameConfig.TUFT_CLUSTER_SPREAD))
	var h_min := float(GameConfig.plant("height_min", GameConfig.CLUMP_HEIGHT_MIN))
	var h_max := float(GameConfig.plant("height_max", GameConfig.CLUMP_HEIGHT_MAX))
	var tall := float(GameConfig.plant("tall_chance", GameConfig.CLUMP_TALL_CHANCE))
	var stalks := GameConfig.plant_is_stalk()
	for clump in per_cell:
		var center := Vector3(rng.randf_range(-spread, spread), 0.0,
			rng.randf_range(-spread, spread))
		var band_split := lerpf(h_min, h_max, 0.45)
		var clump_h := rng.randf_range(band_split, h_max) \
			if rng.randf() < tall else rng.randf_range(h_min, band_split)
		if stalks:
			# A stalk plant may say what colour its stem and leaves are, so a
			# sunflower can stand green in an amber field while its head keeps
			# the gold. Without the override it took the palette gradient the
			# whole way up and the crop looked dead.
			_add_stalk(st, rng, center, clump_h,
				GameConfig.plant("stalk_root", root_col) as Color,
				GameConfig.plant("stalk_tip", tip_col) as Color)
		else:
			_add_clump(st, rng, center, clump_h, root_col, tip_col, spec["flowers"])
	return st.commit()


## One upright stem with leaves, and optionally a head: corn and sunflowers.
##
## A stalk is not a tall blade. It stands rather than fans, it is thick enough
## to hide what is behind it, and its leaves hang OUT — which is what turns a
## field of them into corridors instead of a taller lawn.
static func _add_stalk(st: SurfaceTool, rng: RandomNumberGenerator,
		center: Vector3, height: float, root_col: Color, tip_col: Color) -> void:
	var width := float(GameConfig.plant("stalk_width", 0.05))
	var leaves := int(GameConfig.plant("leaves", 4))
	var leaf_len := float(GameConfig.plant("leaf_length", 0.55))
	var shade := rng.randf_range(0.92, 1.06)
	# A slight lean per stalk, so a field never looks like a pin cushion.
	var lean_dir := Vector3(rng.randf_range(-1.0, 1.0), 0.0,
		rng.randf_range(-1.0, 1.0)).normalized() * rng.randf_range(0.03, 0.11)

	# The stem: a four-sided prism tapering to the top, built as three bands so
	# the wind shader has something to bend.
	var bands: Array[float] = [0.0, 0.38, 0.72, 1.0]
	var rings: Array = []
	for lv in bands:
		var w := width * (1.0 - 0.45 * lv)
		var c := center + lean_dir * lv * lv + Vector3(0.0, height * lv, 0.0)
		var col := root_col.lerp(tip_col, lv * 0.7) * shade
		col.a = 1.0
		rings.append([[c + Vector3(-w, 0.0, -w), c + Vector3(w, 0.0, -w),
			c + Vector3(w, 0.0, w), c + Vector3(-w, 0.0, w)], col, lv])
	for i in bands.size() - 1:
		var lo: Array = rings[i]
		var hi: Array = rings[i + 1]
		var lo_ring: Array = lo[0]
		var hi_ring: Array = hi[0]
		for k in 4:
			_vquad(st, lo_ring[k], lo_ring[(k + 1) % 4], hi_ring[(k + 1) % 4],
				hi_ring[k], lo[1], lo[1].darkened(0.16), hi[1],
				hi[1].darkened(0.16), lo[2], hi[2])

	# Leaves: long, drooping, alternating around the stem.
	for i in leaves:
		var lv := 0.28 + 0.62 * float(i) / maxf(1.0, float(leaves - 1))
		var a := TAU * float(i) * 0.61 + rng.randf_range(-0.3, 0.3)
		var dir := Vector3(cos(a), 0.0, sin(a))
		var root := center + lean_dir * lv * lv + Vector3(0.0, height * lv, 0.0)
		var col := root_col.lerp(tip_col, lv) * shade
		col.a = 1.0
		var length := leaf_len * rng.randf_range(0.8, 1.15)
		var droop := -length * rng.randf_range(0.34, 0.58)
		var mid := root + dir * length * 0.55 + Vector3(0.0, length * 0.16, 0.0)
		var tip := root + dir * length + Vector3(0.0, droop, 0.0)
		var side := Vector3(-dir.z, 0.0, dir.x) * width * 1.7
		_vquad(st, root - side * 0.5, root + side * 0.5, mid + side * 0.6,
			mid - side * 0.6, col, col.darkened(0.2), col, col.darkened(0.2),
			lv, lv + 0.1)
		_vtri(st, mid - side * 0.6, mid + side * 0.6, tip,
			col, col.darkened(0.2), col.lerp(tip_col, 0.5), lv + 0.1, lv + 0.2)

	if bool(GameConfig.plant("head", false)):
		var top: Array = rings[rings.size() - 1]
		var top_ring: Array = top[0]
		var head_at: Vector3 = (top_ring[0] + top_ring[2]) * 0.5
		_add_head(st, head_at, rng)


## A sunflower head. Every one of them faces the SAME way, which is the single
## detail that makes the field read as alive rather than as scattered props.
static func _add_head(st: SurfaceTool, at: Vector3, rng: RandomNumberGenerator) -> void:
	# Two shapes. The default is a ROSETTE — petals radiating from a disc, which
	# is a sunflower and a cotton boll. A pumpkin is not that: built as a
	# rosette at gourd size it came out a spiky orange star, because the petals
	# fan outward and never close. "globe" builds a squat round body instead.
	if str(GameConfig.plant("head_shape", "rosette")) == "globe":
		_add_globe_head(st, at, rng)
		return
	var radius := float(GameConfig.plant("head_radius", 0.28))
	var yaw := float(GameConfig.plant("head_yaw", 0.0))
	var petal: Color = GameConfig.plant("head_petal", Color(0.94, 0.72, 0.16))
	var disc: Color = GameConfig.plant("head_disc", Color(0.30, 0.20, 0.10))
	var face := Vector3(sin(yaw), 0.10, cos(yaw)).normalized()
	var right := face.cross(Vector3.UP).normalized()
	var up := right.cross(face).normalized()
	var centre := at + face * radius * 0.22 + Vector3(0.0, radius * 0.55, 0.0)
	var petals := 13
	for i in petals:
		var a0 := TAU * float(i) / float(petals)
		var a1 := TAU * float(i + 1) / float(petals)
		var inner := radius * 0.42
		var outer := radius * rng.randf_range(0.94, 1.06)
		var p0 := centre + (right * cos(a0) + up * sin(a0)) * inner
		var p1 := centre + (right * cos(a1) + up * sin(a1)) * inner
		var mid_a := (a0 + a1) * 0.5
		var p2 := centre + (right * cos(mid_a) + up * sin(mid_a)) * outer
		_vtri(st, p0, p1, p2, petal, petal, petal.lightened(0.12), 1.0, 1.0)
		_vtri(st, p1, p0, p2, petal.darkened(0.15), petal.darkened(0.15),
			petal, 1.0, 1.0)
	for i in 10:
		var a0 := TAU * float(i) / 10.0
		var a1 := TAU * float(i + 1) / 10.0
		var r := radius * 0.44
		_vtri(st, centre,
			centre + (right * cos(a0) + up * sin(a0)) * r,
			centre + (right * cos(a1) + up * sin(a1)) * r,
			disc.lightened(0.1), disc, disc, 1.0, 1.0)


## A gourd: a ribbed ball sitting on the ground, with a short stub on top.
## Rings of quads around a vertical axis, squashed so it is wider than it is
## tall — a pumpkin read from the mower is a shape and a colour, and this is
## both at about sixty triangles.
static func _add_globe_head(st: SurfaceTool, at: Vector3,
		rng: RandomNumberGenerator) -> void:
	var radius := float(GameConfig.plant("head_radius", 0.34))
	var body: Color = GameConfig.plant("head_petal", Color(0.88, 0.44, 0.10))
	var deep: Color = GameConfig.plant("head_disc", Color(0.72, 0.34, 0.07))
	var squash := 0.72
	var centre := at + Vector3(0.0, radius * squash, 0.0)
	var rings := 4
	var segs := 8
	var spin := rng.randf() * TAU
	for r in rings:
		var t0 := PI * float(r) / float(rings)
		var t1 := PI * float(r + 1) / float(rings)
		var y0 := cos(t0)
		var y1 := cos(t1)
		var r0 := sin(t0)
		var r1 := sin(t1)
		for i in segs:
			# Every other segment pulled in a little: that is the ribbing, and
			# it is what stops it reading as a beach ball.
			var rib := 0.90 if i % 2 == 0 else 1.0
			var a0 := TAU * float(i) / float(segs) + spin
			var a1 := TAU * float(i + 1) / float(segs) + spin
			var p00 := centre + Vector3(cos(a0) * r0 * rib, y0 * squash,
				sin(a0) * r0 * rib) * radius
			var p10 := centre + Vector3(cos(a1) * r0 * rib, y0 * squash,
				sin(a1) * r0 * rib) * radius
			var p01 := centre + Vector3(cos(a0) * r1 * rib, y1 * squash,
				sin(a0) * r1 * rib) * radius
			var p11 := centre + Vector3(cos(a1) * r1 * rib, y1 * squash,
				sin(a1) * r1 * rib) * radius
			var shade := body.lerp(deep, float(r) / float(rings))
			_vtri(st, p00, p10, p11, shade, shade, shade.darkened(0.08), 1.0, 1.0)
			_vtri(st, p00, p11, p01, shade, shade.darkened(0.08), shade,
				1.0, 1.0)
	# The stub, so it is a pumpkin and not an orange.
	var stem: Color = Color(0.28, 0.30, 0.14)
	var top := centre + Vector3(0.0, radius * squash * 0.96, 0.0)
	for i in 4:
		var a0 := TAU * float(i) / 4.0
		var a1 := TAU * float(i + 1) / 4.0
		var w := radius * 0.13
		_vtri(st, top + Vector3(cos(a0) * w, 0.0, sin(a0) * w),
			top + Vector3(cos(a1) * w, 0.0, sin(a1) * w),
			top + Vector3(0.0, radius * 0.36, 0.0), stem, stem,
			stem.lightened(0.15), 1.0, 1.0)


static func _add_clump(st: SurfaceTool, rng: RandomNumberGenerator, center: Vector3,
		clump_h: float, root_col: Color, tip_col: Color, flowered: bool) -> void:
	# Blade count and fan width come from the plant profile (G13): a reed bed is
	# the same builder with fewer, thinner, straighter blades.
	var blades := int(GameConfig.plant("blades", GameConfig.CLUMP_BLADES)) \
		+ rng.randi_range(-1, 1)
	var base := rng.randf_range(
		float(GameConfig.plant("base_min", GameConfig.CLUMP_BASE_MIN)),
		float(GameConfig.plant("base_max", GameConfig.CLUMP_BASE_MAX)))
	var width_scale := float(GameConfig.plant("width_scale", 1.0))
	var lean_scale := float(GameConfig.plant("lean_scale", 1.0))
	var flower_slots: Array[int] = []
	if flowered and rng.randf() < 0.5:
		for f in rng.randi_range(2, 3):
			flower_slots.append(rng.randi_range(0, blades - 1))

	for b in blades:
		var a := TAU * (float(b) + rng.randf_range(-0.2, 0.2)) / float(blades)
		var lean_dir := Vector3(cos(a), 0.0, sin(a))
		# Tight at the base, fanning outward toward the tips.
		var root_off := center + lean_dir * rng.randf_range(0.02, 0.10)
		var height := clump_h * rng.randf_range(0.8, 1.05)
		var lean := rng.randf_range(0.20, 0.36) * base * lean_scale
		var width := rng.randf_range(0.12, 0.18) * (base / 0.42) * width_scale
		var tip := _add_blade(st, root_off, lean_dir, lean, height, width,
			root_col, tip_col, rng)
		if flower_slots.has(b):
			_add_flower(st, tip)


## A V-folded 2-segment blade: three columns of vertices (left, creased centre,
## right) so it reads thick from every angle without alpha.
static func _add_blade(st: SurfaceTool, root: Vector3, dir: Vector3, lean: float,
		height: float, width: float, root_col: Color, tip_col: Color,
		rng: RandomNumberGenerator) -> Vector3:
	var side := Vector3(-dir.z, 0.0, dir.x)
	var crease := dir * width * 0.45     # centre pushed out = the V fold
	var shade := rng.randf_range(0.9, 1.05)

	# Levels: root (0), mid (0.55), tip (1.0, converges to a point).
	var levels: Array[float] = [0.0, 0.55, 1.0]
	var rows: Array = []
	for lv in levels:
		var w := width * (1.0 - 0.82 * lv)
		var center := root + dir * (lean * lv * lv) + Vector3(0.0, height * lv, 0.0)
		var col := root_col.lerp(tip_col, lv) * shade
		col.a = 1.0
		var dark := col.darkened(0.18)
		if lv >= 0.999:
			rows.append([center + crease * 0.2, col, dark, lv])   # tip point
		else:
			rows.append([
				center - side * w * 0.5, center + crease, center + side * w * 0.5,
				col, dark, lv])

	# Segment 1: root row -> mid row (two quads across the V).
	for seg in 1:
		var r0: Array = rows[0]
		var r1: Array = rows[1]
		_vquad(st, r0[0], r0[1], r1[1], r1[0], r0[3], r0[4], r1[3], r1[4], r0[5], r1[5])
		_vquad(st, r0[1], r0[2], r1[2], r1[1], r0[4], r0[3], r1[4], r1[3], r0[5], r1[5])
	# Segment 2: mid row -> tip point (two triangles).
	var m: Array = rows[1]
	var tp: Array = rows[2]
	_vtri(st, m[0], m[1], tp[0], m[3], m[4], tp[1], m[5], tp[3])
	_vtri(st, m[1], m[2], tp[0], m[4], m[3], tp[1], m[5], tp[3])
	return tp[0]


static func _vquad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3,
		col_ab: Color, col_b: Color, col_cd: Color, col_c: Color,
		v0: float, v1: float) -> void:
	var n := (b - a).cross(d - a).normalized()
	_v(st, a, col_ab, v0, n)
	_v(st, b, col_b, v0, n)
	_v(st, c, col_c, v1, n)
	_v(st, a, col_ab, v0, n)
	_v(st, c, col_c, v1, n)
	_v(st, d, col_cd, v1, n)


static func _vtri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3,
		col_a: Color, col_b: Color, col_c: Color, v0: float, v1: float) -> void:
	var n := (b - a).cross(c - a).normalized()
	_v(st, a, col_a, v0, n)
	_v(st, b, col_b, v0, n)
	_v(st, c, col_c, v1, n)


static func _v(st: SurfaceTool, pos: Vector3, col: Color, height_frac: float, n: Vector3) -> void:
	# Vertex colours reach a custom spatial shader as LINEAR data; baking the
	# sRGB palette values raw would render washed-out pale (it did).
	st.set_color(col.srgb_to_linear())
	st.set_uv(Vector2(0.0, height_frac))
	st.set_normal(n)
	st.add_vertex(pos)


## Tiny white flower: a 6-vertex octahedron at a blade tip. Opaque, cheap.
static func _add_flower(st: SurfaceTool, tip: Vector3) -> void:
	var r := 0.045
	var white := Color(0.96, 0.96, 0.92)
	var c := tip + Vector3(0.0, r * 0.6, 0.0)
	var top := c + Vector3(0.0, r, 0.0)
	var bottom := c - Vector3(0.0, r, 0.0)
	var ring: Array[Vector3] = [
		c + Vector3(r, 0.0, 0.0), c + Vector3(0.0, 0.0, r),
		c + Vector3(-r, 0.0, 0.0), c + Vector3(0.0, 0.0, -r)]
	for i in 4:
		var p0: Vector3 = ring[i]
		var p1: Vector3 = ring[(i + 1) % 4]
		_vtri(st, p0, p1, top, white, white, white, 1.0, 1.0)
		_vtri(st, p1, p0, bottom, white, white, white, 1.0, 1.0)


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
	counts.resize(_variants.size())

	for row in GameConfig.GRID_ROWS:
		for col in GameConfig.GRID_COLS:
			var i := LawnModel.index_of(col, row)
			if not _model.is_mowable(col, row):
				_cell_slot[i] = -1
				continue
			var v := _weighted_variant(rng)
			_cell_variant[i] = v
			_cell_slot[i] = counts[v]
			counts[v] += 1
			_cell_yaw[i] = rng.randf() * TAU
			_cell_scale[i] = rng.randf_range(
				GameConfig.TUFT_CELL_SCALE_MIN, GameConfig.TUFT_CELL_SCALE_MAX)
			# In-cell jitter; cluster spread is +/-0.34 so +/-0.15 keeps it inside.
			_cell_origin[i] = LawnModel.cell_center(col, row) + Vector3(
				rng.randf_range(-0.18, 0.18), 0.0, rng.randf_range(-0.18, 0.18))
			# Variants carry the hue now; per-cell tint is brightness only.
			var bright := rng.randf_range(0.92, 1.08)
			_cell_color[i] = Color(bright, bright, bright, 1.0)

	for v in _variants.size():
		_meshes[v].instance_count = counts[v]


func _weighted_variant(rng: RandomNumberGenerator) -> int:
	var total := 0.0
	for spec in _variants:
		total += spec["weight"]
	var pick := rng.randf() * total
	for v in _variants.size():
		pick -= _variants[v]["weight"]
		if pick <= 0.0:
			return v
	return 0


## Representative colour of the clump on a cell — the clippings borrow it so a
## dry-yellow clump throws dry-yellow cuttings (G6.5).
func clump_tint(col: int, row: int) -> Color:
	var i := LawnModel.index_of(col, row)
	if i < 0 or i >= _cell_variant.size() or _cell_slot[i] < 0:
		return GameConfig.clipping_color()
	var tip: Color = _variants[int(_cell_variant[i])]["tip"]
	return tip * _cell_color[i]


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
