shader_type canvas_item;
// Screen dressing from §16: a warm sun gradient falling from the top-left
// (orange 10% -> purple 8%) and a soft radial vignette (16% black).
// Drawn on a full-rect ColorRect that ignores input.

uniform float vignette_strength = 0.16;
uniform float warm_strength = 0.10;
uniform float cool_strength = 0.08;
uniform vec3 warm_color : source_color = vec3(1.0, 0.55, 0.18);
uniform vec3 cool_color : source_color = vec3(0.42, 0.22, 0.62);

void fragment() {
	// Sun gradient: strongest at the top-left corner, fading across the screen.
	float d = clamp(length(UV) / 1.4142, 0.0, 1.0);
	vec3 tint = mix(warm_color, cool_color, d);
	float tint_a = mix(warm_strength, cool_strength, d);

	// Vignette hugging the frame edges. A circular falloff in UV space burns
	// the corners on a tall portrait screen, so this uses a rounded box that
	// treats both axes evenly and only touches the outer band.
	float edge = max(abs(UV.x - 0.5), abs(UV.y - 0.5)) * 2.0;
	float vig = smoothstep(0.72, 1.0, edge) * vignette_strength;

	// Composite the tint over the vignette so one quad does both.
	float out_a = vig + tint_a * (1.0 - vig);
	vec3 out_rgb = vec3(0.0);
	if (out_a > 0.0001) {
		out_rgb = (vec3(0.0) * vig + tint * tint_a * (1.0 - vig)) / out_a;
	}
	COLOR = vec4(out_rgb, out_a);
}
