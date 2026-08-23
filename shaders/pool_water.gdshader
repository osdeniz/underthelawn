shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

// Pool water. G5 base: §11 vertex wave. G6 upgrade (WATER_FANCY_ENABLED):
// a second fast ripple layer, fresnel-driven alpha/specular (clear when viewed
// straight down, mirror-bright at grazing angles) and two counter-scrolling
// procedural normal fields that make the sun glints crawl with the camera.

uniform vec4 water_color : source_color = vec4(0.30, 0.75, 0.82, 0.72);
uniform float water_roughness = 0.12;
uniform float wave_speed = 1.8;
uniform float wave_amp = 0.02;

uniform bool fancy = true;
uniform float wave2_speed = 4.2;
uniform float wave2_freq = 7.0;
uniform float wave2_amp = 0.008;
uniform float fresnel_power = 3.0;
uniform float alpha_facing = 0.55;
uniform float alpha_grazing = 0.92;

varying vec3 v_world;

void vertex() {
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	VERTEX.y += sin(TIME * wave_speed + v_world.x * 3.0 + v_world.z * 2.2) * wave_amp;
	if (fancy) {
		VERTEX.y += sin(TIME * wave2_speed + v_world.x * wave2_freq) * wave2_amp;
	}
}

void fragment() {
	ALBEDO = water_color.rgb;
	ROUGHNESS = water_roughness;

	if (fancy) {
		// Two scrolling ripple fields, different speeds and directions; their
		// slopes tilt the normal so the sun highlight breaks up and moves.
		vec2 p1 = v_world.xz * 2.6 + vec2(TIME * 0.55, TIME * 0.35);
		vec2 p2 = v_world.xz * 4.1 - vec2(TIME * 0.42, -TIME * 0.28);
		vec2 slope = vec2(
			sin(p1.x) * 0.5 + sin(p2.x + p2.y) * 0.35,
			sin(p1.y * 1.3) * 0.5 + cos(p2.y) * 0.35);
		NORMAL = normalize(NORMAL + TANGENT * slope.x * 0.10 + BINORMAL * slope.y * 0.10);

		// Fresnel: VIEW is the vector to the camera in view space.
		float facing = clamp(dot(normalize(VIEW), NORMAL), 0.0, 1.0);
		float fresnel = pow(1.0 - facing, fresnel_power);
		ALPHA = mix(alpha_facing, alpha_grazing, fresnel);
		SPECULAR = mix(0.5, 1.0, fresnel);
		ALBEDO += vec3(0.10, 0.12, 0.12) * fresnel;
	} else {
		ALPHA = water_color.a;
		SPECULAR = 0.6;
		float glint = sin(TIME * wave_speed * 1.3 + v_world.x * 5.0 + v_world.z * 3.7);
		ALBEDO += vec3(0.06) * smoothstep(0.75, 1.0, glint);
	}
}
