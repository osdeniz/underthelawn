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


## How much of the front has arrived, 0 to 1 (G49). 1 by default: a scene
## built without a level driving it — the diorama, a shot, a bare run — should
## look like the weather it says it has, and only a yard being played makes
## the rain arrive.
static var wetness := 1.0
## Skips the arrival and holds the weather full on. The suites set it, because
## a dozen of them render or measure a wet yard and would otherwise be looking
## at a dry one and passing for the wrong reason.
static var hold := false


## Decided ONCE, when the script loads, and not on every scene build: the
## first version re-read the marker in build(), which put the hold back on
## top of the one suite that had just turned it off (measured — nine claims
## failed reporting a yard that was already soaking).
static func _static_init() -> void:
	# Same marker the background pause and the yard autosave use (G19.10).
	hold = OS.get_environment("UTL_NO_BG_PAUSE") == "1"


static func build(parent: Node3D) -> Rain:
	var node := Rain.new()
	node.name = "Rain"
	parent.add_child(node)
	node._setup()
	node.refresh()
	return node


## Sets the front's progress and repaints the drops for it. The SKY is not
## touched here: whoever moves the weather also re-applies the hour, because
## the light belongs to SkyTime and rain is only a weight on it.
static func set_wetness(value: float) -> void:
	wetness = 1.0 if hold else clampf(value, 0.0, 1.0)


## How hard it is actually falling: nothing until the light has changed, then
## up to full. The light goes first because that is the order it happens in.
static func fall_ratio() -> float:
	if wetness <= GameConfig.RAIN_FALL_AT:
		return 0.0
	return (wetness - GameConfig.RAIN_FALL_AT) / (1.0 - GameConfig.RAIN_FALL_AT)


var _pm: ParticleProcessMaterial
var _quad: QuadMesh
var _mat: StandardMaterial3D


## Snow (G23): a wet chapter on the SNOW palette. The same particle system,
## slowed and whitened in refresh(); the rain SOUND stays off for it.
static func is_snow() -> bool:
	return is_wet() and LevelVariant.current != null \
		and LevelVariant.current.palette_id == "SNOW"


func _apply_look() -> void:
	if _pm == null:
		return
	var snow := is_snow()
	_pm.initial_velocity_min = GameConfig.SNOW_SPEED.x if snow else GameConfig.RAIN_SPEED.x
	_pm.initial_velocity_max = GameConfig.SNOW_SPEED.y if snow else GameConfig.RAIN_SPEED.y
	_pm.gravity = GameConfig.SNOW_SLANT if snow else GameConfig.RAIN_SLANT
	_quad.size = GameConfig.SNOW_FLAKE if snow else GameConfig.RAIN_DROP
	_mat.albedo_color = GameConfig.SNOW_COLOUR if snow else GameConfig.RAIN_COLOUR
	_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED if snow \
		else BaseMaterial3D.BILLBOARD_FIXED_Y
	# A flake is a soft dot, not a square: the cloud texture on the quad, the
	# same lesson as the chimney smoke (G20.1). A drop stays a bare line.
	_mat.albedo_texture = TextureLibrary.find("cloud_billboard") if snow else null
	amount = GameConfig.SNOW_COUNT if snow else GameConfig.RAIN_COUNT
	lifetime = GameConfig.SNOW_LIFETIME if snow else GameConfig.RAIN_LIFETIME
	preprocess = lifetime


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
	_pm = pm

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
	_quad = quad
	_mat = mat

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
	_apply_look()
	var wet := is_wet()
	var falling := fall_ratio()
	# `amount` is left alone: changing it restarts the whole system, and a
	# front that comes over should not make the rain blink. The drops fade in
	# on their own alpha instead.
	emitting = wet and falling > 0.0
	visible = emitting
	amount = GameConfig.RAIN_COUNT
	if _mat != null:
		var full: Color = GameConfig.SNOW_COLOUR if is_snow() else GameConfig.RAIN_COLOUR
		_mat.albedo_color = Color(full.r, full.g, full.b, full.a * falling)


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
