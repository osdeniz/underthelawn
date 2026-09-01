shader_type spatial;
// G6.5 volumetric grass clumps: OPAQUE geometry, no texture, no alpha — fast on
// mobile and reads as thick, soft-edged stylized grass. All colour comes from
// baked vertex colours (root->tip gradient per variant) multiplied by the
// MultiMesh per-instance brightness tint. UV.y carries the height fraction so
// the wind bends tips while roots stay planted.
render_mode cull_disabled, diffuse_burley, specular_disabled;

uniform float wind_amplitude = 0.06;
uniform float wind_speed = 2.0;

// A gust travelling across the field, on top of the per-blade sway. It is a
// band of extra amplitude sliding along the wind direction, so the lawn breathes
// in waves instead of vibrating uniformly — three terms, no extra draw (G14.6).
uniform float gust_speed = 0.42;
uniform float gust_length = 0.055;
uniform float gust_strength = 0.85;

// 0 where the gust is not, up to gust_strength where its crest is.
float gust_at(vec3 world_root, float t) {
	float along = (world_root.x + world_root.z) * gust_length - t * gust_speed;
	// sin() lifted and sharpened: long calm stretches, short strong crests.
	float wave = sin(along * 6.2831853) * 0.5 + 0.5;
	return pow(wave, 3.0) * gust_strength;
}

void vertex() {
	vec3 root = MODEL_MATRIX[3].xyz;
	float h = UV.y;
	float phase = TIME * wind_speed + root.x * 0.9 + root.z * 0.7;
	float sway = sin(phase) * 0.7 + sin(phase * 2.3 + 1.7) * 0.3;
	float gust = gust_at(root, TIME);
	VERTEX.x += sway * wind_amplitude * h * h * (1.0 + gust * 2.4);
	VERTEX.z += (cos(phase * 0.8) * 0.5 + gust * 1.6) * wind_amplitude * h * h;
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
