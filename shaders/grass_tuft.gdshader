shader_type spatial;
// Grass-card trick (§5): double sided, normals forced UP so the back face is
// not dark and the tufts light like the ground. Alpha-to-coverage silhouette,
// so MSAA antialiases the blade edges.
render_mode cull_disabled, diffuse_burley, specular_disabled, alpha_to_coverage;

uniform sampler2D tuft_texture : source_color, filter_linear_mipmap;
uniform float alpha_cutoff = 0.25;
// Wind, verbatim from §5:
//   pos.x += sin(TIME*2.0 + pos.x*4.0 + pos.z*5.0) * max(pos.y, 0) * 0.06
// Applied in model space, matching the SceneKit geometry modifier: every
// cluster shares one geometry, so the lawn sways in one phase and the
// per-cell Y rotation supplies the variation.
uniform float wind_amplitude = 0.06;
uniform float wind_speed = 2.0;
// The card is cropped to the artwork, so only a hairline fade is needed to
// keep the outermost blade tips from ending on a hard texel edge.
uniform float edge_fade = 0.03;
// The card art is lit as if horizontal (normals forced up, §5's grass-card
// trick), so it renders brighter than the ground. This tint pulls it back into
// the same value range as the TALL ground tint.
uniform vec3 tuft_tint : source_color = vec3(0.60, 0.82, 0.44);

void vertex() {
	vec3 pos = VERTEX;
	VERTEX.x += sin(TIME * wind_speed + pos.x * 4.0 + pos.z * 5.0)
		* max(pos.y, 0.0) * wind_amplitude;
	NORMAL = vec3(0.0, 1.0, 0.0);
}

void fragment() {
	vec4 tex = texture(tuft_texture, UV);
	// COLOR is the MultiMesh per-instance tint (clump-to-clump variation).
	ALBEDO = tex.rgb * COLOR.rgb * tuft_tint;
	// Alpha-to-coverage lets MSAA antialias the blade edges instead of the
	// hard stair-step a scissor gives. Remap so thin tips stay visible.
	float side = smoothstep(0.0, edge_fade, UV2.x) * smoothstep(0.0, edge_fade, 1.0 - UV2.x);
	ALPHA = smoothstep(alpha_cutoff * 0.75, alpha_cutoff * 1.25, tex.a) * side;
	ROUGHNESS = 0.95;
	NORMAL = vec3(0.0, 1.0, 0.0);
}
