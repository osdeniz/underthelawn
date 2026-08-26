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


## Applies `id` to the scene's sun and environment. An unknown id falls back to
## midday, which is the lighting everything else in the game was balanced to.
static func apply(env_host: WorldEnvironment, sun: DirectionalLight3D,
		id: String) -> void:
	if env_host == null or env_host.environment == null:
		return
	var key := id if GameConfig.TIME_OF_DAY.has(id) \
		else GameConfig.TIME_OF_DAY_DEFAULT
	if not GameConfig.TIME_OF_DAY.has(key):
		return
	var spec: Dictionary = GameConfig.TIME_OF_DAY[key]
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
	env.ambient_light_color = spec["ambient"]
	env.ambient_light_energy = float(spec["ambient_energy"])
	env.fog_light_color = spec["fog"]
