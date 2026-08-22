shader_type spatial;
// Grass-card trick (§5): double sided, normals forced UP so the back face is
// not dark and the tufts light like the ground. Alpha-scissored silhouette.
render_mode cull_disabled, diffuse_burley, specular_disabled, depth_prepass_alpha;

uniform sampler2D tuft_texture : source_color, filter_linear_mipmap;
uniform float alpha_cutoff = 0.25;
// Wind, verbatim from §5:
//   pos.x += sin(TIME*2.0 + pos.x*4.0 + pos.z*5.0) * max(pos.y, 0) * 0.06
// Applied in model space, matching the SceneKit geometry modifier: every
// cluster shares one geometry, so the lawn sways in one phase and the
// per-cell Y rotation supplies the variation.
uniform float wind_amplitude = 0.06;
uniform float wind_speed = 2.0;

void vertex() {
	vec3 pos = VERTEX;
	VERTEX.x += sin(TIME * wind_speed + pos.x * 4.0 + pos.z * 5.0)
		* max(pos.y, 0.0) * wind_amplitude;
	NORMAL = vec3(0.0, 1.0, 0.0);
}

void fragment() {
	vec4 tex = texture(tuft_texture, UV);
	ALBEDO = tex.rgb;
	ALPHA = tex.a;
	ALPHA_SCISSOR_THRESHOLD = alpha_cutoff;
	ROUGHNESS = 0.95;
	NORMAL = vec3(0.0, 1.0, 0.0);
}
