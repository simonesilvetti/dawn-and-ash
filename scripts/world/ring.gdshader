shader_type spatial;
// Anello di squadra sotto le unità + ombra "blob" morbida.
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

uniform vec4 color : source_color = vec4(0.3, 0.9, 0.7, 0.9);
uniform float inner = 0.80;
uniform float shadow = 0.45;
uniform float pulse = 0.0;

void fragment() {
	vec2 uv = UV * 2.0 - 1.0;
	float r = length(uv);
	float ring = smoothstep(inner - 0.08, inner, r) * (1.0 - smoothstep(0.92, 1.0, r));
	ring *= 1.0 + pulse * 0.4 * sin(TIME * 6.0);
	float blob = (1.0 - smoothstep(0.0, 0.75, r)) * shadow;
	float ar = clamp(ring * color.a, 0.0, 1.0);
	float ab = blob * (1.0 - ar);
	ALBEDO = color.rgb * ar / max(ar + ab, 0.0001);
	ALPHA = ar + ab;
}
