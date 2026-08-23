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

	_build_arms()
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


## Half of one arm's outline, from the hub out to the horn tip. Mirrored to make
## the full closed silhouette. x = radius, y = lateral half-width.
const ARM_SIDE: Array[Vector2] = [
	Vector2(0.26, 0.105),
	Vector2(0.40, 0.150),
	Vector2(0.56, 0.185),
	Vector2(0.72, 0.225),
	Vector2(0.86, 0.272),
	Vector2(0.97, 0.300),
	Vector2(1.02, 0.246),   # horn tip
]
## The crescent notch cutting back in between the two horns.
const ARM_NOTCH: Array[Vector2] = [
	Vector2(0.925, 0.150),
	Vector2(0.860, 0.070),
	Vector2(0.840, 0.000),
]


func _build_arms() -> void:
	var outline: Array[Vector2] = []
	for pt in ARM_SIDE:
		outline.append(pt)
	for pt in ARM_NOTCH:
		outline.append(pt)
	for i in range(ARM_NOTCH.size() - 2, -1, -1):
		outline.append(Vector2(ARM_NOTCH[i].x, -ARM_NOTCH[i].y))
	for i in range(ARM_SIDE.size() - 1, -1, -1):
		outline.append(Vector2(ARM_SIDE[i].x, -ARM_SIDE[i].y))

	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	# Low metallic: at 0.45 the arms mirrored the bright sky and read as white
	# plastic instead of painted gold.
	mat.metallic = 0.12
	mat.roughness = 0.38

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for arm in 4:
		_extrude_arm(st, outline, TAU * float(arm) / 4.0)
	var mi := MeshInstance3D.new()
	mi.name = "Arms"
	mi.mesh = st.commit()
	mi.material_override = mat
	# Nothing on the chakram casts: the plate would paint hard black swirls on
	# the blur halo 3 cm below it.
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_disk.add_child(mi)


## Concentric colour bands along the arm: rich gold at the root, cream across
## the body, silver at the horns. Banding is keyed to RADIUS because the
## silhouette has no vertices on the spine — a lateral gradient had nothing to
## paint and every arm came out flat cream.
static func _arm_color(radius: float, lateral: float, half_width: float) -> Color:
	var col: Color
	# The gold band has to reach past r~0.47, where the hub's diamond bars stop
	# covering the arm, or it is never seen.
	if radius < 0.74:
		col = GameConfig.BLADE_GOLD.lerp(GameConfig.BLADE_CREAM,
			clampf((radius - 0.30) / 0.44, 0.0, 1.0))
	else:
		col = GameConfig.BLADE_CREAM.lerp(GameConfig.BLADE_SILVER,
			clampf((radius - 0.80) / 0.20, 0.0, 1.0))
	# Two darker rings standing in for the reference's engraved arcs; the radii
	# sit on outline vertex rings so they actually land.
	var arc := exp(-pow((radius - 0.57) / 0.055, 2.0)) \
		+ exp(-pow((radius - 0.87) / 0.055, 2.0))
	col = col.darkened(clampf(arc, 0.0, 1.0) * 0.26)
	# Rim shading: the outer edge of each arm catches a warmer line.
	var edge := absf(lateral) / maxf(half_width, 0.001)
	return col.lerp(GameConfig.BLADE_GOLD.darkened(0.15),
		clampf(edge - 0.74, 0.0, 1.0) * 0.7)


func _extrude_arm(st: SurfaceTool, outline: Array[Vector2], rot: float) -> void:
	var half := GameConfig.BLADE_PLATE_THICK * 0.5
	var cs := cos(rot)
	var sn := sin(rot)
	var count := outline.size()

	# Flat outline -> 3D, rotated into place around the hub.
	var top: Array[Vector3] = []
	var bottom: Array[Vector3] = []
	var cols: Array[Color] = []
	var flat := PackedVector2Array()
	for pt in outline:
		var x := pt.x * cs - pt.y * sn
		var z := pt.x * sn + pt.y * cs
		# The spine is raised, giving the arm a shallow roof like the reference.
		var crown := half + (1.0 - clampf(absf(pt.y) / 0.30, 0.0, 1.0)) * 0.075
		top.append(Vector3(x, crown, z))
		bottom.append(Vector3(x, -half, z))
		cols.append(_arm_color(pt.x, pt.y, 0.30))
		flat.append(pt)

	# Triangulate the concave silhouette once, reuse for both faces.
	var tris := Geometry2D.triangulate_polygon(flat)
	for i in range(0, tris.size(), 3):
		var a: int = tris[i]
		var b: int = tris[i + 1]
		var c: int = tris[i + 2]
		_face(st, top[a], top[b], top[c], cols[a], cols[b], cols[c], Vector3.UP)
		_face(st, bottom[a], bottom[b], bottom[c],
			cols[a].darkened(0.45), cols[b].darkened(0.45), cols[c].darkened(0.45),
			Vector3.DOWN)

	# Rim walls all the way round.
	for i in count:
		var j := (i + 1) % count
		var wall := (top[j] - top[i]).cross(Vector3.UP)
		if wall.length_squared() < 0.000001:
			continue
		wall = wall.normalized()
		var edge_col := cols[i].lerp(GameConfig.BLADE_SILVER, 0.5)
		var edge_col_j := cols[j].lerp(GameConfig.BLADE_SILVER, 0.5)
		_face(st, top[i], top[j], bottom[j], edge_col, edge_col_j, edge_col_j, wall)
		_face(st, top[i], bottom[j], bottom[i], edge_col, edge_col_j, edge_col, wall)


## Four green gems set into the gaps between arms, pointing outward.
func _build_gems() -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = GameConfig.BLADE_GEM
	mat.metallic = 0.05
	mat.roughness = 0.22
	mat.emission_enabled = true
	mat.emission = GameConfig.BLADE_GEM
	mat.emission_energy_multiplier = 0.35

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 4:
		var a := TAU * (float(i) + 0.5) / 4.0
		var cs := cos(a)
		var sn := sin(a)
		# Kite shape: narrow at the hub, wide shoulders, sharp point outward.
		var pts: Array[Vector2] = [
			Vector2(0.20, 0.0), Vector2(0.34, 0.10),
			Vector2(0.52, 0.0), Vector2(0.34, -0.10),
		]
		var ring: Array[Vector3] = []
		for pt in pts:
			ring.append(Vector3(pt.x * cs - pt.y * sn, 0.0, pt.x * sn + pt.y * cs))
		var peak := Vector3(0.34 * cs, 0.055, 0.34 * sn)
		var col := GameConfig.BLADE_GEM
		var bright := GameConfig.BLADE_GEM.lightened(0.35)
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

	var ring := TorusMesh.new()
	ring.inner_radius = GameConfig.BLADE_HUB_INNER
	ring.outer_radius = GameConfig.BLADE_HUB_OUTER
	ring.rings = 32
	ring.ring_segments = 10
	_hub_piece(ring, gold, Vector3(0.0, 0.03, 0.0))

	# Stepped collar just inside the ring: the notched lip of the reference.
	var collar := CylinderMesh.new()
	collar.top_radius = GameConfig.BLADE_HUB_INNER + 0.02
	collar.bottom_radius = GameConfig.BLADE_HUB_INNER + 0.035
	collar.height = 0.05
	collar.radial_segments = 24
	_hub_piece(collar, deep, Vector3(0.0, 0.02, 0.0))

	# Diamond frame: four bars set at 45 deg, leaving square gaps at the corners.
	var bar := BoxMesh.new()
	bar.size = Vector3(0.34, 0.03, 0.055)
	for i in 4:
		var a := TAU * (float(i) + 0.5) / 4.0
		var mi := _hub_piece(bar, gold,
			Vector3(cos(a) * 0.30, 0.005, sin(a) * 0.30))
		mi.rotation.y = -a + PI * 0.5


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
		ca: Color, cb: Color, cc: Color, n: Vector3) -> void:
	if (b - a).cross(c - a).dot(n) > 0.0:
		_cv(st, a, ca, n)
		_cv(st, c, cc, n)
		_cv(st, b, cb, n)
		return
	_cv(st, a, ca, n)
	_cv(st, b, cb, n)
	_cv(st, c, cc, n)


func _cv(st: SurfaceTool, pos: Vector3, col: Color, n: Vector3) -> void:
	st.set_color(col.srgb_to_linear())
	st.set_normal(n)
	st.set_uv(Vector2(0.5, 0.5))
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
