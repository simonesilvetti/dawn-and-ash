shader_type spatial;
// Increspature attorno alle unità che guadano il fiume (UnitView._update_wake): anelli che si allargano e
// schiuma attorno alle gambe. "strength" è per istanza: più forte quando l'unità cammina.
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

instance uniform float strength = 0.5;

void fragment() {
	vec2 uv = UV * 2.0 - 1.0;
	float r = length(uv);
	float seed = fract(dot(NODE_POSITION_WORLD.xz, vec2(0.13, 0.71)));
	float a = 0.0;
	for (int i = 0; i < 2; i++) {
		float ph = fract(TIME * 0.7 + float(i) * 0.5 + seed);
		float rr = 0.3 + ph * 0.62;
		a += (1.0 - smoothstep(0.0, 0.07, abs(r - rr))) * (1.0 - ph);
	}
	a += (1.0 - smoothstep(0.18, 0.36, r)) * 0.6;
	a *= strength * (1.0 - smoothstep(0.85, 1.0, r));
	ALBEDO = vec3(0.9, 0.97, 1.0);
	ALPHA = clamp(a, 0.0, 1.0) * 0.75;
}
