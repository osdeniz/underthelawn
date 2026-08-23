shader_type spatial;
// G6.5 volumetric grass clumps: OPAQUE geometry, no texture, no alpha — fast on
// mobile and reads as thick, soft-edged stylized grass. All colour comes from
// baked vertex colours (root->tip gradient per variant) multiplied by the
// MultiMesh per-instance brightness tint. UV.y carries the height fraction so
// the wind bends tips while roots stay planted.
render_mode cull_disabled, diffuse_burley, specular_disabled;

uniform float wind_amplitude = 0.06;
uniform float wind_speed = 2.0;

void vertex() {
	vec3 root = MODEL_MATRIX[3].xyz;
	float h = UV.y;
	float phase = TIME * wind_speed + root.x * 0.9 + root.z * 0.7;
	float sway = sin(phase) * 0.7 + sin(phase * 2.3 + 1.7) * 0.3;
	VERTEX.x += sway * wind_amplitude * h * h;
	VERTEX.z += cos(phase * 0.8) * wind_amplitude * 0.5 * h * h;
	// Lit mostly like the ground so clumps sit into the lawn instead of
	// popping off it; a little of the true normal keeps the blade shape.
	NORMAL = normalize(mix(NORMAL, vec3(0.0, 1.0, 0.0), 0.65));
}

void fragment() {
	ALBEDO = COLOR.rgb;
	ROUGHNESS = 0.92;
	if (!FRONT_FACING) {
		NORMAL = -NORMAL;
	}
}
