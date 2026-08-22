shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

// Ground = ONE continuous 16x24 plane. Grass detail texture tiles across it
// (7 repeats in X, ~10.5 in Z) and a 16x24 tint texture multiplies the albedo,
// one pixel per cell (REFERENCE.md §5). Linear filtering on the tint gives the
// soft cell-to-cell transition.
//
// Tint texel (col, row) maps to UV (col/16, row/24); row 0 is north (-Z), which
// matches PlaneMesh UV v=0 at z=-12. Verify on first run (§18 trap 5).

uniform sampler2D grass_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D grass_normal : hint_roughness_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D cell_tint : source_color, filter_linear, repeat_disable;

uniform bool has_albedo = false;
uniform bool has_normal = false;
uniform vec3 fallback_albedo : source_color = vec3(0.28, 0.42, 0.18);
uniform vec2 uv_repeat = vec2(7.0, 10.5);
uniform float normal_strength = 0.6;
uniform float surface_roughness = 0.95;

void fragment() {
	vec2 detail_uv = UV * uv_repeat;

	vec3 base = fallback_albedo;
	if (has_albedo) {
		base = texture(grass_albedo, detail_uv).rgb;
	}

	vec3 tint = texture(cell_tint, UV).rgb;

	ALBEDO = base * tint;
	ROUGHNESS = surface_roughness;
	SPECULAR = 0.15;

	if (has_normal) {
		NORMAL_MAP = texture(grass_normal, detail_uv).rgb;
		NORMAL_MAP_DEPTH = normal_strength;
	}
}
