class_name Rain
extends GPUParticles3D
## Rain over the yard (G14.7).
##
## One GPU particle system, unshaded and shadowless, exactly like the fireflies
## and the chimney smoke: 260 drops cost what one node costs. It follows the
## CHAPTER, not the clock — a yard is either a wet one or it is not, so there is
## no cycle and nothing to keep in sync.
##
## What rain must NOT do is hide the cut line. Everything it does to the light
## lives in GameConfig.RAIN_* and was measured against the legibility floor
## before it was kept.


static func build(parent: Node3D) -> Rain:
	var node := Rain.new()
	node.name = "Rain"
	parent.add_child(node)
	node._setup()
	node.refresh()
	return node


func _setup() -> void:
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	# A thin slab well above the lawn: drops fall INTO the frame rather than
	# appearing inside it.
	pm.emission_box_extents = Vector3(GameConfig.HALF_X + 6.0, 0.4,
		GameConfig.HALF_Z + 6.0)
	pm.direction = Vector3(0.0, -1.0, 0.0)
	pm.spread = 0.0
	pm.initial_velocity_min = GameConfig.RAIN_SPEED.x
	pm.initial_velocity_max = GameConfig.RAIN_SPEED.y
	pm.gravity = GameConfig.RAIN_SLANT
	pm.scale_min = 0.7
	pm.scale_max = 1.25
	process_material = pm

	var quad := QuadMesh.new()
	quad.size = GameConfig.RAIN_DROP
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = GameConfig.RAIN_COLOUR
	mat.disable_receive_shadows = true
	# Y-billboard: a drop turns to face the camera but stays vertical, which is
	# what keeps it a falling line instead of a tumbling flake.
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	quad.material = mat
	draw_pass_1 = quad

	amount = GameConfig.RAIN_COUNT
	lifetime = GameConfig.RAIN_LIFETIME
	preprocess = GameConfig.RAIN_LIFETIME
	randomness = 0.4
	local_coords = false
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	position.y = GameConfig.RAIN_HEIGHT
	set_meta("no_bake", true)
	visibility_aabb = AABB(
		Vector3(-GameConfig.HALF_X - 8.0, -GameConfig.RAIN_HEIGHT - 2.0,
			-GameConfig.HALF_Z - 8.0),
		Vector3(GameConfig.HALF_X * 2.0 + 16.0, GameConfig.RAIN_HEIGHT + 6.0,
			GameConfig.HALF_Z * 2.0 + 16.0))


## On for a wet chapter, off otherwise. A stopped system draws nothing, so a
## dry yard pays nothing for this node existing.
func refresh() -> void:
	var wet := is_wet()
	emitting = wet
	visible = wet
	amount = GameConfig.RAIN_COUNT


## Whether the level being played is a wet one AND the hour allows it. The
## light switch can put any chapter into the dark, so this has to be asked of
## the hour actually in force, not of the chapter's own.
static func is_wet() -> bool:
	if LevelVariant.current == null:
		return false
	if LevelVariant.current.weather != GameConfig.WEATHER_RAIN:
		return false
	var hour := SkyTime.resolve(LevelVariant.current.time_of_day)
	return not GameConfig.RAIN_FORBIDDEN_HOURS.has(hour)
