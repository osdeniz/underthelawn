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
		var step := minf(GameConfig.BLADE_FOLLOW_SPEED * delta, dist)
		_velocity = to_target.normalized() * (step / maxf(delta, 0.0001)) \
			if dist > 0.01 else Vector3.ZERO
		position += to_target.normalized() * step if dist > 0.01 else Vector3.ZERO
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
	# The disk never stops spinning; motion adds up to 20%.
	if _disk:
		_disk.rotation.y += deg_to_rad(GameConfig.BLADE_SPIN_DEG) \
			* (1.0 + 0.2 * speed_fraction()) * delta
	if _blur_ring:
		_blur_ring.rotation.y -= deg_to_rad(GameConfig.BLADE_SPIN_DEG) * 0.6 * delta


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


# ---------------------------------------------------------------- model (G6.6)

## Chakram / shuriken form: a thick blue donut ring with dark rivets, and six
## white sickle blades sweeping backwards from it with blue-glowing tips.
## Diameter ~1.1, riding 0.15 above the ground, spinning at BLADE_SPIN_DEG.
func _build_model() -> void:
	var body := Node3D.new()
	body.name = "Body"
	add_child(body)

	_disk = Node3D.new()
	_disk.name = "Disk"
	_disk.position.y = 0.15
	_disk.scale = Vector3.ONE * GameConfig.BLADE_SCALE
	body.add_child(_disk)

	var blue := StandardMaterial3D.new()
	blue.albedo_color = Color(0.25, 0.60, 0.95)
	blue.metallic = 0.55
	blue.roughness = 0.30
	var rivet := StandardMaterial3D.new()
	rivet.albedo_color = Color(0.10, 0.14, 0.20)
	rivet.metallic = 0.7
	rivet.roughness = 0.35
	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color(0.95, 0.95, 0.92)
	steel.metallic = 0.4
	steel.roughness = 0.25
	var edge := StandardMaterial3D.new()
	edge.albedo_color = Color(0.60, 0.85, 1.0)
	edge.emission_enabled = true
	edge.emission = Color(0.35, 0.72, 1.0)
	edge.emission_energy_multiplier = 2.2

	# Hub ring: a real donut — hole in the middle, section radius 0.07.
	var ring := TorusMesh.new()
	ring.inner_radius = 0.08
	ring.outer_radius = 0.22
	ring.rings = 28
	ring.ring_segments = 10
	var ring_mi := MeshInstance3D.new()
	ring_mi.mesh = ring
	ring_mi.material_override = blue
	ring_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_disk.add_child(ring_mi)

	# Seven dark rivets pressed into the ring's top face.
	var rivet_mesh := SphereMesh.new()
	rivet_mesh.radius = 0.028
	rivet_mesh.height = 0.056
	rivet_mesh.radial_segments = 8
	rivet_mesh.rings = 4
	for i in 7:
		var a := TAU * float(i) / 7.0
		var mi := MeshInstance3D.new()
		mi.mesh = rivet_mesh
		mi.material_override = rivet
		mi.position = Vector3(cos(a) * 0.15, 0.052, sin(a) * 0.15)
		mi.scale = Vector3(1.0, 0.55, 1.0)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_disk.add_child(mi)

	# Six sickle blades, built as one mesh, plus their glowing tips.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tips: Array[Vector3] = []
	for i in 6:
		tips.append(_add_sickle(st, TAU * float(i) / 6.0))
	var blades_mi := MeshInstance3D.new()
	blades_mi.name = "Sickles"
	blades_mi.mesh = st.commit()
	blades_mi.material_override = steel
	# No shadow casting anywhere on the chakram: the blades sit 3.5 cm above the
	# translucent blur disk and were painting hard black swirls onto it. The disk
	# spins at 720 deg/s and has its own fake-AO decal for grounding.
	blades_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_disk.add_child(blades_mi)

	var tip_mesh := BoxMesh.new()
	tip_mesh.size = Vector3(0.05, 0.012, 0.05)
	for tip in tips:
		var mi := MeshInstance3D.new()
		mi.mesh = tip_mesh
		mi.material_override = edge
		mi.position = tip
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_disk.add_child(mi)

	if GameConfig.BLADE_FX_ENABLED:
		_build_fx(body)
	_build_clippings()
	_spark_audio = AudioStreamPlayer3D.new()
	_spark_audio.stream = TrafficController._find_audio("res://audio/blade_hit")
	_spark_audio.unit_size = 10.0
	if _spark_audio.stream == null:
		print("[Blade] audio/blade_hit.ogg yok - kivilcim sesi sessiz")
	add_child(_spark_audio)


## One sickle: a 4-segment SOLID slab stepping outward from the ring while
## turning ~25 deg backwards per segment, tapering to a point and lifting
## slightly for the twist. Built with real thickness and outward normals — a
## single-sided strip with cull_disabled renders its back faces unlit (they came
## out black), and a solid also just reads better. Returns the tip position.
func _add_sickle(st: SurfaceTool, start_angle: float) -> Vector3:
	var segments := 4
	var r0 := 0.20
	var r1 := 0.55                       # diameter ~1.1
	var back_turn := deg_to_rad(25.0)    # per segment
	var half_width := 0.105
	var half_thick := 0.011

	var rows: Array = []                 # [lt, rt, lb, rb, up]
	var tip := Vector3.ZERO
	for s in segments + 1:
		var f := float(s) / float(segments)
		var radius := lerpf(r0, r1, f)
		var angle := start_angle + back_turn * float(s)
		var out_dir := Vector3(cos(angle), 0.0, sin(angle))
		var side := Vector3(-sin(angle), 0.0, cos(angle))
		var center := out_dir * radius + Vector3(0.0, f * 0.035, 0.0)
		var w := half_width * (1.0 - f * f)
		# Twist: the blade rolls a little around its own radial axis.
		var roll := f * 0.35
		var up := (Vector3.UP * cos(roll) + side * sin(roll)).normalized()
		var across := side * cos(roll) - Vector3.UP * sin(roll)
		if s == segments:
			tip = center
		rows.append([
			center - across * w + up * half_thick,
			center + across * w + up * half_thick,
			center - across * w - up * half_thick,
			center + across * w - up * half_thick,
			up])

	for s in segments:
		var a: Array = rows[s]
		var b: Array = rows[s + 1]
		var up_a: Vector3 = a[4]
		var up_b: Vector3 = b[4]
		if s == segments - 1:
			# Close into the point: top and bottom triangles plus two edges.
			_tri_n(st, a[0], a[1], tip, up_a)
			_tri_n(st, a[3], a[2], tip, -up_a)
			var e0: Vector3 = a[0]
			var e1: Vector3 = a[1]
			var edge_n := (e1 - e0).normalized()
			_tri_n(st, a[1], a[3], tip, edge_n)
			_tri_n(st, a[2], a[0], tip, -edge_n)
			continue
		# Top and bottom faces.
		_quad_n(st, a[0], a[1], b[1], b[0], up_a, up_b)
		_quad_n(st, b[2], b[3], a[3], a[2], -up_b, -up_a)
		# Outer and inner edges.
		var a1: Vector3 = a[1]
		var a0: Vector3 = a[0]
		var out_n := (a1 - a0).normalized()
		_quad_n(st, a[1], a[3], b[3], b[1], out_n, out_n)
		_quad_n(st, b[0], b[2], a[2], a[0], -out_n, -out_n)
	return tip


func _quad_n(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3,
		n_ab: Vector3, n_cd: Vector3) -> void:
	var n := (n_ab + n_cd).normalized()
	_tri_n(st, a, b, c, n)
	_tri_n(st, a, c, d, n)


## Emits one flat-shaded triangle FACING `n`. The sickle twists, so hand-reasoned
## winding is error-prone — and Godot treats CLOCKWISE as front-facing, the
## opposite of the usual right-hand rule. So the winding is chosen such that the
## counter-clockwise cross product points AWAY from `n`; get it backwards and the
## top faces are culled, leaving the slab's unlit underside on show (black).
func _tri_n(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, n: Vector3) -> void:
	if (b - a).cross(c - a).dot(n) > 0.0:
		_v3(st, a, n)
		_v3(st, c, n)
		_v3(st, b, n)
		return
	_v3(st, a, n)
	_v3(st, b, n)
	_v3(st, c, n)


func _v3(st: SurfaceTool, pos: Vector3, n: Vector3) -> void:
	st.set_normal(n)
	st.set_uv(Vector2(0.5, 0.5))
	st.add_vertex(pos)


func _build_fx(body: Node3D) -> void:
	# Faint counter-rotating streak ring under the disk: motion-blur feel.
	# Translucent white-blue disk under the chakram: the spin smears into a
	# faint halo the eye reads as motion.
	var blur := CylinderMesh.new()
	blur.top_radius = 0.58
	blur.bottom_radius = 0.58
	blur.height = 0.004
	blur.radial_segments = 32
	var blur_mat := StandardMaterial3D.new()
	blur_mat.albedo_color = Color(0.78, 0.92, 1.0, 0.16)
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
	pm.emission_ring_radius = 0.55 * GameConfig.BLADE_SCALE
	pm.emission_ring_inner_radius = 0.30 * GameConfig.BLADE_SCALE
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
