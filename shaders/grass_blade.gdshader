shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_disabled;

// Shared cut mask (see lawn_ground.gdshader). Sampled in the vertex stage from
// each blade's instance origin, so cutting costs zero per-blade CPU work.
uniform sampler2D cut_mask : filter_linear, repeat_disable;
uniform vec2 lawn_origin = vec2(0.0);
uniform vec2 lawn_size = vec2(1.0);

uniform vec3 color_root : source_color = vec3(0.045, 0.145, 0.035);
uniform vec3 color_tip : source_color = vec3(0.330, 0.610, 0.150);
uniform vec3 color_cut_tip : source_color = vec3(0.300, 0.520, 0.165);

uniform float cut_height = 0.17;
uniform float cut_lean = 0.55;
uniform float wind_strength = 0.16;
uniform float wind_speed = 1.7;

// Live mower position, so standing grass leans away from the chassis.
uniform vec3 mower_pos = vec3(0.0, 0.0, 1000.0);
uniform float mower_push_radius = 1.6;
uniform float mower_push_strength = 0.5;

varying float v_cut;
varying float v_height;
varying float v_rand;

void vertex() {
	vec3 root = MODEL_MATRIX[3].xyz;
	vec2 uv = (root.xz - lawn_origin) / lawn_size;
	vec4 m = textureLod(cut_mask, clamp(uv, vec2(0.0005), vec2(0.9995)), 0.0);

	float cut = clamp(m.r, 0.0, 1.0);
	float dir = m.g;
	float rnd = INSTANCE_CUSTOM.r;

	float h = UV.y;
	v_cut = cut;
	v_height = h;
	v_rand = rnd;

	// Ease the collapse so blades snap down fast then settle.
	float e = 1.0 - pow(1.0 - cut, 3.0);

	// Blades fall over in the direction of the pass, then shrink to stubble.
	float side = mix(-1.0, 1.0, step(0.5, dir));
	VERTEX.x += cut_lean * e * h * h * side;
	VERTEX.y *= mix(1.0, cut_height, e);

	// Wind sway, only for grass that is still standing.
	float phase = TIME * wind_speed + root.x * 0.55 + root.z * 0.4 + rnd * 6.283;
	float sway = sin(phase) * 0.7 + sin(phase * 2.3 + 1.7) * 0.3;
	float amp = wind_strength * h * h * (1.0 - e);
	VERTEX.x += sway * amp;
	VERTEX.z += cos(phase * 0.8) * amp * 0.5;

	// Push standing blades away from the mower body. The instance basis is
	// yaw + uniform XZ scale, so projecting onto its axes converts the world
	// direction to blade-local space without a matrix inverse.
	vec3 away = vec3(root.x - mower_pos.x, 0.0, root.z - mower_pos.z);
	float dist = length(away);
	if (dist < mower_push_radius && dist > 0.001) {
		away /= dist;
		float push = (1.0 - dist / mower_push_radius) * mower_push_strength * h * h * (1.0 - e);
		vec3 axis_x = normalize(MODEL_MATRIX[0].xyz);
		vec3 axis_z = normalize(MODEL_MATRIX[2].xyz);
		VERTEX.x += dot(away, axis_x) * push;
		VERTEX.z += dot(away, axis_z) * push;
	}

	NORMAL = normalize(mix(NORMAL, vec3(0.0, 1.0, 0.0), 0.45));
}

void fragment() {
	vec3 col = mix(color_root, color_tip, v_height * 0.9 + 0.1);
	col = mix(col, color_cut_tip, v_cut * 0.6);
	col *= 0.82 + 0.36 * v_rand;
	ALBEDO = col;
	ROUGHNESS = 0.9;
	if (!FRONT_FACING) {
		NORMAL = -NORMAL;
	}
}
