class_name SkyTime
extends RefCounted
## Puts a chapter's hour on the sky (G14.2).
##
## The eight chapters are one day, so each says what time it is and this file
## writes that onto the two nodes the scene already has: the DirectionalLight
## and the WorldEnvironment's sky and fog. Nothing is animated and nothing is
## added — a Sky3D-style dynamic cycle would cost a full-screen sky shader every
## frame on a phone to animate something no level is long enough to see, and it
## would fight a fog curve that the horizon ring is tuned against.
##
## The numbers live in GameConfig.TIME_OF_DAY. This file is only the wiring.

const SECTION := "display"
const KEY := "sky_mode"


## Applies `id` to the scene's sun and environment. An unknown id falls back to
## midday, which is the lighting everything else in the game was balanced to.
## The mode the player has chosen, or AUTO. Stored rather than derived because
## it is a preference, not a fact about the world.
static func mode() -> String:
	var value := str(GameState.get_setting(SECTION, KEY, GameConfig.SKY_MODE_AUTO))
	return value if GameConfig.SKY_MODES.has(value) else GameConfig.SKY_MODE_AUTO


static func set_mode(value: String) -> void:
	if not GameConfig.SKY_MODES.has(value):
		return
	GameState.set_setting(SECTION, KEY, value)


## The next mode in the cycle, for a button that has one job.
static func next_mode() -> String:
	var at := GameConfig.SKY_MODES.find(mode())
	return GameConfig.SKY_MODES[(at + 1) % GameConfig.SKY_MODES.size()]


## Which preset actually lights a level whose own hour is `hour`. AUTO keeps
## the chapter's hour; the other two override it everywhere.
static func resolve(hour: String) -> String:
	var chosen := mode()
	if chosen == GameConfig.SKY_MODE_AUTO:
		return hour
	return str(GameConfig.SKY_MODE_PRESET.get(chosen, hour))


static func apply(env_host: WorldEnvironment, sun: DirectionalLight3D,
		id: String) -> void:
	_write(env_host, sun, resolve(id))


## The light part-way between two hours (G15.5): every field of the two presets
## interpolated, then written like a preset. Used by the one chapter whose sun
## actually moves, over the length of its search — the only motion the sky
## ever has, and it costs nothing per frame beyond a handful of lerps.
static func blend(env_host: WorldEnvironment, sun: DirectionalLight3D,
		from_id: String, to_id: String, t: float) -> void:
	var a: Dictionary = GameConfig.TIME_OF_DAY.get(resolve(from_id),
		GameConfig.TIME_OF_DAY[GameConfig.TIME_OF_DAY_DEFAULT])
	var b: Dictionary = GameConfig.TIME_OF_DAY.get(resolve(to_id), a)
	var mixed := {}
	for k: String in a:
		var va: Variant = a[k]
		var vb: Variant = b.get(k, va)
		if va is Color and vb is Color:
			mixed[k] = (va as Color).lerp(vb, t)
		elif (va is float or va is int) and (vb is float or vb is int):
			mixed[k] = lerpf(float(va), float(vb), t)
		else:
			mixed[k] = va if t < 0.5 else vb
	_write_spec(env_host, sun, mixed, from_id if t < 0.5 else to_id)


static func _write(env_host: WorldEnvironment, sun: DirectionalLight3D,
		id: String) -> void:
	var key := id if GameConfig.TIME_OF_DAY.has(id) \
		else GameConfig.TIME_OF_DAY_DEFAULT
	if not GameConfig.TIME_OF_DAY.has(key):
		return
	_write_spec(env_host, sun, GameConfig.TIME_OF_DAY[key], id)


static func _write_spec(env_host: WorldEnvironment, sun: DirectionalLight3D,
		spec: Dictionary, id: String) -> void:
	if env_host == null or env_host.environment == null:
		return
	var env := env_host.environment

	if sun != null:
		# -elev because a light shines down its own -Z: rotating +x would lift
		# the beam off the ground instead of onto it.
		sun.rotation_degrees = Vector3(
			-float(spec["elev"]), float(spec["azim"]), 0.0)
		sun.light_color = spec["sun"]
		sun.light_energy = float(spec["sun_energy"])

	var sky_material := env.sky.sky_material as ProceduralSkyMaterial \
		if env.sky != null else null
	if sky_material != null:
		sky_material.sky_top_color = spec["sky_top"]
		sky_material.sky_horizon_color = spec["sky_horizon"]
		sky_material.ground_horizon_color = spec["sky_horizon"]
		sky_material.ground_bottom_color = spec["ground"]
	# The preset's ambient is a COLOUR, so the environment has to be reading its
	# ambient from a colour. The diorama's takes it from the SKY instead, and a
	# night sky is nearly black — forcing night on it turned the whole town off
	# and the ambient value here was simply ignored (G14.6).
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = spec["ambient"]
	env.ambient_light_energy = float(spec["ambient_energy"])
	env.fog_light_color = spec["fog"]

	# Rain takes the edge off the light rather than replacing it: the hour is
	# still readable underneath, and the cut line survives (measured, G14.7).
	if Rain.is_wet():
		var dark: bool = GameConfig.RAIN_DARK_HOURS.has(id)
		if sun != null:
			sun.light_energy *= GameConfig.RAIN_DARK_SUN_ENERGY if dark \
				else GameConfig.RAIN_SUN_ENERGY
		# Note the direction: after dark the ambient goes DOWN, not up. An
		# overcast sky lifts the fill light, which is right at noon and fatal
		# at dusk — it flattens away the last of the directional contrast.
		env.ambient_light_energy *= GameConfig.RAIN_DARK_AMBIENT_ENERGY \
			if dark else GameConfig.RAIN_AMBIENT_ENERGY
		env.fog_light_color = (spec["fog"] as Color).lerp(GameConfig.RAIN_FOG,
			GameConfig.RAIN_DARK_FOG_MIX if dark else GameConfig.RAIN_FOG_MIX)
