shader_type spatial;
// Anello effetto (click, onda d'urto, avvisi, gittate) con progresso animabile.
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

uniform vec4 color : source_color = vec4(1.0, 0.6, 0.2, 1.0);
uniform float thickness = 0.12;
uniform float fade = 1.0;
uniform float fill = 0.0;

void fragment() {
	vec2 uv = UV * 2.0 - 1.0;
	float r = length(uv);
	float ring = smoothstep(1.0 - thickness, 1.0 - thickness * 0.5, r) * (1.0 - smoothstep(0.97, 1.0, r));
	float inside = (1.0 - step(1.0, r)) * fill * (0.4 + 0.6 * r * r);
	ALBEDO = color.rgb;
	ALPHA = clamp((ring + inside) * color.a * fade, 0.0, 1.0);
}
