shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

// Cut mask: R = cut animation progress (0 = uncut, 1 = fully cut),
//           G = mow direction captured when the tile was cut (0 or 1).
uniform sampler2D cut_mask : filter_linear, repeat_disable;
uniform vec2 lawn_origin = vec2(0.0);
uniform vec2 lawn_size = vec2(1.0);

uniform vec3 color_uncut_dark : source_color = vec3(0.070, 0.200, 0.050);
uniform vec3 color_uncut_light : source_color = vec3(0.130, 0.320, 0.085);
uniform vec3 color_cut_dark : source_color = vec3(0.145, 0.330, 0.082);
uniform vec3 color_cut_light : source_color = vec3(0.235, 0.455, 0.130);
uniform vec3 color_soil : source_color = vec3(0.180, 0.130, 0.080);

uniform float stripe_width = 2.4;
uniform float noise_scale = 0.55;

varying vec3 v_world;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void vertex() {
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 uv = (v_world.xz - lawn_origin) / lawn_size;
	vec4 m = texture(cut_mask, clamp(uv, vec2(0.0005), vec2(0.9995)));
	float cut = clamp(m.r, 0.0, 1.0);
	float dir = m.g;

	// Organic patchiness so the uncut lawn is not a flat colour.
	float patch = vnoise(v_world.xz * noise_scale);
	float grain = hash21(floor(v_world.xz * 22.0));

	vec3 uncut = mix(color_uncut_dark, color_uncut_light, patch * 0.85 + grain * 0.15);

	// Classic mown stripes: the band axis flips with the direction of the pass.
	float band_x = sin(v_world.x * (PI / stripe_width));
	float band_z = sin(v_world.z * (PI / stripe_width));
	float band = mix(band_z, band_x, step(0.5, dir));
	float fine = sin((mix(v_world.z, v_world.x, step(0.5, dir))) * 9.0) * 0.5 + 0.5;

	vec3 cut_col = mix(color_cut_dark, color_cut_light, band * 0.5 + 0.5);
	cut_col *= 0.94 + 0.06 * fine;
	cut_col = mix(cut_col, color_soil, 0.10 * (1.0 - patch));

	// A short-lived bright "fresh clipping" flash right after the blades pass.
	float freshness = smoothstep(0.0, 0.4, cut) * (1.0 - smoothstep(0.5, 0.95, cut));
	cut_col += vec3(0.07, 0.10, 0.02) * freshness;

	ALBEDO = mix(uncut, cut_col, cut);
	ROUGHNESS = mix(0.95, 0.78, cut);
	SPECULAR = 0.15;
}
