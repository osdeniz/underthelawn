class_name BladeMower
extends MowerController
## G6 Blade: a free-roaming saw disk, the fantasy/flair mower. Unlike the other
## three it has NO heading — while a finger holds on or near the disk, the disk
## chases the finger's ground point at BLADE_FOLLOW_SPEED, glides to a stop
## when the finger lifts, and never steers. Wall clipping, obstacle push-out
## and the deck sweep all come from the MowerController core.

const GRAB_RADIUS := 2.5      # how close (world units) a press must land

var _target := Vector3.ZERO
var _has_finger := false
var _touch_index := -1
var _velocity := Vector3.ZERO
var _glide := 0.0

var _disk: Node3D
var _blur_ring: MeshInstance3D
var _trail: GPUParticles3D
var _sparks: GPUParticles3D
var _spark_audio: AudioStreamPlayer3D
var _spark_cooldown := 0.0
var _spin_rate := GameConfig.BLADE_SPIN_IDLE_DEG


func type_index() -> int:
	return GameConfig.MOWER_BLADE


## Mesh, cut radius and collision all grow from the one BLADE_SCALE number, so
## a future Size upgrade only touches that constant (G6.6).
func deck_radius() -> float:
	return params["deck"] * GameConfig.BLADE_SCALE


func body_radius() -> float:
	return params["body"] * GameConfig.BLADE_SCALE


func _ready() -> void:
	_build_model()
	super()


func _on_active_changed(value: bool) -> void:
	_has_finger = false
	_touch_index = -1
	_velocity = Vector3.ZERO
	if not value and _trail:
		_trail.emitting = false


# ---------------------------------------------------------------- input

func on_touch_pressed(index: int, screen_pos: Vector2) -> void:
	if _touch_index != -1:
		return
	var hit := ground_point(screen_pos)
	if Vector2(hit.x - position.x, hit.z - position.z).length() > GRAB_RADIUS:
		return
	_touch_index = index
	_has_finger = true
	_target = hit


func on_touch_dragged(index: int, screen_pos: Vector2) -> void:
	if index != _touch_index:
		return
	_target = ground_point(screen_pos)


func on_touch_released(index: int, _screen_pos: Vector2) -> void:
	if index != _touch_index:
		return
	_touch_index = -1
	_has_finger = false
	_glide = GameConfig.BLADE_GLIDE_TIME


# ---------------------------------------------------------------- movement

## Fully replaces the core throttle/steering loop: direct chase, no yaw.
func _physics_process(delta: float) -> void:
	if _has_finger:
		var to_target := _target - position
		to_target.y = 0.0
		var dist := to_target.length()
		if dist > 0.01:
			# Proportional chase: speed scales with how far the finger is, up to
			# the cap. Drifts under fine control, accelerates on a big sweep.
			var desired := minf(dist * GameConfig.BLADE_FOLLOW_GAIN,
				GameConfig.BLADE_MAX_SPEED)
			var step := minf(desired * delta, dist)
			var dir := to_target / dist
			_velocity = dir * desired
			position += dir * step
		else:
			_velocity = Vector3.ZERO
	elif _glide > 0.0:
		# Short coast after release.
		_glide = maxf(_glide - delta, 0.0)
		_velocity *= maxf(_glide / GameConfig.BLADE_GLIDE_TIME, 0.0)
		position += _velocity * delta
	else:
		_velocity = Vector3.ZERO

	# The core's speed drives the engine mix; stripes follow the motion heading.
	speed = _velocity.length()
	if speed > 0.2:
		yaw = atan2(_velocity.x, -_velocity.z)

	_resolve_walls()
	_resolve_obstacles()
	_mow(delta)
	_check_spark(delta)

	if _trail:
		_trail.emitting = GameConfig.BLADE_FX_ENABLED and speed > 4.0


func _process(delta: float) -> void:
	# Idles lazily, revs up with motion, and eases between the two so the change
	# reads as spin-up rather than a snap (G6.8).
	var target_rate := lerpf(GameConfig.BLADE_SPIN_IDLE_DEG,
		GameConfig.BLADE_SPIN_FAST_DEG, speed_fraction())
	_spin_rate = lerpf(_spin_rate, target_rate,
		minf(1.0, GameConfig.BLADE_SPIN_LERP * delta))
	if _disk:
		_disk.rotation.y += deg_to_rad(_spin_rate) * delta
	if _blur_ring:
		_blur_ring.rotation.y -= deg_to_rad(_spin_rate) * 0.6 * delta
		# The blur halo only earns its keep once the thing is really moving.
		var mat := _blur_ring.material_override as StandardMaterial3D
		if mat:
			mat.albedo_color.a = 0.20 * speed_fraction()


## No engine body shudder; the disk spin IS the life.
func _idle_shake(_delta: float) -> void:
	pass


## Orange spark burst + metallic clink + 25 ms haptic when the disk grinds the
## stone obstacle's edge (collision rect index 1 in LawnModel.OBSTACLES).
func _check_spark(delta: float) -> void:
	_spark_cooldown = maxf(_spark_cooldown - delta, 0.0)
	if not GameConfig.BLADE_FX_ENABLED or model == null or _spark_cooldown > 0.0:
		return
	if speed < 1.0:
		return
	var stone: Rect2 = model.collision_rects[1]
	var p := Vector2(position.x, position.z)
	var closest := Vector2(clampf(p.x, stone.position.x, stone.end.x),
		clampf(p.y, stone.position.y, stone.end.y))
	if p.distance_to(closest) > body_radius() + 0.06:
		return
	_spark_cooldown = GameConfig.BLADE_SPARK_COOLDOWN
	if _sparks:
		_sparks.restart()
		_sparks.emitting = true
	if _spark_audio and _spark_audio.stream != null:
		_spark_audio.play()
	Haptics.medium()


# ---------------------------------------------------------------- model (G6.8)

## Ceremonial chakram from the reference art: four cream-and-gold arms ending in
## crescent horns, four green gems set between them, and an ornate pierced gold
## hub. Arms are extruded 2D silhouettes (triangulated), so the concave crescent
## notch comes out clean; colour banding is baked into vertex colours instead of
## textures. Span ~2.0, riding 0.15 above the ground.
func _build_model() -> void:
	var body := Node3D.new()
	body.name = "Body"
	add_child(body)

	_disk = Node3D.new()
	_disk.name = "Disk"
	_disk.position.y = 0.15
	_disk.scale = Vector3.ONE * GameConfig.BLADE_SCALE
	body.add_child(_disk)

	_build_plate()
	_build_gems()
	_build_hub()

	if GameConfig.BLADE_FX_ENABLED:
		_build_fx(body)
	_build_clippings()
	_spark_audio = AudioStreamPlayer3D.new()
	_spark_audio.stream = TrafficController._find_audio("res://audio/blade_hit")
	_spark_audio.unit_size = 10.0
	if _spark_audio.stream == null:
		print("[Blade] audio/blade_hit.ogg yok - kivilcim sesi sessiz")
	add_child(_spark_audio)


## Outer silhouette MEASURED from the supplied line-art trace
## (textures/chakram1.0.svg) by tools/trace_chakram.gd, in world units. The
## shape is star-shaped about its centre, so a polar sweep captures it exactly —
## crescent notches included — and the four sectors were averaged to force exact
## 4-fold symmetry. Regenerate by re-running the tracer.
const PLATE_OUTLINE: Array[Vector2] = [
	Vector2(0.9658, 0.0000), Vector2(0.9372, 0.0460), Vector2(0.9870, 0.0972), Vector2(1.0067, 0.1493), 
	Vector2(0.9877, 0.1965), Vector2(0.9643, 0.2415), Vector2(0.9315, 0.2826), Vector2(0.8964, 0.3208), 
	Vector2(0.7239, 0.2998), Vector2(0.6876, 0.3252), Vector2(0.6533, 0.3492), Vector2(0.4443, 0.2663), 
	Vector2(0.3375, 0.2255), Vector2(0.2672, 0.1981), Vector2(0.2536, 0.2081), Vector2(0.2414, 0.2188), 
	Vector2(0.2303, 0.2303), Vector2(0.2183, 0.2408), Vector2(0.2071, 0.2524), Vector2(0.2181, 0.2941), 
	Vector2(0.2064, 0.3089), Vector2(0.2632, 0.4391), Vector2(0.2888, 0.5403), Vector2(0.3193, 0.6752), 
	Vector2(0.2952, 0.7126), Vector2(0.3172, 0.8864), Vector2(0.2799, 0.9228), Vector2(0.2391, 0.9547), 
	Vector2(0.1954, 0.9824), Vector2(0.1488, 1.0029), Vector2(0.0972, 0.9870), Vector2(0.0469, 0.9555), 
	Vector2(0.0000, 0.9658), Vector2(-0.0460, 0.9372), Vector2(-0.0972, 0.9870), Vector2(-0.1493, 1.0067), 
	Vector2(-0.1968, 0.9892), Vector2(-0.2415, 0.9643), Vector2(-0.2826, 0.9315), Vector2(-0.3208, 0.8964), 
	Vector2(-0.2998, 0.7239), Vector2(-0.3252, 0.6876), Vector2(-0.3492, 0.6533), Vector2(-0.2663, 0.4443), 
	Vector2(-0.2255, 0.3375), Vector2(-0.1981, 0.2672), Vector2(-0.2081, 0.2536), Vector2(-0.2188, 0.2414), 
	Vector2(-0.2303, 0.2303), Vector2(-0.2408, 0.2183), Vector2(-0.2524, 0.2071), Vector2(-0.2941, 0.2181), 
	Vector2(-0.3089, 0.2064), Vector2(-0.4391, 0.2632), Vector2(-0.5403, 0.2888), Vector2(-0.6752, 0.3193), 
	Vector2(-0.7126, 0.2952), Vector2(-0.8864, 0.3172), Vector2(-0.9228, 0.2799), Vector2(-0.9547, 0.2391), 
	Vector2(-0.9787, 0.1947), Vector2(-1.0029, 0.1488), Vector2(-0.9870, 0.0972), Vector2(-0.9555, 0.0469), 
	Vector2(-0.9658, 0.0000), Vector2(-0.9372, -0.0460), Vector2(-0.9870, -0.0972), Vector2(-1.0067, -0.1493), 
	Vector2(-0.9877, -0.1965), Vector2(-0.9643, -0.2415), Vector2(-0.9315, -0.2826), Vector2(-0.8964, -0.3208), 
	Vector2(-0.7239, -0.2998), Vector2(-0.6876, -0.3252), Vector2(-0.6533, -0.3492), Vector2(-0.4443, -0.2663), 
	Vector2(-0.3375, -0.2255), Vector2(-0.2672, -0.1981), Vector2(-0.2536, -0.2081), Vector2(-0.2414, -0.2188), 
	Vector2(-0.2303, -0.2303), Vector2(-0.2183, -0.2408), Vector2(-0.2071, -0.2524), Vector2(-0.2181, -0.2941), 
	Vector2(-0.2064, -0.3089), Vector2(-0.2632, -0.4391), Vector2(-0.2888, -0.5403), Vector2(-0.3193, -0.6752), 
	Vector2(-0.2952, -0.7126), Vector2(-0.3172, -0.8864), Vector2(-0.2799, -0.9228), Vector2(-0.2391, -0.9547), 
	Vector2(-0.1947, -0.9787), Vector2(-0.1488, -1.0029), Vector2(-0.0972, -0.9870), Vector2(-0.0469, -0.9555), 
	Vector2(-0.0000, -0.9658), Vector2(0.0460, -0.9372), Vector2(0.0972, -0.9870), Vector2(0.1493, -1.0067), 
	Vector2(0.1968, -0.9892), Vector2(0.2415, -0.9643), Vector2(0.2826, -0.9315), Vector2(0.3208, -0.8964), 
	Vector2(0.2998, -0.7239), Vector2(0.3252, -0.6876), Vector2(0.3492, -0.6533), Vector2(0.2663, -0.4443), 
	Vector2(0.2255, -0.3375), Vector2(0.1981, -0.2672), Vector2(0.2081, -0.2536), Vector2(0.2188, -0.2414), 
	Vector2(0.2303, -0.2303), Vector2(0.2408, -0.2183), Vector2(0.2524, -0.2071), Vector2(0.2941, -0.2181), 
	Vector2(0.3089, -0.2064), Vector2(0.4391, -0.2632), Vector2(0.5403, -0.2888), Vector2(0.6752, -0.3193), 
	Vector2(0.7126, -0.2952), Vector2(0.8864, -0.3172), Vector2(0.9228, -0.2799), Vector2(0.9547, -0.2391), 
	Vector2(0.9787, -0.1947), Vector2(1.0029, -0.1488), Vector2(0.9870, -0.0972), Vector2(0.9555, -0.0469), 
]


## One extruded plate for the whole chakram. The plate texture is colourised
## from the SAME SVG, so a plain top-down UV registers every engraved line with
## the geometry — that alignment is the whole point of tracing.
func _build_plate() -> void:
	var mat := StandardMaterial3D.new()
	mat.metallic = 0.16
	mat.roughness = 0.34
	var plate_tex := TextureLibrary.find("chakram_plate")
	if plate_tex != null:
		mat.albedo_texture = plate_tex
		# The texture punches alpha out inside the hub, making the centre a real
		# hole rather than a painted one.
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		mat.alpha_scissor_threshold = 0.5
	else:
		TextureLibrary.warn_missing("chakram_plate", "duz altin plaka")
		mat.albedo_color = GameConfig.BLADE_CREAM

	var half := GameConfig.BLADE_PLATE_THICK * 0.5
	var count := PLATE_OUTLINE.size()
	var top: Array[Vector3] = []
	var bottom: Array[Vector3] = []
	var uvs: Array[Vector2] = []
	var flat := PackedVector2Array()

	for raw in PLATE_OUTLINE:
		# Sharpen: keep the horn tips, squeeze everything nearer the hub inward.
		var reach := GameConfig.BLADE_ARM_REACH
		var pt := raw
		var rr := raw.length()
		if rr > 0.0001:
			# Fade the squeeze in past the hub, or the engraved hub frame
			# collapses into the centre hole.
			var g := lerpf(1.0, GameConfig.BLADE_PLATE_SHARPEN,
				smoothstep(0.34, 0.62, rr))
			pt = raw * (reach * pow(minf(rr / reach, 1.0), g) / rr)
		var radius := pt.length()
		# Gentle dome: thicker toward the hub, thinning at the horns.
		var crown := half + (1.0 - clampf(radius / 1.02, 0.0, 1.0)) * 0.05
		top.append(Vector3(pt.x, crown, pt.y))
		bottom.append(Vector3(pt.x, -half, pt.y))
		# UV from the untouched trace, so the engraved rim line still lands
		# exactly on the rim after sharpening.
		uvs.append(_plate_uv(raw.x, raw.y))
		flat.append(pt)

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tris := Geometry2D.triangulate_polygon(flat)
	for i in range(0, tris.size(), 3):
		var a: int = tris[i]
		var b: int = tris[i + 1]
		var c: int = tris[i + 2]
		_face(st, top[a], top[b], top[c], Color.WHITE, Color.WHITE, Color.WHITE,
			Vector3.UP, uvs[a], uvs[b], uvs[c])
		_face(st, bottom[a], bottom[b], bottom[c],
			Color(0.45, 0.40, 0.30), Color(0.45, 0.40, 0.30), Color(0.45, 0.40, 0.30),
			Vector3.DOWN, uvs[a], uvs[b], uvs[c])

	# Rim wall around the whole silhouette.
	for i in count:
		var j := (i + 1) % count
		var wall := (top[j] - top[i]).cross(Vector3.UP)
		if wall.length_squared() < 0.000001:
			continue
		wall = wall.normalized()
		_face(st, top[i], top[j], bottom[j], Color.WHITE, Color.WHITE, Color.WHITE,
			wall, uvs[i], uvs[j], uvs[j])
		_face(st, top[i], bottom[j], bottom[i], Color.WHITE, Color.WHITE, Color.WHITE,
			wall, uvs[i], uvs[j], uvs[i])

	var mi := MeshInstance3D.new()
	mi.name = "Plate"
	mi.mesh = st.commit()
	mi.material_override = mat
	# Nothing on the chakram casts: the plate would paint hard swirls on the
	# blur halo a few centimetres below it.
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_disk.add_child(mi)


## Top-down UV using the tracer's own metrics, so texture and mesh share a frame.
static func _plate_uv(x: float, z: float) -> Vector2:
	const HALF_EXTENT := 1.30
	return Vector2(x / (2.0 * HALF_EXTENT) + 0.5, z / (2.0 * HALF_EXTENT) + 0.5)


## Four green gems set into the gaps between arms, pointing outward.
func _build_gems() -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = GameConfig.BLADE_GEM
	mat.metallic = 0.05
	mat.roughness = 0.22
	mat.emission_enabled = true
	mat.emission = GameConfig.BLADE_GEM
	mat.emission_energy_multiplier = 1.6

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 4:
		var a := TAU * (float(i) + 0.5) / 4.0
		var cs := cos(a)
		var sn := sin(a)
		# Kite shape: narrow at the hub, wide shoulders, sharp point outward.
		# The traced silhouette narrows to ~0.29 between arms, so the gems have
		# to sit inside that or they poke out past the plate.
		var pts: Array[Vector2] = [
			Vector2(0.165, 0.0), Vector2(0.235, 0.058),
			Vector2(0.300, 0.0), Vector2(0.235, -0.058),
		]
		var ring: Array[Vector3] = []
		for pt in pts:
			# Above the plate crown, or the plate swallows them.
			ring.append(Vector3(pt.x * cs - pt.y * sn, 0.062, pt.x * sn + pt.y * cs))
		var peak := Vector3(0.235 * cs, 0.108, 0.235 * sn)
		var col := GameConfig.BLADE_GEM
		var bright := GameConfig.BLADE_GEM.lightened(0.55)
		for k in 4:
			var p0: Vector3 = ring[k]
			var p1: Vector3 = ring[(k + 1) % 4]
			var n := (p1 - p0).cross(peak - p0).normalized()
			_face(st, p0, p1, peak, col, col, bright, n)
	var mi := MeshInstance3D.new()
	mi.name = "Gems"
	mi.mesh = st.commit()
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_disk.add_child(mi)


## Pierced hub: a thick gold ring, a stepped inner collar, and a diamond frame
## whose corners read as the reference's four square windows.
func _build_hub() -> void:
	var gold := StandardMaterial3D.new()
	gold.albedo_color = GameConfig.BLADE_GOLD
	gold.metallic = 0.7
	gold.roughness = 0.28
	var deep := StandardMaterial3D.new()
	deep.albedo_color = GameConfig.BLADE_GOLD.darkened(0.35)
	deep.metallic = 0.65
	deep.roughness = 0.4

	# A narrow raised lip only. A full-width torus buried the hub frame that the
	# plate texture already draws from the reference.
	var ring := TorusMesh.new()
	ring.inner_radius = GameConfig.BLADE_HUB_INNER - 0.005
	ring.outer_radius = GameConfig.BLADE_HUB_INNER + 0.038
	ring.rings = 32
	ring.ring_segments = 8
	_hub_piece(ring, gold, Vector3(0.0, 0.026, 0.0))

	# G6.9 item 4: fine radial teeth around the ring's inner mouth — small, but
	# it is the detail that sells the hub as machined rather than a plain donut.
	var tooth := BoxMesh.new()
	tooth.size = Vector3(0.016, 0.022, 0.030)
	for i in 24:
		var a := TAU * float(i) / 24.0
		var mi := _hub_piece(tooth, deep, Vector3(
			cos(a) * (GameConfig.BLADE_HUB_INNER + 0.006), 0.040,
			sin(a) * (GameConfig.BLADE_HUB_INNER + 0.006)))
		mi.rotation.y = -a

	# The diamond frame and its square windows come from the plate texture now,
	# traced from the reference — no need to model bars over the top of them.


func _hub_piece(mesh: Mesh, mat: Material, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_disk.add_child(mi)
	return mi


## One coloured triangle facing `n`. Godot treats CLOCKWISE as front-facing, so
## the winding is chosen to put the CCW cross product opposite `n`.
func _face(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3,
		ca: Color, cb: Color, cc: Color, n: Vector3,
		ua := Vector2(0.5, 0.5), ub := Vector2(0.5, 0.5),
		uc := Vector2(0.5, 0.5)) -> void:
	if (b - a).cross(c - a).dot(n) > 0.0:
		_cv(st, a, ca, n, ua)
		_cv(st, c, cc, n, uc)
		_cv(st, b, cb, n, ub)
		return
	_cv(st, a, ca, n, ua)
	_cv(st, b, cb, n, ub)
	_cv(st, c, cc, n, uc)


func _cv(st: SurfaceTool, pos: Vector3, col: Color, n: Vector3,
		uv := Vector2(0.5, 0.5)) -> void:
	st.set_color(col.srgb_to_linear())
	st.set_normal(n)
	st.set_uv(uv)
	st.add_vertex(pos)


func _build_fx(body: Node3D) -> void:
	# Faint counter-rotating streak ring under the disk: motion-blur feel.
	# Translucent white-blue disk under the chakram: the spin smears into a
	# faint halo the eye reads as motion.
	var blur := CylinderMesh.new()
	blur.top_radius = 0.95
	blur.bottom_radius = 0.95
	blur.height = 0.004
	blur.radial_segments = 32
	var blur_mat := StandardMaterial3D.new()
	blur_mat.albedo_color = Color(0.82, 0.94, 1.0, 0.0)
	blur_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	blur_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	blur_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_blur_ring = MeshInstance3D.new()
	_blur_ring.mesh = blur
	_blur_ring.material_override = blur_mat
	_blur_ring.position.y = 0.115
	_blur_ring.scale = Vector3.ONE * GameConfig.BLADE_SCALE
	_blur_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body.add_child(_blur_ring)

	# Short green trail while moving fast: soft fading blobs, not hard quads.
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 12.0
	pm.initial_velocity_min = 0.02
	pm.initial_velocity_max = 0.08
	pm.gravity = Vector3.ZERO
	pm.scale_min = 0.5
	pm.scale_max = 0.9
	pm.color = Color(0.45, 0.85, 0.35, 0.35)
	# Fade out over the particle's life.
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 1))
	ramp.set_color(1, Color(1, 1, 1, 0))
	var ramp_tex := GradientTexture1D.new()
	ramp_tex.gradient = ramp
	pm.color_ramp = ramp_tex
	var quad := QuadMesh.new()
	quad.size = Vector2(0.4, 0.4)
	var qm := StandardMaterial3D.new()
	qm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	qm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	qm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	qm.vertex_color_use_as_albedo = true
	# The soft cloud blob makes each puff round and feathered.
	qm.albedo_texture = TextureLibrary.find("cloud_billboard")
	quad.material = qm
	_trail = GPUParticles3D.new()
	_trail.process_material = pm
	_trail.draw_pass_1 = quad
	_trail.amount = 20
	_trail.lifetime = 0.3
	_trail.local_coords = false
	_trail.emitting = false
	_trail.position.y = 0.08
	add_child(_trail)

	# Orange spark burst for the stone grind.
	var sm := ParticleProcessMaterial.new()
	sm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	sm.emission_sphere_radius = 0.3
	sm.direction = Vector3(0, 1, 0)
	sm.spread = 70.0
	sm.initial_velocity_min = 2.0
	sm.initial_velocity_max = 4.5
	sm.gravity = Vector3(0, -9.8, 0)
	sm.scale_min = 0.4
	sm.scale_max = 0.9
	sm.color = Color(1.0, 0.55, 0.12)
	var squad := QuadMesh.new()
	squad.size = Vector2(0.06, 0.06)
	var sqm := StandardMaterial3D.new()
	sqm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sqm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sqm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	sqm.vertex_color_use_as_albedo = true
	squad.material = sqm
	_sparks = GPUParticles3D.new()
	_sparks.process_material = sm
	_sparks.draw_pass_1 = squad
	_sparks.amount = 26
	_sparks.lifetime = 0.2
	_sparks.one_shot = true
	_sparks.explosiveness = 0.95
	_sparks.local_coords = false
	_sparks.emitting = false
	_sparks.position.y = 0.12
	add_child(_sparks)


## Clippings burst in EVERY direction at double density — the right-side rule
## does not apply to the blade (G6).
func _build_clippings() -> void:
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	pm.emission_ring_radius = 0.62 * GameConfig.BLADE_SCALE
	pm.emission_ring_inner_radius = 0.32 * GameConfig.BLADE_SCALE
	pm.emission_ring_height = 0.02
	pm.emission_ring_axis = Vector3(0, 1, 0)
	pm.spread = 80.0
	pm.direction = Vector3(0, 1, 0)
	pm.initial_velocity_min = 1.6
	pm.initial_velocity_max = 4.2
	pm.gravity = Vector3(0, GameConfig.CLIP_GRAVITY, 0)
	pm.angular_velocity_min = 120.0
	pm.angular_velocity_max = 480.0
	pm.scale_min = 0.8
	pm.scale_max = 1.25
	var quad := QuadMesh.new()
	quad.size = Vector2(0.045, 0.12)
	var qm := StandardMaterial3D.new()
	qm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	qm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	qm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	qm.albedo_texture = TextureLibrary.leaf_particle()
	pm.color = GameConfig.clipping_color()
	quad.material = qm
	var clippings := GPUParticles3D.new()
	clippings.name = "Clippings"
	clippings.process_material = pm
	clippings.draw_pass_1 = quad
	pm.lifetime_randomness = 0.4167
	clippings.amount = 108   # double the mower clip density
	clippings.lifetime = 0.6
	clippings.local_coords = false
	clippings.emitting = false
	clippings.position.y = 0.1
	add_child(clippings)
