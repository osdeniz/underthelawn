shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

// Pool water (§11): semi-transparent turquoise over the pool-floor tint the
// ground already paints, so the bottom shows through. Vertex wave verbatim:
//   y += sin(TIME*1.8 + x*3.0 + z*2.2) * 0.02

uniform vec4 water_color : source_color = vec4(0.30, 0.75, 0.82, 0.72);
uniform float water_roughness = 0.12;
uniform float wave_speed = 1.8;
uniform float wave_amp = 0.02;

varying vec3 v_world;

void vertex() {
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	VERTEX.y += sin(TIME * wave_speed + v_world.x * 3.0 + v_world.z * 2.2) * wave_amp;
}

void fragment() {
	ALBEDO = water_color.rgb;
	ALPHA = water_color.a;
	ROUGHNESS = water_roughness;
	SPECULAR = 0.6;
	// Faint moving highlight so the surface reads as liquid from above.
	float glint = sin(TIME * wave_speed * 1.3 + v_world.x * 5.0 + v_world.z * 3.7);
	ALBEDO += vec3(0.06) * smoothstep(0.75, 1.0, glint);
}
