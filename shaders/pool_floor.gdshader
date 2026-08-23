shader_type spatial;
render_mode diffuse_burley, specular_disabled;

// Pool bottom under the water: light tile pattern whose UVs wobble with a
// small sine offset, selling refraction through the surface (G6).

uniform vec3 floor_color : source_color = vec3(0.70, 0.92, 0.95);
uniform vec3 line_color : source_color = vec3(0.48, 0.72, 0.78);
uniform float tile_size = 0.5;
uniform bool fancy = true;

varying vec3 v_world;

void vertex() {
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 uv = v_world.xz;
	if (fancy) {
		uv += vec2(
			sin(TIME * 1.6 + v_world.z * 3.1),
			sin(TIME * 1.3 + v_world.x * 2.7)) * 0.035;
	}
	vec2 cell = fract(uv / tile_size);
	float line = step(cell.x, 0.055) + step(cell.y, 0.055);
	ALBEDO = mix(floor_color, line_color, clamp(line, 0.0, 1.0) * 0.7);
	ROUGHNESS = 0.6;
}
